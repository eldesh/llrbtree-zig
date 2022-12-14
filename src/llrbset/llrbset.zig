const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");

const color = @import("../color.zig");
const string_cmp = @import("../string_cmp.zig");
const node = @import("./node.zig");
const compat = @import("../compat.zig");

pub const config = @import("./config.zig");
pub const iter = @import("./iter.zig");

const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const assert = std.debug.assert;

/// A value set container.
///
/// # Details
/// This function returns that a value container using Left-leaning Red-Black Tree algorithm.
/// All values are stored based on it's order relation.
///
/// Note that the releation must be total ordering.
/// If `basis_concept.isOrd(T)` evaluates to `true`, then the automatically derived ordering function is used.
/// Otherwise, an ordering function must be explicitly passed via `with_cmp`.
///
/// # Arguments
/// - `T`: type of value to be held in the container, for which a total ordering relation must be defined.
pub fn LLRBTreeSet(comptime T: type) type {
    return struct {
        /// The type `LLRBTreeSet` itself
        pub const Self: type = @This();
        pub const Item: type = T;

        // type of node of tree structure
        const Node = node.Node(Item);

        /// Type of ownership configuration parameters.
        /// By default, it represents that items are owned by the set.
        pub const Config: type = Node.Config;
        /// Shorthand for representing that items in the set are not owned.
        pub const NotOwned: Config = Config{ .item = .NotOwned };

        alloc: Allocator,
        root: ?*Node,
        cmp: compat.Func2(*const T, *const T, Order),
        cfg: Config,

        /// Build a Set with an allocator and ownership config of items.
        ///
        /// # Details
        /// Build a Set with an allocator and ownership config of items.
        /// The allocator that allocates memory for internal nodes.
        ///
        /// # Requires
        /// The type `T` must satisfy the predicate `Con.isOrd`.
        ///
        /// # Examples
        ///
        /// Construct a set that owns items typed `T`.
        ///
        /// ```
        /// var set = Set(T).new(alloc, .{});
        /// ```
        ///
        /// Construct a set that not owns items typed `T`.
        ///
        /// ```
        /// var set = Set(T).new(alloc, Set(T).NotOwned);
        /// ```
        pub fn new(alloc: Allocator, cfg: Config) Self {
            comptime assert(Con.isOrd(T));
            return .{
                .alloc = alloc,
                .root = null,
                .cmp = Con.Ord.on(*const T),
                .cfg = cfg,
            };
        }

        /// Build a Set with an allocator, an ownership config of items and a comparator.
        ///
        /// # Details
        /// Build a Set of values are typed `T` like `new`, but takes an order function explicitly.
        ///
        /// # Requires
        /// The comparator `cmp` must be a total order function for type `T`.
        pub fn with_cmp(alloc: Allocator, cfg: Config, cmp: compat.Func2(*const T, *const T, Order)) Self {
            return .{
                .alloc = alloc,
                .root = null,
                .cmp = cmp,
                .cfg = cfg,
            };
        }

        /// Destroy the set
        ///
        /// # Details
        /// Deallocates memory of all remaining nodes in the set.
        /// Items held in the set are destroyed if it is owned by the set.
        pub fn destroy(self: *Self) void {
            Node.check_inv(self.root);
            if (self.root) |root| {
                root.destroy(self.alloc, Config, &self.cfg);
                self.alloc.destroy(root);
                self.root = null;
            }
        }

        /// Returns an iterator which enumerates all values of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all values of the tree.
        /// The values are enumerated by asceding order.
        /// Also, the tree must not be modified while the iterator is alive.
        pub fn to_iter(self: *const Self) iter.Iter(Item) {
            Node.check_inv(self.root);
            return iter.Iter(Item).new(self.root, Node.get_item);
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
            const old = try Node.insert(&self.root, self.alloc, value, self.cmp);
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
            const old = Node.delete(&self.root, self.alloc, value, self.cmp);
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
            const old = Node.delete_min(&self.root, self.alloc);
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
            const old = Node.delete_max(&self.root, self.alloc);
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
    const alloc = testing.allocator;

    const Tree = LLRBTreeSet(u32);

    var tree = Tree.new(alloc, .{});
    defer tree.destroy();

    var values = [_]u32{ 0, 1, 2, 3, 4 };

    for (values) |v|
        try testing.expectEqual(try tree.insert(v), null);
}

test "insert" {
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Tree = LLRBTreeSet(u32);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;

    var tree = Tree.new(alloc, .{});
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
    const alloc = testing.allocator;

    const Set = LLRBTreeSet([]const u8);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;
    var set = Set.with_cmp(alloc, .{}, string_cmp.order);
    defer set.destroy();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = try fmt.allocPrint(alloc, "value{}", .{random.int(u4)});
        // std.debug.print("v: {}th... \"{s}\"\n", .{ i, v });
        if (try set.insert(v)) |x| {
            // std.debug.print("already exist: \"{s}\"\n", .{x});
            try testing.expectEqualStrings(v, x);
            Con.Destroy.destroy(x, alloc);
        }
    }
}

test "insert (set of not owned string)" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const Set = LLRBTreeSet([]const u8);
    var set = Set.with_cmp(alloc, Set.NotOwned, string_cmp.order);
    // Items in the set are `NotOwned` and are not destroyed.
    defer set.destroy();

    const num: usize = 20;
    var items: [num][]const u8 = init: {
        var items: [num][]const u8 = undefined;
        var i: usize = 0;
        while (i < num) : (i += 1) {
            items[i] = try std.fmt.allocPrint(alloc, "value{}", .{i});
            // std.debug.print("v: {}th... \"{s}\"\n", .{ i, v });
        }
        break :init items;
    };
    // Items are owned by variable `keys`.
    defer for (items) |item| alloc.free(item);

    for (items) |item|
        try testing.expectEqual(@as(?Set.Item, null), try set.insert(item));
}

