const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");
const node_color = @import("../node_color.zig");
pub const iters = @import("./iter.zig");

const math = std.math;

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;

pub fn LLRBTreeSet(comptime T: type) type {
    comptime assert(Con.isPartialOrd(T));

    return struct {
        pub const Self = @This();
        pub const Item = T;

        allocator: Allocator,
        root: ?*Node,

        pub const NodeError = error{
            TwoRedsInARow,
            NotLeftLeaning,
            PerfectBlackBalance,
        };

        pub const Node = struct {
            // color of the incoming link (from parent)
            color: NodeColor,
            value: T,
            // left child node
            lnode: ?*Node,
            // right child node
            rnode: ?*Node,

            fn check_inv(self: ?*@This()) void {
                // enabled only when Debug mode
                if (comptime builtin.mode != std.builtin.Mode.Debug)
                    return;

                if (self == null)
                    return;

                self.?.check_disallowed_2reds() catch unreachable;
                self.?.check_left_leaning() catch unreachable;
                self.?.check_perfect_black_balance() catch unreachable;
            }

            fn check_disallowed_2reds(self: *const @This()) NodeError!void {
                if (isRed(self)) {
                    if (isRed(self.lnode) or isRed(self.rnode))
                        return NodeError.TwoRedsInARow;
                }

                if (self.rnode) |rnode|
                    try rnode.check_disallowed_2reds();
                if (self.lnode) |lnode|
                    try lnode.check_disallowed_2reds();
            }

            // isRed(self.rnode) ==> isRed(self.lnode)
            fn check_left_leaning(self: *const @This()) NodeError!void {
                if (!isRed(self.rnode) or self.lnode == null or isRed(self.lnode)) {
                    if (self.rnode) |rnode|
                        try rnode.check_left_leaning();
                    if (self.lnode) |lnode|
                        try lnode.check_left_leaning();
                } else {
                    return NodeError.NotLeftLeaning;
                }
            }

            fn check_perfect_black_balance(self: @This()) NodeError!void {
                var self_ = self;
                var rblack: u32 = 0;
                var lblack: u32 = 0;

                var node: ?*Node = &self_;
                while (node) |n| : (node = n.rnode) {
                    if (!isRed(n.rnode))
                        rblack += 1;
                }
                node = &self_;
                while (node) |n| : (node = n.lnode) {
                    if (!isRed(n.lnode))
                        lblack += 1;
                }
                if (rblack != lblack) {
                    std.debug.print("balance: {} vs {}\n", .{ lblack, rblack });
                    return NodeError.PerfectBlackBalance;
                }
                if (self.rnode) |rnode|
                    try rnode.check_perfect_black_balance();
                if (self.lnode) |lnode|
                    try lnode.check_perfect_black_balance();
            }

            fn new(alloc: Allocator, value: T, lnode: ?*Node, rnode: ?*Node) Allocator.Error!*Node {
                var node = try alloc.create(Node);
                node.* = .{ .color = .Red, .value = value, .lnode = lnode, .rnode = rnode };
                Node.check_inv(node);
                return node;
            }

            fn destroy(self: ?*Node, allocator: Allocator) void {
                check_inv(self);
                if (self) |node| {
                    Node.destroy(node.lnode, allocator);
                    node.lnode = null;
                    Node.destroy(node.rnode, allocator);
                    node.rnode = null;
                    allocator.destroy(node);
                }
            }

            pub fn contains(self: ?*const Node, value: *const T) bool {
                if (self) |n| {
                    return switch (Con.PartialOrd.on(*const T)(value, &n.value).?) {
                        .lt => Node.contains(n.lnode, value),
                        .eq => true,
                        .gt => Node.contains(n.rnode, value),
                    };
                }
                return false;
            }

            pub fn get(self: ?*const Node, value: *const T) ?*const T {
                if (self) |n| {
                    return switch (Con.PartialOrd.on(*const T)(value, &n.value).?) {
                        .lt => Node.get(n.lnode, value),
                        .eq => &n.value,
                        .gt => Node.get(n.rnode, value),
                    };
                }
                return null;
            }

            pub fn black_height(self: ?*const Node) usize {
                var h: usize = if (isRed(self)) 0 else 1;
                var node: ?*const Node = self;
                while (node) |n| : (node = n.lnode) {
                    if (!isRed(n.lnode))
                        h += 1;
                }
                return h;
            }

            fn rotate_right(self: *Node) *Node {
                const x = self.lnode.?;
                self.lnode = x.rnode;
                x.rnode = self;
                x.color = self.color;
                self.color = .Red;
                return x;
            }

            fn rotate_left(self: *Node) *Node {
                const x = self.rnode.?;
                self.rnode = x.lnode;
                x.lnode = self;
                x.color = self.color;
                self.color = .Red;
                return x;
            }

            // Correct color of a node
            //
            // # Details
            // Flip the color of both nodes to black/red when both child nodes of a given node are red/black.
            // For colors of both child nodes are red:
            //   split 4node to 2 2nodes.
            // For colors of both child nodes are black:
            //   combine 2 2nodes into a 4node.
            fn flip_color(self: *Node) void {
                self.color.flip();
                self.lnode.?.color.flip();
                self.rnode.?.color.flip();
            }

            // Correct the tree to hold the LLRB invariant.
            //
            // # Details
            // 1. Rotate left a right leaning node
            // 1. Rotate right a 2 reds in a row to a 4node
            // 1. Split a 4node to 2 2nodes
            fn fixup(self: *Node) *Node {
                var h = self;
                if (isRed(h.rnode) and !isRed(h.lnode)) {
                    // right leaning h => rotate left
                    h = h.rotate_left();
                } else if (isRed(h.lnode) and isRed(h.lnode.?.lnode)) {
                    // 2reds in a row => rotate right
                    h = h.rotate_right();
                }
                // if h then split
                // NOTICE: split h on the way up the tree, then structure of `Node` should be 2-3 (without 4) tree.
                if (isRed(h.lnode) and isRed(h.rnode))
                    h.flip_color();
                // h.check_inv() catch unreachable;
                return h;
            }

            fn insert_node(self: *?*Node, allocator: Allocator, t: T) Allocator.Error!?T {
                if (self.* == null) {
                    self.* = try Node.new(allocator, t, null, null);
                    return null;
                }

                var node = self.*.?;
                check_inv(node);

                var old: ?T = null;
                switch (Con.PartialOrd.on(*const T)(&t, &node.value).?) {
                    .lt => old = try insert_node(&node.lnode, allocator, t),
                    .eq => {
                        old = node.value;
                        node.value = t;
                    },
                    .gt => old = try insert_node(&node.rnode, allocator, t),
                }

                self.* = node.fixup();
                return old;
            }

            // Checks if node `self` is not `null` and the value of the color field is equal to `.Red`.
            fn isRed(self: ?*const Node) bool {
                return if (self) |node| node.color == .Red else false;
            }

            // move a red link to the left
            fn move_redleft(self: *Node) *Node {
                var h = self;
                h.flip_color();
                // flip_color ensures both links are not null
                if (isRed(h.rnode.?.lnode)) {
                    h.rnode = h.rnode.?.rotate_right();
                    h = h.rotate_left();
                    h.flip_color();
                }
                return h;
            }

            // move a red link to the right
            fn move_redright(self: *Node) *Node {
                var h = self;
                // Combine as it maybe 2 x 2nodes.
                // 'Maybe' because this function called after the invariant is broken.
                h.flip_color();
                // flip_color ensures both links are not null
                if (isRed(h.lnode.?.lnode)) {
                    h = h.rotate_right();
                    h.flip_color();
                }
                return h;
            }

            fn min(self: *Node) *Node {
                var h: *Node = self;
                while (h.lnode) |lnode| : (h = lnode) {}
                return h;
            }

            fn delete(self: *?*Node, allocator: Allocator, value: *const T) ?T {
                if (self.* == null)
                    return null;

                var h = self.*.?;
                // removed value if it found
                var old: ?T = null;
                if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.lt)) {
                    // not found the value `value.*`
                    if (h.lnode == null) {
                        return null;
                    }
                    if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                        h = h.move_redleft();
                    old = Node.delete(&h.lnode, allocator, value);
                } else {
                    if (isRed(h.lnode)) {
                        // right-leaning 3node
                        h = h.rotate_right();
                        assert(h.rnode != null);
                    }

                    // If `h` is right rotated, then right node is non-null.
                    // Therefore `h` is not right rotated.

                    // Found a node to be deleted on the leaf
                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq) and h.rnode == null) {
                        assert(h.lnode == null);
                        old = h.value;
                        allocator.destroy(h);
                        self.* = null;
                        return old;
                    }

                    // Not found a node have the value equals to `value.*`
                    //
                    // - Not (`value` equals to `h.value` and right node is null)
                    //   ==> by DeMorgan law
                    //   `value` not equals to `h.value` or right node is non-null
                    if (h.rnode == null) {
                        // Right node is null.
                        // These conditions are able to be represented as formally:
                        // `(value != h.value \/ rnode != null) /\ rnode = null`
                        // Then the condition `value != h.value` is satisfied.
                        assert(Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.neq));
                        return null;
                    }

                    if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                        h = h.move_redright();

                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq)) {
                        // const rm = h.rnode.?.min();
                        // h.value = rm.value;
                        old = h.value;
                        h.value = delete_min_node(&h.rnode, allocator).?;
                    } else {
                        old = Node.delete(&h.rnode, allocator, value);
                    }
                }
                self.* = h.fixup();
                return old;
            }

            // Delete the node have min value the left most node
            //
            // # Details
            // Delete the min value from the tree `self` and returns the removed value.
            // If the tree is empty, `null` is returned.
            fn delete_min_node(self: *?*Node, allocator: Allocator) ?T {
                if (self.* == null)
                    return null;

                var h: *Node = self.*.?;
                var old: ?T = null;
                if (h.lnode == null) {
                    // std.debug.print("delete_min_node: lnode=null: {}\n", .{h.value});
                    old = h.value;
                    assert(h.rnode == null);
                    allocator.destroy(h);
                    self.* = null;
                    return old;
                }

                // left-leaning 3node or 2node
                assert(!isRed(h.rnode));

                // isRed(h.lnode):
                //   `h` is a left-leaning 3node.
                //   4node must not be occurred because this is llrb-2-3 Tree.
                //
                // isRed(h.lnode.?.lnode):
                //   The left node is a (root of) left-leaning 3node.
                if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode)) {
                    h = h.move_redleft();
                }

                old = delete_min_node(&h.lnode, allocator);
                self.* = h.fixup();
                return old;
            }

            // Delete the node have max value the right most node
            //
            // # Details
            // Delete the max value from the tree `self` and returns the removed value.
            // If the tree is empty, `null` is returned.
            //
            // Move red link down/right to tree.
            // Because removing a black link breaks balance.
            fn delete_max_node(self: *?*Node, allocator: Allocator) ?T {
                if (self.* == null)
                    return null;

                var h = self.*.?;
                if (isRed(h.lnode))
                    // to right leaning
                    h = h.rotate_right();

                // 2 red nodes are not contiguous
                assert(!isRed(h.lnode));

                var old: ?T = null;
                if (h.rnode == null) {
                    // std.debug.print("delete_max_node: {}\n", .{h.value});
                    old = h.value;
                    assert(h.lnode == null);
                    allocator.destroy(h);
                    self.* = null;
                    return old;
                }

                // isRed(h.rnode):
                //   `h` is a right-leaning 3node.
                //
                // isRed(h.rnode.?.lnode):
                //   The right node is a (root of) left-leaning 3node.
                if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                    h = h.move_redright();

                old = delete_max_node(&h.rnode, allocator);
                self.* = h.fixup();
                return old;
            }
        };

        pub fn new(allocator: Allocator) Self {
            return .{ .allocator = allocator, .root = null };
        }

        pub fn destroy(self: *Self) void {
            Node.check_inv(self.root);

            Node.destroy(self.root, self.allocator);
            self.root = null;
        }

        /// Returns an iterator which enumerates all values of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all values of the tree.
        /// The values are enumerated by asceding order.
        /// Also, the tree must no be modified while the iterator is alive.
        pub fn iter(self: *const Self) Allocator.Error!iters.Iter(Item) {
            return iters.Iter(Item).new(self.root, self.allocator);
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
            const old = try Node.insert_node(
                &self.root,
                self.allocator,
                value,
            );
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

            const old = Node.delete(&self.root, self.allocator, value);
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
            var old: ?T = null;
            Node.check_inv(self.root);
            old = Node.delete_min_node(&self.root, self.allocator);
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
            var old: ?T = null;
            Node.check_inv(self.root);
            old = Node.delete_max_node(&self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Checks to see if it contains a node with a value equal to `value`.
        pub fn contains(self: *const Self, value: *const T) bool {
            return Node.contains(self.root, value);
        }

        /// Checks whether a node contains a value equal to `value` and returns a pointer to that value.
        /// If not found, returns `null`.
        pub fn get(self: *const Self, value: *const T) ?*const T {
            return Node.get(self.root, value);
        }
    };
}

