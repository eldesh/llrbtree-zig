const std = @import("std");
const iter_zig = @import("iter-zig");
const Con = @import("basis_concept");
const color = @import("../color.zig");
const string_cmp = @import("../string_cmp.zig");
const node = @import("./node.zig");
const compat = @import("../compat.zig");

pub const config = @import("./config.zig");
pub const key_value = @import("./key_value.zig");
pub const entry = @import("./entry.zig");
pub const iters = @import("./iter.zig");

const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const assert = std.debug.assert;

const Color = color.Color;
const KeyValue = key_value.KeyValue;
const Entry = entry.Entry;

/// A key/value container.
///
/// # Details
/// This function returns that a key/value container using Left-leaning Red-Black Tree algorithm.
/// All values are associated for each keys, and all key/value pairs are stored based on order relation of the keys.
///
/// Note that the releation must be total ordering.
/// If `basis_concept.isOrd(K)` evaluates to `true`, then the automatically derived total function is used.
/// Otherwise, an ordering function must be explicitly passed via `with_cmp`.
///
/// # Arguments
/// - `K`: type of keys, and a total ordering releation must be defined.
/// - `V`: type of values.
pub fn LLRBTreeMap(comptime K: type, comptime V: type) type {
    return struct {
        /// The type `LLRBTreeMap` itself
        pub const Self: type = @This();
        /// Type of keys to ordering values.
        pub const Key: type = K;
        /// Type of values to be stored in the container.
        pub const Value: type = V;

        // tree implementation
        const Node = node.Node(Key, Value);

        /// Type of configuration parameters
        pub const Config: type = Node.Config;

        /// The allocator to allocate memory for internal Nodes.
        alloc: Allocator,
        root: ?*Node,
        cmp: compat.Func2(*const K, *const K, Order),
        cfg: Config,

        /// Build a Map by passing an allocator that allocates memory for internal nodes.
        pub fn new(alloc: Allocator, cfg: Config) Self {
            return .{ .alloc = alloc, .root = null, .cmp = Con.Ord.on(*const K), .cfg = cfg };
        }

        /// Build a Map like `new`, but takes an order function explicitly.
        /// The function must be a total order.
        pub fn with_cmp(alloc: Allocator, cfg: Config, cmp: compat.Func2(*const K, *const K, Order)) Self {
            return .{ .alloc = alloc, .root = null, .cmp = cmp, .cfg = cfg };
        }

        /// Destroy the Map
        ///
        /// # Details
        /// Deallocates memory of all remaining nodes in the Map.
        /// Memory owned by keys and values are not released.
        pub fn destroy(self: *Self) void {
            Node.check_inv(self.root);
            if (self.root) |root| {
                root.destroy(self.alloc, Config, &self.cfg);
                self.alloc.destroy(root);
                self.root = null;
            }
        }

        /// Returns an iterator which enumerates all key/value pairs of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all key/value paris of the tree.
        /// The keys of the pairs are enumerated by asceding order.
        ///
        /// # Notice
        /// The tree must not be modified while the iterator is alive.
        pub fn iter(self: *const Self) iters.Iter(Key, Value) {
            Node.check_inv(self.root);
            return iters.Iter(Key, Value).new(self.root, Node.get_item);
        }

        /// Returns an iterator which enumerates all keys of the tree by ascending order.
        ///
        /// # Details
        /// Returns an iterator which enumerates all keys of the tree by ascending order.
        ///
        /// # Notice
        /// The tree must not be modified while the iterator is alive.
        pub fn keys(self: *const Self) iters.Keys(Key, Value) {
            Node.check_inv(self.root);
            const proj = struct {
                fn key(n: *const Node) *const Key {
                    return Node.get_key(n.get_item());
                }
            };
            return iters.Keys(Key, Value).new(self.root, proj.key);
        }

        /// Returns an iterator which enumerates all values of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all values of the tree.
        /// Values are enumerated in ascending order of the associated key.
        ///
        /// # Notice
        /// The tree must not be modified while the iterator is alive.
        pub fn values(self: *const Self) iters.Values(Key, Value) {
            Node.check_inv(self.root);
            const proj = struct {
                fn value(n: *const Node) *const Value {
                    return Node.get_value(n.get_item());
                }
            };
            return iters.Values(Key, Value).new(self.root, proj.value);
        }

        /// Insert the `key` and an associated `value` to the tree `self`.
        ///
        /// # Details
        /// Insert the `key` and an associated `value` to the tree `self`.
        /// If the key exists in the tree, the old value is replaced with the new value.
        /// And the old value is returned.
        /// Otherwise, `null` is returned.
        pub fn insert(self: *Self, key: Key, value: Value) Allocator.Error!?Value {
            Node.check_inv(self.root);
            const oldopt = try Node.insert(&self.root, self.alloc, key_value.make(key, value), self.cmp);
            self.root.?.color = .Black;
            Node.check_inv(self.root);
            if (oldopt) |old| {
                const tup = old.toTuple();
                switch (self.cfg.key) {
                    .OwnedAlloc => |key_alloc| Con.Destroy.destroy(tup[0], key_alloc),
                    .Owned => Con.Destroy.destroy(tup[0], self.alloc),
                    .NotOwned => {},
                }
                return tup[1];
            } else return null;
        }

        /// Delete a value for the specified `key`.
        ///
        /// # Details
        /// Delete a value for the specified `key`.
        /// If it exists, the value associated to the `key` is returned.
        /// If it is not found, `null` is returned.
        pub fn delete(self: *Self, key: *const Key) ?Value {
            Node.check_inv(self.root);
            return if (self.delete_entry(key)) |kv| kv.toTuple()[1] else null;
        }

        /// Delete an entry for the specified `key`.
        ///
        /// # Details
        /// Delete an entry for the specified `key`.
        /// If it exists, the key/value pair is returned.
        /// If it is not found, `null` is returned.
        pub fn delete_entry(self: *Self, key: *const Key) ?KeyValue(Key, Value) {
            Node.check_inv(self.root);
            const old = Node.delete(&self.root, self.alloc, key, self.cmp);
            if (self.root) |sroot|
                sroot.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Delete the key/value pair with the minimum key from the tree
        ///
        /// # Details
        /// Delete the key/value pair with the minimum key from the tree `self`, and returns the pair.
        /// And `null` is returned for empty tree.
        pub fn delete_min(self: *Self) ?KeyValue(Key, Value) {
            Node.check_inv(self.root);
            var old = Node.delete_min(&self.root, self.alloc);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Delete the key/value pair with the maximum key from the tree
        ///
        /// # Details
        /// Delete the key/value pair with the maximum key from the tree `self`, and returns the pair.
        /// And `null` is returned for empty tree.
        pub fn delete_max(self: *Self) ?KeyValue(Key, Value) {
            Node.check_inv(self.root);
            var old = Node.delete_max(&self.root, self.alloc);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Checks to see if it contains a value for the specified `key`.
        pub fn contains_key(self: *const Self, key: *const Key) bool {
            Node.check_inv(self.root);
            return Node.contains_key(self.root, key, self.cmp);
        }

        /// Checks whether a node contains a value equal to `value` and returns a pointer to that value.
        /// If not found, returns `null`.
        pub fn get(self: *const Self, key: *const Key) ?*const Value {
            Node.check_inv(self.root);
            return if (Node.get(self.root, key, self.cmp)) |kv| kv.value() else null;
        }

        /// Get an entry specified with `key`
        ///
        /// # Details
        /// Searches for the node specified by `key` and returns the corresponding [`entry.Entry`].
        /// If the node is found, an [`entry.Entry.Occupied`] entry is returned.
        /// Otherwise, a [`entry.Entry.Vacant`] entry is returned.
        pub fn entry(self: *Self, key: Key) Entry(Key, Value) {
            Node.check_inv(self.root);
            return Node.entry(&self.root, self.alloc, key, self.cmp);
        }
    };
}

test "simple insert" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);

    var tree = Tree.new(alloc, .{});
    defer tree.destroy();

    var values = [_]u32{ 0, 1, 2, 3, 4 };

    for (values) |v|
        try testing.expectEqual(@as(?u32, null), try tree.insert(v, v));
}

test "insert" {
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;

    var tree = Tree.new(alloc, .{});
    defer tree.destroy();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = @as(u32, random.int(u4));
        // std.debug.print("v: {}th... {}\n", .{ i, v });
        if (try tree.insert(v, v)) |x| {
            // std.debug.print("already exist: {}\n", .{old});
            try testing.expectEqual(v, x);
        }
    }
}

