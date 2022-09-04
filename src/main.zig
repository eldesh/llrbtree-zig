/// Red-Black tree implementation. A variant of balanced binary tree.
///
/// # Summary
/// This function returns Left-leaning Red-Black Tree (LLRB tree) implementation which is a variant of Red-Black Tree.
/// The LLRB tree restricts the invariant of the tree, then the number of tree operations are reduced compared to the naive Red-Black Tree.
///
/// # Cite
/// Left-leaning Red-Black Trees, Robert Sedgewick https://sedgewick.io/wp-content/themes/sedgewick/papers/2008LLRB.pdf
///
const std = @import("std");
const Con = @import("basis_concept");

const testing = std.testing;

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
            color: NodeColor,
            value: T,
            lnode: ?*Node,
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

            fn flip_color(self: *Node) void {
                self.color.flip();
                self.lnode.?.color.flip();
                self.rnode.?.color.flip();
            }

            fn insert_node(self: ?*Node, allocator: Allocator, t: T) Allocator.Error!*Node {
                if (self) |node| {
                    if (Node.isRed(node.lnode) and isRed(node.rnode)) node.flip_color();

                    switch (Con.PartialOrd.on(*const T)(&node.value, &t).?) {
                        .lt => node.lnode = try insert_node(node.lnode, allocator, t),
                        .eq => node.value = t,
                        .gt => node.rnode = try insert_node(node.rnode, allocator, t),
                    }

                    var vnode = node;
                    if (isRed(node.rnode) and !isRed(node.lnode))
                        vnode = vnode.rotate_left();
                    if (isRed(node.lnode) and node.lnode != null and isRed(node.lnode.?.lnode))
                        vnode = vnode.rotate_right();
                    return vnode;
                } else {
                    return Node.new(allocator, t, null, null);
                }
            }

            fn isRed(self: ?*Node) bool {
                return if (self) |node| node.color == .Red else false;
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

        // pub fn remove(self: *Self, key: *K) ?Value {
        // }

        // pub fn get(self: *Self, key: *K) ?Entry {
        // }

        // pub fn mut_get(self: *Self, key: *K) ?Entry {
        // }
    };
}

test "LLRBTreeSet" {
    const Tree = LLRBTreeSet(u32);
    var tree = Tree.new(testing.allocator);
    defer tree.destroy();
    try tree.insert(1);
    try tree.insert(2);
    try tree.insert(3);
    try tree.insert(4);
    try tree.insert(5);
    try tree.insert(5);
    try tree.insert(4);
    try tree.insert(3);
    try tree.insert(2);
    try tree.insert(1);
}