test "contains" {
    const testing = std.testing;
    const rand = std.rand;
    const alloc = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeSet(u32);

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
    const alloc = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeSet(u32);

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
    const alloc = testing.allocator;

    {
        const Tree = LLRBTreeSet(u32);
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
        const Tree = LLRBTreeSet([]const u8);
        var rng = rand.DefaultPrng.init(0);
        const random = rng.random();
        const num: usize = 4096;

        var tree = Tree.with_cmp(alloc, .{}, string_cmp.order);
        defer tree.destroy();

        var values = Array([]const u8).init(alloc);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = try fmt.allocPrint(alloc, "value{}", .{random.int(u32)});
            // if (@mod(i, num / 10) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            if (try tree.insert(v)) |old|
                alloc.free(old);
        }

        assert(tree.root != null);

        var min: []const u8 = try fmt.allocPrint(alloc, "", .{});
        defer alloc.free(min);
        for (values.items) |_, j| {
            _ = j;
            // const p = @mod(j, num / 10) == 0;
            if (tree.delete_min()) |rm| {
                // if (p) std.debug.print("v: {}th... {s}\n", .{ j, rm });
                try testing.expectEqual(Order.lt, string_cmp.order(&min, &rm));
                alloc.free(min);
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
    const alloc = testing.allocator;

    const Tree = LLRBTreeSet(u32);
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
    const alloc = testing.allocator;

    {
        var tree = LLRBTreeSet(i32).new(alloc, .{});
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

        var tree = LLRBTreeSet(u32).new(alloc, .{});
        defer tree.destroy();

        var values = Array(u32).init(alloc);
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

        // all nodes would be destroyed
        while (values.popOrNull()) |v| {
            if (tree.delete(&v)) |rm|
                assert(v == rm);
        }
    }
}

test "values" {
    const testing = std.testing;
    const alloc = testing.allocator;
    {
        var tree = LLRBTreeSet(i32).new(alloc, .{});
        defer tree.destroy();

        var i: i32 = 5;
        while (0 <= i) : (i -= 1)
            try testing.expectEqual(try tree.insert(i), null);

        var it = tree.to_iter();
        defer it.destroy();

        // values are enumerated by asceding order
        try testing.expectEqual(it.next().?.*, 0);
        try testing.expectEqual(it.next().?.*, 1);
        try testing.expectEqual(it.next().?.*, 2);
        try testing.expectEqual(it.next().?.*, 3);
        try testing.expectEqual(it.next().?.*, 4);
        try testing.expectEqual(it.next().?.*, 5);
        try testing.expectEqual(it.next(), null);
    }
    {
        var tree = LLRBTreeSet(i32).new(alloc, .{});
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i), null);
        i = 1;
        while (i <= 4096) : (i += 2)
            try testing.expectEqual(try tree.insert(i), null);

        var it = tree.to_iter();
        defer it.destroy();
        var old: LLRBTreeSet(i32).Item = -1;
        while (it.next()) |item| {
            // std.debug.print("item: {}\n", .{item.*});
            assert(old < item.*);
            old = item.*;
        }
    }
}