test "simple insert" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32);

    var tree = Tree.new(allocator);
    defer tree.destroy();

    var values = [_]u32{ 0, 1, 2, 3, 4 };

    for (values) |v|
        try testing.expectEqual(try tree.insert(v), null);
}

test "insert" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32);
    var rng = rand.DefaultPrng.init(0);
    const random = rng.random();
    const num: usize = 20;

    var tree = Tree.new(allocator);
    defer tree.destroy();

    var i: usize = 0;
    while (i < num) : (i += 1) {
        const v = @as(u32, random.int(u4));
        // std.debug.print("v: {}th... {}\n", .{ i, v });
        if (try tree.insert(v)) |x| {
            // std.debug.print("already exist: {}\n", .{old});
            try testing.expectEqual(v, x);
        }
    }
}

test "contains" {
    const testing = std.testing;
    const rand = std.rand;
    const allocator = testing.allocator;

    const Array = std.ArrayList;
    const Tree = LLRBTreeSet(u32);

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
    const Tree = LLRBTreeSet(u32);

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
        if (try tree.insert(v)) |x| {
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

    const Tree = LLRBTreeSet(u32);
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
}

test "delete_max" {
    const testing = std.testing;
    const rand = std.rand;
    const Array = std.ArrayList;
    const allocator = testing.allocator;

    const Tree = LLRBTreeSet(u32);
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
        var tree = LLRBTreeSet(i32).new(testing.allocator);
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

        var tree = LLRBTreeSet(u32).new(allocator);
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
    {
        var tree = LLRBTreeSet(i32).new(testing.allocator);
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 5) : (i += 1)
            try testing.expectEqual(try tree.insert(i), null);

        var iter = try tree.iter();
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
        var tree = LLRBTreeSet(i32).new(testing.allocator);
        defer tree.destroy();

        var i: i32 = 0;
        while (i <= 4096) : (i += 1)
            try testing.expectEqual(try tree.insert(i), null);

        var iter = try tree.iter();
        defer iter.destroy();
        while (iter.next()) |item| {
            _ = item;
            // std.debug.print("item: {}\n", .{item.*});
        }
    }
}
