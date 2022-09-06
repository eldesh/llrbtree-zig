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

            fn flip_color(self: *Node) void {
                self.color.flip();
                self.lnode.?.color.flip();
                self.rnode.?.color.flip();
            }

            fn fixup(self: *Node) *Node {
                var h = self;
                if (isRed(h.rnode))
                    h = h.rotate_left();
                if (isRed(h.lnode) and isRed(h.lnode.?.lnode))
                    h = h.rotate_right();
                if (isRed(h.lnode) and isRed(h.rnode))
                    h.flip_color();
                return h;
            }

            fn insert_node(self: ?*Node, allocator: Allocator, t: T) Allocator.Error!*Node {
                if (self) |node| {
                    if (isRed(node.lnode) and isRed(node.rnode)) node.flip_color();

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

            // Checks if node `self` is not null and the value of the color field is equal to `.Red`.
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

            fn delete_node(self: *Node, value: *const T) *Node {
                var h = self;
                if (Con.PartialOrd.on(*const T)(value, &h.value).?.compare(math.CompareOperator.lt)) {
                    if (!isRed(h.lnode) and h.lnode != null and !isRed(h.lnode.?.lnode))
                        h = h.move_redleft();
                    h.lnode = delete_node(h.lnode.?, value);
                } else {
                    unreachable;
                }
                return h.fixup();
            }

            fn delete_min_node(self: ?*Node, allocator: Allocator) ?*Node {
                if (self == null)
                    return null;

                if (self.?.lnode == null) {
                    allocator.destroy(self.?);
                    return null;
                }

                var h = self.?;
                if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                    h = h.move_redleft();

                h.lnode = delete_min_node(h.lnode, allocator);
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
                self.root = root.delete_node(value);
                if (self.root) |_|
                    self.root.?.color = .Black;
            }
        }

        pub fn delete_min(self: *Self) void {
            self.root = Node.delete_min_node(self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
        }

        // pub fn get(self: *Self, key: *K) ?Entry {
        // }

        // pub fn mut_get(self: *Self, key: *K) ?Entry {
        // }
    };
}

test "LLRBTreeSet" {
    const Tree = LLRBTreeSet(u32);
    {
        var tree = Tree.new(testing.allocator);
        defer tree.destroy();
        var i: u32 = 0;
        while (i <= 5) : (i += 1)
            try tree.insert(i);
        while (i > 0) : (i -= 1)
            try tree.insert(i);

        i = 0;
        while (i < 10) : (i += 1)
            tree.delete_min();
    }

    // var val: u32 = 1;
    // tree.delete_min(&val);
}
