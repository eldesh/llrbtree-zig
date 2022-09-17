/// Left-leaning Red-Black Tree implementation. A variant of balanced binary tree.
///
/// # Summary
/// This module provides Left-leaning Red-Black Tree (LLRB tree) implementation which is a variant of Red-Black Tree.
/// The LLRB tree restricts the invariant of the tree, then the number of tree operations are reduced compared to the naive Red-Black Tree.
///
/// # Cite
/// Left-leaning Red-Black Trees, Robert Sedgewick https://sedgewick.io/wp-content/themes/sedgewick/papers/2008LLRB.pdf
///
const std = @import("std");
const Con = @import("basis_concept");

const math = std.math;

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = enum {
    Red,
    Black,

    pub fn flip(self: *@This()) void {
        switch (self.*) {
            .Red => self.* = .Black,
            .Black => self.* = .Red,
        }
    }
};

pub fn LLRBTreeSet(comptime T: type) type {
    comptime assert(Con.isPartialOrd(T));

    return struct {
        pub const Self = @This();
        pub const T = T;

        // pub const Entry = struct {
        //     key: *const Key,
        //     val: *Value,
        // };

        allocator: Allocator,
        root: ?*Node,

        pub const NodeError = error{
            TwoRedsInARow,
            NotLeftLeaning,
        };

        pub const Node = struct {
            // color of the incoming link (from parent)
            color: NodeColor,
            value: T,
            // left child node
            lnode: ?*Node,
            // right child node
            rnode: ?*Node,

            fn check_inv(self: ?@This()) !void {
                if (self == null)
                    return;

                try self.?.check_disallowed_2reds();
                try self.?.check_left_leaning();
            }

            fn check_disallowed_2reds(self: @This()) NodeError!void {
                if (isRed(&self)) {
                    if (isRed(self.lnode) or isRed(self.rnode))
                        return NodeError.TwoRedsInARow;
                }

                if (self.rnode) |rnode|
                    try rnode.check_disallowed_2reds();
                if (self.lnode) |lnode|
                    try lnode.check_disallowed_2reds();
            }

            // isRed(self.rnode) ==> isRed(self.lnode)
            fn check_left_leaning(self: @This()) NodeError!void {
                if (!isRed(self.rnode) or self.lnode == null or isRed(self.lnode)) {
                    if (self.rnode) |rnode|
                        try rnode.check_left_leaning();
                    if (self.lnode) |lnode|
                        try lnode.check_left_leaning();
                } else {
                    return NodeError.NotLeftLeaning;
                }
            }

            fn new(alloc: Allocator, value: T, lnode: ?*Node, rnode: ?*Node) !*Node {
                var node = try alloc.create(Node);
                node.* = .{ .color = .Red, .value = value, .lnode = lnode, .rnode = rnode };
                node.check_inv() catch unreachable;
                return node;
            }

            fn destroy(self: ?*Node, allocator: Allocator) void {
                if (self) |node| {
                    node.check_inv() catch unreachable;
                    Node.destroy(node.lnode, allocator);
                    node.lnode = null;
                    Node.destroy(node.rnode, allocator);
                    node.rnode = null;
                    allocator.destroy(node);
                }
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
                node.check_inv() catch unreachable;

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

            fn delete_node(self: *Node, allocator: Allocator, value: *const T) ?*Node {
                var h = self;
                if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.lt)) {
                    // not found the value `value.*`
                    if (h.lnode == null) {
                        // std.debug.print("l: not found the value: {}\n", .{value.*});
                        return h;
                    }
                    if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                        h = h.move_redleft();
                    h.lnode = delete_node(h.lnode.?, allocator, value);
                    // if (h.lnode) |lnode|
                    //     lnode.check_inv() catch unreachable;
                } else {
                    if (isRed(h.lnode))
                        h = h.rotate_right();

                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq) and h.rnode == null) {
                        // std.debug.assert(h.lnode == null);
                        allocator.destroy(h);
                        return null;
                    }

                    // not found
                    if (h.rnode == null) {
                        return h;
                    }

                    if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                        h = h.move_redright();

                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq)) {
                        const rm = h.rnode.?.min();
                        h.value = rm.value;
                        _ = delete_min_node(&h.rnode, allocator);
                        // if (h.rnode) |rnode|
                        //     rnode.check_inv() catch unreachable;
                    } else {
                        h.rnode = delete_node(h.rnode.?, allocator, value);
                        // if (h.rnode) |rnode|
                        //     rnode.check_inv() catch unreachable;
                    }
                }
                return h.fixup();
            }

            // Delete the node have min value the left most node
            //
            // # Details
            //
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
                    // std.debug.print("delete_min_node: move_redleft\n", .{});
                }

                old = delete_min_node(&h.lnode, allocator);
                // std.debug.print("delete_min_node: old: {}\n", .{old});
                self.* = h.fixup();
                // std.debug.print("delete_min_node: fixup\n", .{});
                return old;
            }

            // Delete the node have max value the right most node
            //
            // # Details
            // Move red link down/right to tree.
            // Because removing a black link breaks balance.
            //
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

        // pub fn keys(self: *const Self) iter.KeyConstIter(K, V) {
        // }

        // pub fn mut_keys(self: *Self) iter.KeyIter(K, V) {
        // }

        // pub fn values(self: *const Self) iter.ValueConstIter(K, V) {
        // }

        // pub fn mut_values(self: *Self) iter.ValueIter(K, V) {
        // }

        pub fn destroy(self: *Self) void {
            if (self.root) |node|
                node.check_inv() catch unreachable;

            Node.destroy(self.root, self.allocator);
            self.root = null;
        }

        pub fn insert(self: *Self, value: T) !?T {
            if (self.root) |root|
                try root.check_inv();
            const old = try Node.insert_node(
                &self.root,
                self.allocator,
                value,
            );
            self.root.?.color = .Black;
            try self.root.?.check_inv();
            return old;
        }

        pub fn delete(self: *Self, value: *const T) void {
            if (self.root) |root| {
                root.check_inv() catch unreachable;
                self.root = Node.delete_node(root, self.allocator, value);
                if (self.root) |sroot|
                    sroot.color = .Black;
            }
            if (self.root) |root| {
                root.check_inv() catch unreachable;
            }
        }

        /// Delete the minimum element from tree
        ///
        /// # Details
        /// Delete the minimum element from tree `self`, and returns it.
        /// And `null` is returned for empty tree.
        pub fn delete_min(self: *Self) ?T {
            var old: ?T = null;
            if (self.root) |root|
                root.check_inv() catch unreachable;
            if (self.root) |_|
                old = Node.delete_min_node(&self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
            if (self.root) |root|
                root.check_inv() catch unreachable;
            return old;
        }

        /// Delete the maximum element from tree
        ///
        /// # Details
        /// Delete the maximum element from tree `self`, and returns it.
        /// And `null` is returned for empty tree.
        pub fn delete_max(self: *Self) ?T {
            var old: ?T = null;
            if (self.root) |root|
                root.check_inv() catch unreachable;
            if (self.root) |_|
                old = Node.delete_max_node(&self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
            if (self.root) |root|
                root.check_inv() catch unreachable;
            return old;
        }

        // pub fn get(self: *Self, key: *K) ?Entry {
        // }

        // pub fn mut_get(self: *Self, key: *K) ?Entry {
        // }
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
        _ = try tree.insert(v);
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
        const v = random.int(u4);
        // std.debug.print("v: {}th... {}\n", .{ i, v });
        if (try tree.insert(v)) |_| {
            // std.debug.print("already exist: {}\n", .{old});
        }
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
            _ = try tree.insert(v);
        }

        i = 0;
        var max: u32 = std.math.maxInt(u32);
        while (values.popOrNull()) |_| : (i += 1) {
            const p = @mod(i, num / 10) == 0;
            _ = p;
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

    const Tree = LLRBTreeSet(u32);
    {
        var tree = Tree.new(testing.allocator);
        defer tree.destroy();
        var i: u32 = 0;
        while (i <= 5) : (i += 1)
            _ = try tree.insert(i);
        while (i > 0) : (i -= 1)
            _ = try tree.insert(i);
        while (i <= 5) : (i += 1)
            tree.delete(&i);
        while (i > 0) : (i -= 1)
            tree.delete(&i);
    }
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

        while (values.popOrNull()) |v| {
            tree.delete(&v);
        }
    }
}