test "insert (not owned string key)" {
    const fmt = std.fmt;
    const testing = std.testing;
    const alloc = testing.allocator;

    const Map = LLRBTreeMap([]const u8, u32);
    const num: usize = 20;
    var keys: [num][]const u8 = undefined;
    {
        var i: usize = 0;
        while (i < num) : (i = i + 1)
            keys[i] = try fmt.allocPrint(alloc, "key{}", .{i});
    }
    defer for (keys) |key| Con.Destroy.destroy(key, alloc);

    // the Map not owned keys
    var map = Map.with_cmp(alloc, .{ .key = .NotOwned }, string_cmp.order);
    defer map.destroy();

    for (keys) |key, i|
        try testing.expect(null == try map.insert(key, @intCast(u32, i)));
}

test "insert (owned string key)" {
    const fmt = std.fmt;
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Map = LLRBTreeMap([]const u8, u32);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;
    var map = Map.with_cmp(alloc, .{}, string_cmp.order);
    defer map.destroy();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v: u32 = random.int(u4);
        const k = try fmt.allocPrint(alloc, "key{}", .{v});
        // std.debug.print("v: {}th... \"{s}\" ==> {}\n", .{ i, k, v });
        if (try map.insert(k, v)) |old| {
            try testing.expect(map.get(&k) != null);
            // std.debug.print("already exist value for: \"{}\"\n", .{old});
            Con.Destroy.destroy(old, alloc);
        }
    }
}

