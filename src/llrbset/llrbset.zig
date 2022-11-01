const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");

const node_color = @import("../node_color.zig");
const string_cmp = @import("../string_cmp.zig");
const node = @import("./node.zig");
pub const config = @import("./config.zig");
pub const iters = @import("./iter.zig");

const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;

/// A value set container.
///
/// # Details
/// This function returns that a value container using Left-leaning Red-Black Tree algorithm.
/// All values are stored based on it's order relation.
///
/// Note that the releation must be total ordering.
/// If `basis_concept.isOrd(T)` evaluates to `true`, then the automatically derived total function is used.
/// Otherwise, an ordering function must be explicitly passed via `with_cmp`.
///
/// # Arguments
/// - `T`: type of values, and a total ordering releation must be defined.
/// - `A`: allocator allocates memory for inner nodes of data structures.
pub fn LLRBTreeSet(comptime T: type, comptime A: Allocator) type {
    return struct {
        /// The type `LLRBTreeSet` itself
        pub const Self: type = @This();
        pub const Item: type = T;
        /// Type of allocator to allocate memory for internal Nodes.
        pub const Alloc: Allocator = A;

        /// Type of configuration parameters
        pub const Config: type = config.Config(Alloc);

        // tree implementation
        const Node = node.Node(Item, Alloc);

        root: ?*Node,
        cmp: fn (*const T, *const T) Order,
        cfg: Config,

        /// Build a Set by passing an allocator that allocates memory for internal nodes.
        pub fn new(cfg: Config) Self {
            return .{ .root = null, .cmp = Con.Ord.on(*const T), .cfg = cfg };
        }

        /// Build a Set of T like `new`, but takes an order function explicitly.
        /// The function must be a total order.
        pub fn with_cmp(cfg: Config, cmp: fn (*const T, *const T) Order) Self {
            return .{ .root = null, .cmp = cmp, .cfg = cfg };
        }

        /// Destroy the Set
        ///
        /// # Details
        /// Deallocates memory of all remaining nodes in the Set.
        /// Memory owned by values are not released.
        pub fn destroy(self: *Self) void {
            Node.check_inv(self.root);
            if (self.root) |root| {
                root.destroy(Config, &self.cfg);
                Alloc.destroy(root);
                self.root = null;
            }
        }

        /// Returns an iterator which enumerates all values of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all values of the tree.
        /// The values are enumerated by asceding order.
        /// Also, the tree must no be modified while the iterator is alive.
        pub fn iter(self: *const Self) iters.Iter(Item, Alloc) {
            Node.check_inv(self.root);
            return iters.Iter(Item, Alloc).new(self.root, Node.get_item);
        }

        /// Insert the value `value` to the tree `self`.
        ///
        /// # Details
        /// Insert the value `value` to the tree `self`.
        /// If a value equals to `value` exists in the tree, the old value is replaced with the new value.
        /// And the old value is returned.
        /// Otherwise, `null` is returned.
        pub fn insert(self: *Self, value: T) Allocator.Error!?T {
            Node.check_inv(self.root);
            const old = try Node.insert(&self.root, value, self.cmp);
            self.root.?.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Delete a node which have a value equals to `value`.
        ///
        /// # Details
        /// Delete a node which have a value equals to `value`.
        /// If it exists, it is returned.
        /// If it is not found, `null` is returned.
        pub fn delete(self: *Self, value: *const T) ?T {
            Node.check_inv(self.root);
            const old = Node.delete(&self.root, value, self.cmp);
            if (self.root) |sroot|
                sroot.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Delete the minimum element from tree
        ///
        /// # Details
        /// Delete the minimum element from tree `self`, and returns it.
        /// And `null` is returned for empty tree.
        pub fn delete_min(self: *Self) ?T {
            Node.check_inv(self.root);
            const old = Node.delete_min(&self.root);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Delete the maximum element from tree
        ///
        /// # Details
        /// Delete the maximum element from tree `self`, and returns it.
        /// And `null` is returned for empty tree.
        pub fn delete_max(self: *Self) ?T {
            Node.check_inv(self.root);
            const old = Node.delete_max(&self.root);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Checks to see if it contains a node with a value equal to `value`.
        pub fn contains(self: *const Self, value: *const T) bool {
            Node.check_inv(self.root);
            return Node.contains_key(self.root, value, self.cmp);
        }

        /// Checks whether a node contains a value equal to `value` and returns a pointer to that value.
        /// If not found, returns `null`.
        pub fn get(self: *const Self, value: *const T) ?*const T {
            Node.check_inv(self.root);
            return Node.get(self.root, value, self.cmp);
        }
    };
}

test "simple insert" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32, allocator);

    var tree = Tree.new(.{});
    defer tree.destroy();

    var values = [_]u32{ 0, 1, 2, 3, 4 };

    for (values) |v|
        try testing.expectEqual(try tree.insert(v), null);
}

test "insert" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32, allocator);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;

    var tree = Tree.new(.{});
    defer tree.destroy();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = @as(u32, random.int(u4));
        // std.debug.print("v: {}th... {}\n", .{ i, v });
        if (try tree.insert(v)) |x| {
            // std.debug.print("already exist: {}\n", .{x});
            try testing.expectEqual(v, x);
        }
    }
}

