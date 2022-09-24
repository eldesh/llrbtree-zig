const std = @import("std");
const Con = @import("basis_concept");
const node_color = @import("../node_color.zig");
const node = @import("./node.zig");
pub const key_value = @import("./key_value.zig");
pub const entry = @import("./entry.zig");
pub const iters = @import("./iter.zig");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;
const KeyValue = key_value.KeyValue;
const Entry = entry.Entry;

/// A key/value container.
///
/// # Details
/// This function returns that a key/value container using Left-leaning Red-Black Tree algorithm.
/// All values are associated for each keys, and all key/value pairs are stored based on order relation of the keys.
///
/// # Requirements
/// `K` is a type for which an ordering relation is given.
/// This means `Con.isPartialOrd(K)` evaluates to `true`.
pub fn LLRBTreeMap(comptime K: type, comptime V: type) type {
    comptime assert(Con.isPartialOrd(K));

    return struct {
        pub const Self = @This();
        pub const Key = K;
        pub const Value = V;

        // tree implementation
        const Node = node.Node(Key, Value);

        allocator: Allocator,
        root: ?*Node,

        pub fn new(allocator: Allocator) Self {
            return .{ .allocator = allocator, .root = null };
        }

        pub fn destroy(self: *Self) void {
            Node.check_inv(self.root);
            Node.destroy(self.root, self.allocator);
            self.root = null;
        }

        /// Returns an iterator which enumerates all key/value pairs of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all key/value paris of the tree.
        /// The keys of the paris are enumerated by asceding order.
        /// Also, the tree must no be modified while the iterator is alive.
        pub fn iter(self: *const Self) iters.Iter(Key, Value) {
            Node.check_inv(self.root);
            return iters.Iter(Key, Value).new(self.root);
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
            const oldopt = try Node.insert(&self.root, self.allocator, key_value.make(key, value));
            self.root.?.color = .Black;
            Node.check_inv(self.root);
            return if (oldopt) |old| old.toTuple()[1] else null;
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
            const old = Node.delete(&self.root, self.allocator, key);
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
            var old = Node.delete_min(&self.root, self.allocator);
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
            var old = Node.delete_max(&self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Checks to see if it contains a value for the specified `key`.
        pub fn contains_key(self: *const Self, key: *const Key) bool {
            Node.check_inv(self.root);
            return Node.contains_key(self.root, key);
        }

        /// Checks whether a node contains a value equal to `value` and returns a pointer to that value.
        /// If not found, returns `null`.
        pub fn get(self: *const Self, key: *const Key) ?*const Value {
            Node.check_inv(self.root);
            return if (Node.get(self.root, key)) |kv| kv.value() else null;
        }

        /// Get an entry specified with `key`
        ///
        /// # Details
        /// Searches for the node specified by `key` and returns the corresponding [`entry.Entry`].
        /// If the node is found, an [`entry.Entry.Occupied`] entry is returned.
        /// Otherwise, a [`entry.Entry.Vacant`] entry is returned.
        pub fn entry(self: *Self, key: Key) Entry(Key, Value) {
            Node.check_inv(self.root);
            return Node.entry(&self.root, self.allocator, key);
        }
    };
}

test "simple insert" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);

    var tree = Tree.new(allocator);
    defer tree.destroy();

    var values = [_]u32{ 0, 1, 2, 3, 4 };

    for (values) |v|
        try testing.expectEqual(try tree.insert(v, v), null);
}

test "insert" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;

    var tree = Tree.new(allocator);
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

test "contains_key" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeMap(u32, u32);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(allocator);
    defer tree.destroy();

    var values = Array(u32).init(allocator);
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
    const allocator = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeMap(u32, u32);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(allocator);
    defer tree.destroy();

    var values = Array(u32).init(allocator);
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
    const allocator = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(allocator);
        defer tree.destroy();

        var values = Array(u32).init(allocator);
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
    const allocator = testing.allocator;

    const Tree = LLRBTreeMap(u32, u32);
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(allocator);
        defer tree.destroy();

        var values = Array(u32).init(allocator);
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
    const allocator = testing.allocator;

    {
        var tree = LLRBTreeMap(i32, i32).new(testing.allocator);
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

        var tree = LLRBTreeMap(u32, u32).new(allocator);
        // all nodes would be destroyed
        // defer tree.destroy();

        var values = Array(u32).init(allocator);
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
    const allocator = testing.allocator;

    {
        var tree = LLRBTreeMap(i32, i32).new(testing.allocator);
        // all nodes would be destroyed
        // defer tree.destroy();
        var i: i32 = 0;
        while (i <= 5) : (i += 1) {
            var entry_ = tree.entry(i);
            try testing.expectEqual(i, entry_.get_key().*);
            try testing.expectEqual(i, (try entry_.insert(i)).*);
        }
        i -= 1;
        while (i >= 0) : (i -= 1) {
            var entry_ = tree.entry(i);
            try testing.expectEqual(entry_.get_key().*, i);
            try testing.expectEqual(i, (try entry_.insert(i)).*);
        }
        i = 0;
        while (i <= 5) : (i += 1) {
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

        var tree = LLRBTreeMap(u32, u32).new(allocator);
        // all nodes would be destroyed
        // defer tree.destroy();

        var values = Array(u32).init(allocator);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            var entry_ = tree.entry(v);
            try testing.expectEqual(v, (try entry_.insert(v)).*);
        }

        while (values.popOrNull()) |v| {
            if (tree.delete(&v)) |rm|
                assert(v == rm);
        }
    }
}

test "values" {
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
        var tree = Tree.new(testing.allocator);
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(try tree.insert(i, i), null);

        var iter = tree.iter();

        // values are enumerated by asceding order
        try testing.expectEqual(iter.next().?.*, kv(0, 0));
        try testing.expectEqual(iter.next().?.*, kv(1, 1));
        try testing.expectEqual(iter.next().?.*, kv(2, 2));
        try testing.expectEqual(iter.next().?.*, kv(3, 3));
        try testing.expectEqual(iter.next().?.*, kv(4, 4));
        try testing.expectEqual(iter.next().?.*, kv(5, 5));
        try testing.expectEqual(iter.next(), null);
    }
    {
        var tree = LLRBTreeMap(i32, i32).new(testing.allocator);
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 1)
            try testing.expectEqual(try tree.insert(i, i), null);

        var iter = tree.iter();
        while (iter.next()) |item| {
            _ = item;
            // std.debug.print("item: {}\n", .{item.*});
        }
    }
}