test "insert (not owned value)" {
    const fmt = std.fmt;
    const testing = std.testing;
    const alloc = testing.allocator;

    const Map = LLRBTreeMap(u32, []const u8);
    const num: usize = 20;
    var values: [num][]const u8 = undefined;
    {
        var i: usize = 0;
        while (i < num) : (i = i + 1)
            values[i] = try fmt.allocPrint(alloc, "key{}", .{i});
    }
    defer for (values) |value| Con.Destroy.destroy(value, alloc);

    // the Map not owned keys
    var map = Map.new(alloc, .{ .value = .NotOwned });
    defer map.destroy();

    for (values) |value, i|
        try testing.expect(null == try map.insert(@intCast(u32, i), value));
}

test "contains_key" {
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeMap(u32, u32);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(alloc, .{});
    defer tree.destroy();

    var values = Array(u32).init(alloc);
    defer values.deinit();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = random.int(u32);
        try values.append(v);
        if (try tree.insert(v, v)) |x| {
            try testing.expectEqual(v, x);
        }
    }

    for (values.items) |item|
        assert(tree.contains_key(&item));
}

test "get" {
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeMap(u32, u32);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(alloc, .{});
    defer tree.destroy();

    var values = Array(u32).init(alloc);
    defer values.deinit();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = random.int(u32);
        try values.append(v);
        if (try tree.insert(v, v)) |x| {
            try testing.expectEqual(v, x);
        }
    }

    for (values.items) |item| {
        try testing.expectEqual(tree.get(&item).?.*, item);
    }
}

test "delete_min" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const alloc = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(alloc, .{});
        defer tree.destroy();

        var values = Array(u32).init(alloc);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            _ = try tree.insert(v, v);
        }

        assert(tree.root != null);

        i = 0;
        var min: u32 = 0;
        while (values.popOrNull()) |_| : (i += 1) {
            const p = @mod(i, num / 10) == 0;
            _ = p;
            if (tree.delete_min()) |rm| {
                // if (p) std.debug.print("v: {}th... {}\n", .{ i, rm });
                assert(min <= rm.key().*);
                min = rm.key().*;
            } else {
                // if (p) std.debug.print("v: {}th... none\n", .{i});
            }
        }
    }
}

test "delete_max" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const alloc = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(alloc, .{});
        defer tree.destroy();

        var values = Array(u32).init(alloc);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            if (try tree.insert(v, v)) |old| {
                assert(v == old);
            }
        }

        i = 0;
        var max: u32 = std.math.maxInt(u32);
        while (values.popOrNull()) |_| : (i += 1) {
            // const p = @mod(i, num / 10) == 0;
            if (tree.delete_max()) |rm| {
                // if (p) std.debug.print("v: {}th... {}\n", .{ i, rm });
                assert(rm.key().* <= max);
                max = rm.key().*;
            } else {
                // if (p) std.debug.print("v: {}th... none\n", .{i});
            }
        }
    }
}

test "insert / delete" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const alloc = testing.allocator;

    {
        var tree = LLRBTreeMap(i32, i32).new(alloc, .{});
        // all nodes would be destroyed
        // defer tree.destroy();
        var i: i32 = 0;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(try tree.insert(i, i), null);
        i -= 1;
        while (i >= 0) : (i -= 1)
            try testing.expectEqual(try tree.insert(i, i), i);
        i += 1;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(tree.delete(&i), i);
        i -= 1;
        while (i >= 0) : (i -= 1)
            try testing.expectEqual(tree.delete(&i), null);
    }
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = LLRBTreeMap(u32, u32).new(alloc, .{});
        // all nodes would be destroyed
        // defer tree.destroy();

        var values = Array(u32).init(alloc);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            if (try tree.insert(v, v)) |in|
                assert(v == in);
        }

        while (values.popOrNull()) |v| {
            if (tree.delete(&v)) |rm|
                assert(v == rm);
        }
    }
}