test "insert (set of string)" {
    const fmt = std.fmt;
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Set = LLRBTreeSet([]const u8, allocator);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;
    var set = Set.with_cmp(.{}, string_cmp.order);
    defer set.destroy();
    defer while (set.delete_min()) |m| allocator.free(m);

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = try fmt.allocPrint(allocator, "value{}", .{random.int(u4)});
        // std.debug.print("v: {}th... \"{s}\"\n", .{ i, v });
        if (try set.insert(v)) |x| {
            // std.debug.print("already exist: \"{s}\"\n", .{x});
            try testing.expectEqualStrings(v, x);
            allocator.free(x);
        }
    }
}

test "contains" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeSet(u32, allocator);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(.{});
    defer tree.destroy();

    var values = Array(u32).init(allocator);
    defer values.deinit();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = random.int(u32);
        try values.append(v);
        if (try tree.insert(v)) |x| {
            try testing.expectEqual(v, x);
        }
    }

    for (values.items) |item|
        assert(tree.contains(&item));
}

test "get" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeSet(u32, allocator);

    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 2000;

    var tree = Tree.new(.{});
    defer tree.destroy();

    var values = Array(u32).init(allocator);
    defer values.deinit();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = random.int(u32);
        try values.append(v);
        if (try tree.insert(v)) |x| {
            try testing.expectEqual(v, x);
        }
    }

    for (values.items) |item| {
        try testing.expectEqual(tree.get(&item).?.*, item);
    }
}

test "delete_min" {
    const fmt = std.fmt;
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const allocator = testing.allocator;

    {
        const Tree = LLRBTreeSet(u32, allocator);
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(.{});
        defer tree.destroy();

        var values = Array(u32).init(allocator);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            _ = try tree.insert(v);
        }

        assert(tree.root != null);

        i = 0;
        var min: u32 = 0;
        while (values.popOrNull()) |_| : (i += 1) {
            const p = @mod(i, num / 10) == 0;
            _ = p;
            if (tree.delete_min()) |rm| {
                // if (p) std.debug.print("v: {}th... {}\n", .{ i, rm });
                assert(min <= rm);
                min = rm;
            } else {
                // if (p) std.debug.print("v: {}th... none\n", .{i});
            }
        }
    }
    {
        const Tree = LLRBTreeSet([]const u8, allocator);
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.with_cmp(.{}, string_cmp.order);
        defer tree.destroy();

        var values = Array([]const u8).init(allocator);
        defer values.deinit();
        defer while (values.popOrNull()) |m| allocator.free(m);

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = try fmt.allocPrint(allocator, "value{}", .{random.int(u32)});
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            if (try tree.insert(v)) |old|
                allocator.free(old);
        }

        assert(tree.root != null);

        var min: []const u8 = ("".*)[0..];
        for (values.items) |_, j| {
            _ = j;
            // const p = @mod(j, num / 10) == 0;
            if (tree.delete_min()) |rm| {
                // if (p) std.debug.print("v: {}th... {s}\n", .{ j, rm });
                try testing.expectEqual(Order.lt, string_cmp.order(&min, &rm));
                min = rm;
            } else {
                // if (p) std.debug.print("v: {}th... none\n", .{j});
            }
        }
    }
}

test "delete_max" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32, allocator);
    {
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.new(.{});
        defer tree.destroy();

        var values = Array(u32).init(allocator);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            if (try tree.insert(v)) |old| {
                assert(v == old);
            }
        }

        i = 0;
        var max: u32 = std.math.maxInt(u32);
        while (values.popOrNull()) |_| : (i += 1) {
            // const p = @mod(i, num / 10) == 0;
            if (tree.delete_max()) |rm| {
                // if (p) std.debug.print("v: {}th... {}\n", .{ i, rm });
                assert(rm <= max);
                max = rm;
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
        var tree = LLRBTreeSet(i32, allocator).new(.{});
        // all nodes would be destroyed
        // defer tree.destroy();
        var i: i32 = 0;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(try tree.insert(i), null);
        i -= 1;
        while (i >= 0) : (i -= 1)
            try testing.expectEqual(try tree.insert(i), i);
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

        var tree = LLRBTreeSet(u32, allocator).new(.{});
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
            if (try tree.insert(v)) |in|
                assert(v == in);
        }

        while (values.popOrNull()) |v| {
            if (tree.delete(&v)) |rm|
                assert(v == rm);
        }
    }
}

test "values" {
    const testing = std.testing;
    const allocator = testing.allocator;
    {
        var tree = LLRBTreeSet(i32, allocator).new(.{});
        defer tree.destroy();

        var i: i32 = 5;
        while (0 <= i) : (i -= 1)
            try testing.expectEqual(try tree.insert(i), null);

        var iter = tree.iter();
        defer iter.destroy();

        // values are enumerated by asceding order
        try testing.expectEqual(iter.next().?.*, 0);
        try testing.expectEqual(iter.next().?.*, 1);
        try testing.expectEqual(iter.next().?.*, 2);
        try testing.expectEqual(iter.next().?.*, 3);
        try testing.expectEqual(iter.next().?.*, 4);
        try testing.expectEqual(iter.next().?.*, 5);
        try testing.expectEqual(iter.next(), null);
    }
    {
        var tree = LLRBTreeSet(i32, allocator).new(.{});
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i), null);
        i = 1;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i), null);

        var iter = tree.iter();
        defer iter.destroy();
        var old: LLRBTreeSet(i32, allocator).Item = -1;
        while (iter.next()) |item| {
            // std.debug.print("item: {}\n", .{item.*});
            assert(old < item.*);
            old = item.*;
        }
    }
}
