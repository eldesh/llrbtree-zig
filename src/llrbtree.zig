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

        pub const Node = struct {
            // color of the incoming link (from parent)
            color: NodeColor,
            value: T,
            // left child node
            lnode: ?*Node,
            // right child node
            rnode: ?*Node,

            fn new(alloc: Allocator, value: T, lnode: ?*Node, rnode: ?*Node) !*Node {
                var node = try alloc.create(Node);
                node.* = .{ .color = .Red, .value = value, .lnode = lnode, .rnode = rnode };
                return node;
            }

            fn destroy(self: ?*Node, allocator: Allocator) void {
                if (self) |node| {
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
                // right leaning h => rotate left
                if (isRed(h.rnode)) // and !isRed(h.lnode))
                    h = h.rotate_left();
                // 2reds in a row => rotate right
                if (isRed(h.lnode) and isRed(h.lnode.?.lnode))
                    h = h.rotate_right();
                // if h then split
                // NOTICE: split h on the way up the tree, then structure of `Node` should be 2-3 (without 4) tree.
                if (isRed(h.lnode) and isRed(h.rnode))
                    h.flip_color();
                return h;
            }

            fn insert_node(self: ?*Node, allocator: Allocator, t: T) Allocator.Error!*Node {
                if (self == null)
                    return Node.new(allocator, t, null, null);

                var node = self.?;

                switch (Con.PartialOrd.on(*const T)(&t, &node.value).?) {
                    .lt => node.lnode = try insert_node(node.lnode, allocator, t),
                    .eq => node.value = t,
                    .gt => node.rnode = try insert_node(node.rnode, allocator, t),
                }

                return node.fixup();
            }

            // Checks if node `self` is not `null` and the value of the color field is equal to `.Red`.
            fn isRed(self: ?*Node) bool {
                return if (self) |node| node.color == .Red else false;
            }

            //
            fn move_redleft(self: *Node) *Node {
                var h = self;
                h.flip_color();
                if (self.rnode != null and isRed(self.rnode.?.lnode)) {
                    h.rnode = h.rnode.?.rotate_right();
                    h = h.rotate_left();
                    h.flip_color();
                }
                return h;
            }

            fn move_redright(self: *Node) *Node {
                var h = self;
                h.flip_color();
                if (self.lnode != null and isRed(self.lnode.?.lnode)) {
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
                if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(math.CompareOperator.lt)) {
                    if (!isRed(h.lnode) and h.lnode != null and !isRed(h.lnode.?.lnode))
                        h = h.move_redleft();
                    if (h.lnode) |lnode|
                        h.lnode = delete_node(lnode, allocator, value);
                } else {
                    if (isRed(h.lnode))
                        h = h.rotate_right();
                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq) and h.rnode == null) {
                        std.debug.assert(h.lnode == null);
                        allocator.destroy(h);
                        return null;
                    }
                    if (!isRed(h.rnode) and h.rnode != null and !isRed(h.rnode.?.lnode))
                        h = h.move_redright();
                    if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(.eq)) {
                        const rm = if (h.rnode) |rnode| rnode.min() else h;
                        h.value = rm.value;
                        if (h.rnode) |rnode|
                            h.rnode = delete_min_node(rnode, allocator);
                    } else {
                        if (h.rnode) |rnode|
                            h.rnode = delete_node(rnode, allocator, value);
                    }
                }
                return h.fixup();
            }

            fn delete_min_node(self: *Node, allocator: Allocator) ?*Node {
                if (self.lnode == null) {
                    // std.debug.print("delete_min_node: {}\n", .{self.?.value});
                    allocator.destroy(self);
                    return null;
                }

                var h = self;
                if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                    h = h.move_redleft();

                h.lnode = delete_min_node(h.lnode.?, allocator);
                return h.fixup();
            }

            fn delete_max_node(self: *Node, allocator: Allocator) ?*Node {
                var h = self;

                if (isRed(h.lnode))
                    // to right leaning
                    h = h.rotate_right();

                if (h.rnode == null) {
                    // std.debug.print("delete_max_node: {}\n", .{h.value});
                    allocator.destroy(h);
                    return null;
                }

                if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                    h = h.move_redright();

                h.rnode = delete_max_node(h.rnode.?, allocator);
                return h.fixup();
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
            if (self.root) |node| {
                Node.destroy(node, self.allocator);
                self.root = null;
            }
        }

        pub fn insert(self: *Self, value: T) !void {
            self.root = try Node.insert_node(
                self.root,
                self.allocator,
                value,
            );
            self.root.?.color = .Black;
        }

        pub fn delete(self: *Self, value: *const T) void {
            if (self.root) |root| {
                self.root = Node.delete_node(root, self.allocator, value);
                if (self.root) |sroot|
                    sroot.color = .Black;
            }
        }

        pub fn delete_min(self: *Self) void {
            if (self.root) |root|
                self.root = Node.delete_min_node(root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
        }

        pub fn delete_max(self: *Self) void {
            if (self.root) |root|
                self.root = Node.delete_max_node(root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
        }

        // pub fn get(self: *Self, key: *K) ?Entry {
        // }

        // pub fn mut_get(self: *Self, key: *K) ?Entry {
        // }
    };
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
        const num: usize = 40960;

        var tree = Tree.new(allocator);
        defer tree.destroy();

        var values = Array(u32).init(allocator);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, 1000) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            try tree.insert(v);
        }

        while (values.popOrNull()) |_| {
            tree.delete_min();
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
        const num: usize = 40960;

        var tree = Tree.new(allocator);
        defer tree.destroy();

        var values = Array(u32).init(allocator);
        defer values.deinit();

        var i: usize = 0;
        while (i < num) : (i += 1) {
            const v = random.int(u32);
            // if (@mod(i, 1000) == 0)
            //     std.debug.print("v: {}th... {}\n", .{ i, v });
            try values.append(v);
            try tree.insert(v);
        }

        while (values.popOrNull()) |_| {
            tree.delete_max();
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
            try tree.insert(i);
        while (i > 0) : (i -= 1)
            try tree.insert(i);
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
            try tree.insert(v);
        }

        while (values.popOrNull()) |v| {
            tree.delete(&v);
        }
    }
}