test "entry" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const alloc = testing.allocator;

    {
        var tree = LLRBTreeMap(i32, i32).new(alloc, .{});
        // all nodes would be destroyed
        defer tree.destroy();
        var i: i32 = 0;
        while (i <= 5) : (i += 1) {
            try testing.expect(!tree.contains_key(&i));
            var entry_ = tree.entry(i);
            try testing.expectEqual(i, entry_.get_key().*);
            try testing.expectEqual(i, (try entry_.or_insert(i)).*);
            try testing.expectEqual(i, tree.get(&i).?.*);
        }
        i -= 1;
        while (i >= 0) : (i -= 1) {
            try testing.expectEqual(i, tree.get(&i).?.*);
            var entry_ = tree.entry(i);
            try testing.expectEqual(i, entry_.get_key().*);
            try testing.expectEqual(i, (try entry_.or_insert(i)).*);
        }
        i = 0;
        while (i <= 5) : (i += 1) {
            try testing.expectEqual(i, tree.get(&i).?.*);
            var entry_ = tree.entry(i);
            try testing.expectEqual(i, entry_.get_key().*);
            _ = entry_.modify(struct {
                fn inc(v: *i32) void {
                    v.* += 1;
                }
            }.inc);
            try testing.expectEqual(i + 1, tree.get(&i).?.*);
        }
        i = 0;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(@as(?i32, i + 1), tree.delete(&i));
        i -= 1;
        while (i >= 0) : (i -= 1)
            try testing.expectEqual(@as(?i32, null), tree.delete(&i));
    }
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = LLRBTreeMap(u32, u32).new(alloc, .{});
        // all nodes would be destroyed
        // defer tree.destroy();

        var values = Array(u32).init(alloc);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            var entry_ = tree.entry(v);
            try testing.expectEqual(v, (try entry_.or_insert(v)).*);
        }

        while (values.popOrNull()) |v| {
            if (tree.delete(&v)) |rm|
                assert(v == rm);
        }
    }
    {
        var map = LLRBTreeMap(u32, []const u8).new(alloc, .{ .value = .NotOwned });
        defer map.destroy();
        _ = try map.insert(42, "foo");
        var entry_ = map.entry(42);
        _ = entry_.modify(struct {
            fn bar(s: *[]const u8) void {
                s.* = "bar";
            }
        }.bar);
        try testing.expectEqualStrings("bar", map.get(&@as(u32, 42)).?.*);
    }
}

test "iter" {
    const testing = std.testing;
    const KV = key_value.KeyValue;
    {
        const Tree = LLRBTreeMap(i32, i32);
        const kv = struct {
            // specialized to the Key, Value types
            fn constructor(k: Tree.Key, v: Tree.Value) KV(Tree.Key, Tree.Value) {
                return key_value.make(k, v);
            }
        }.constructor;
        var tree = Tree.new(testing.allocator, .{});
        defer tree.destroy();

        try testing.expectEqual(try tree.insert(5, 5), null);
        try testing.expectEqual(try tree.insert(1, 1), null);
        try testing.expectEqual(try tree.insert(0, 0), null);
        try testing.expectEqual(try tree.insert(2, 2), null);
        try testing.expectEqual(try tree.insert(4, 4), null);
        try testing.expectEqual(try tree.insert(3, 3), null);

        var iter = tree.iter();
        // values are enumerated by asceding order
        try testing.expectEqual(iter.next().?.*, kv(0, 0));
        try testing.expectEqual(iter.next().?.*, kv(1, 1));
        try testing.expectEqual(iter.next().?.*, kv(2, 2));
        try testing.expectEqual(iter.next().?.*, kv(3, 3));
        try testing.expectEqual(iter.next().?.*, kv(4, 4));
        try testing.expectEqual(iter.next().?.*, kv(5, 5));
        try testing.expectEqual(iter.next(), null);

        var iter2 = tree.iter().map_while(struct {
            fn pred(v: *const KV(Tree.Key, Tree.Value)) ?i32 {
                const t = v.toTuple();
                return if (t[0] * t[1] < 10) t[0] * t[1] else null;
            }
        }.pred).flat_map(struct {
            fn map(v: i32) iter_zig.Range(i32) {
                // v -> [v, v+1]
                return iter_zig.range(v, v + 2);
            }
        }.map);
        try testing.expectEqual(@as(i32, 0), iter2.next().?);
        try testing.expectEqual(@as(i32, 1), iter2.next().?);
        try testing.expectEqual(@as(i32, 1), iter2.next().?);
        try testing.expectEqual(@as(i32, 2), iter2.next().?);
        try testing.expectEqual(@as(i32, 4), iter2.next().?);
        try testing.expectEqual(@as(i32, 5), iter2.next().?);
        try testing.expectEqual(@as(i32, 9), iter2.next().?);
        try testing.expectEqual(@as(i32, 10), iter2.next().?);
        try testing.expectEqual(@as(?i32, null), iter2.next());
    }
    {
        var tree = LLRBTreeMap(i32, i32).new(testing.allocator, .{});
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, i), null);
        i = 1;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, i), null);

        var iter = tree.iter();
        var old: LLRBTreeMap(i32, i32).Value = -1;
        while (iter.next()) |item| {
            // std.debug.print("item: {}\n", .{item.*});
            assert(old < item.key().*);
            old = item.key().*;
        }
    }
}

test "keys" {
    const testing = std.testing;
    {
        const Tree = LLRBTreeMap(i32, i32);
        var tree = Tree.new(testing.allocator, .{});
        defer tree.destroy();

        try testing.expectEqual(try tree.insert(5, 5), null);
        try testing.expectEqual(try tree.insert(1, 1), null);
        try testing.expectEqual(try tree.insert(0, 0), null);
        try testing.expectEqual(try tree.insert(2, 2), null);
        try testing.expectEqual(try tree.insert(4, 4), null);
        try testing.expectEqual(try tree.insert(3, 3), null);

        var keys = tree.keys();
        // keys are enumerated by asceding order
        try testing.expectEqual(keys.next().?.*, 0);
        try testing.expectEqual(keys.next().?.*, 1);
        try testing.expectEqual(keys.next().?.*, 2);
        try testing.expectEqual(keys.next().?.*, 3);
        try testing.expectEqual(keys.next().?.*, 4);
        try testing.expectEqual(keys.next().?.*, 5);
        try testing.expectEqual(keys.next(), null);
    }
    {
        var tree = LLRBTreeMap(i32, f64).new(testing.allocator, .{});
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, @intToFloat(f64, i * 2)), null);
        i = 1;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, @intToFloat(f64, i * 2)), null);

        var keys = tree.keys();
        try testing.expectEqual(@as(usize, 4097), keys.count());
        keys = tree.keys();
        var old: LLRBTreeMap(i32, f64).Key = -1;
        while (keys.next()) |key| {
            // std.debug.print("item: {}\n", .{item.*});
            assert(old < key.*);
            old = key.*;
        }
        try testing.expectEqual(@as(i32, 0), tree.keys().min().?.*);
    }
}

test "value" {
    const testing = std.testing;
    {
        const Tree = LLRBTreeMap(i32, i32);
        var tree = Tree.new(testing.allocator, .{});
        defer tree.destroy();

        try testing.expectEqual(try tree.insert(5, 0), null);
        try testing.expectEqual(try tree.insert(1, 4), null);
        try testing.expectEqual(try tree.insert(0, 5), null);
        try testing.expectEqual(try tree.insert(2, 3), null);
        try testing.expectEqual(try tree.insert(4, 1), null);
        try testing.expectEqual(try tree.insert(3, 2), null);

        var values = tree.values();
        // values are enumerated by asceding order of key
        try testing.expectEqual(values.next().?.*, 5);
        try testing.expectEqual(values.next().?.*, 4);
        try testing.expectEqual(values.next().?.*, 3);
        try testing.expectEqual(values.next().?.*, 2);
        try testing.expectEqual(values.next().?.*, 1);
        try testing.expectEqual(values.next().?.*, 0);
        try testing.expectEqual(values.next(), null);
    }
    {
        var tree = LLRBTreeMap(i32, i32).new(testing.allocator, .{});
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, i), null);
        i = 1;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i, i), null);

        {
            var values = tree.values();
            try testing.expectEqual(@as(usize, 4097), values.count());
        }
        var values = tree.values().filter(struct {
            fn pred(v: *const i32) bool {
                // 0, 1000, 2000, 3000, 4000
                return @mod(v.*, 1000) == 0;
            }
        }.pred).map(struct {
            fn map(v: *const i32) i32 {
                // 0, 1, 2, 3, 4
                return @divExact(v.*, 1000);
            }
        }.map);

        try testing.expectEqual(@as(?i32, 0), values.next());
        try testing.expectEqual(@as(?i32, 1), values.next());
        try testing.expectEqual(@as(?i32, 2), values.next());
        try testing.expectEqual(@as(?i32, 3), values.next());
        try testing.expectEqual(@as(?i32, 4), values.next());
        try testing.expectEqual(@as(?i32, null), values.next());
    }
}
