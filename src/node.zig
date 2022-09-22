const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");
const node_color = @import("./node_color.zig");
const key_value = @import("./llrbmap/key_value.zig");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;
pub const KeyValue = key_value.KeyValue;

pub const NodeError = error{
    TwoRedsInARow,
    NotLeftLeaning,
    PerfectBlackBalance,
};

pub fn Node(comptime Derive: fn (type) type, comptime T: type, comptime Key: type) type {
    return struct {
        pub const Self = @This();
        pub const Item = T;
        pub usingnamespace Derive(@This());

        // color of the incoming link (from parent)
        color: NodeColor,
        item: T,
        // left child node
        lnode: ?*@This(),
        // right child node
        rnode: ?*@This(),

        pub fn get_item(self: *const @This()) *const T {
            return &self.item;
        }

        pub fn check_inv(self: ?*@This()) void {
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

            var node: ?*@This() = &self_;
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

        pub fn new(alloc: Allocator, item: T, lnode: ?*@This(), rnode: ?*@This()) Allocator.Error!*@This() {
            var node = try alloc.create(@This());
            node.* = .{ .color = .Red, .item = item, .lnode = lnode, .rnode = rnode };
            check_inv(node);
            return node;
        }

        pub fn destroy(self: ?*@This(), allocator: Allocator) void {
            check_inv(self);
            if (self) |node| {
                destroy(node.lnode, allocator);
                node.lnode = null;
                destroy(node.rnode, allocator);
                node.rnode = null;
                allocator.destroy(node);
            }
        }

        pub fn contains_key(self: ?*const @This(), key: *const Key) bool {
            if (self) |n| {
                return switch (Con.PartialOrd.on(*const Key)(key, Self.get_key(&n.item)).?) {
                    .lt => contains_key(n.lnode, key),
                    .eq => true,
                    .gt => contains_key(n.rnode, key),
                };
            }
            return false;
        }

        pub fn get(self: ?*const @This(), key: *const Key) ?*const T {
            if (self) |n| {
                return switch (Con.PartialOrd.on(*const Key)(key, Self.get_key(&n.item)).?) {
                    .lt => get(n.lnode, key),
                    .eq => &n.item,
                    .gt => get(n.rnode, key),
                };
            }
            return null;
        }

        pub fn black_height(self: ?*const @This()) usize {
            var h: usize = if (isRed(self)) 0 else 1;
            var node: ?*const @This() = self;
            while (node) |n| : (node = n.lnode) {
                if (!isRed(n.lnode))
                    h += 1;
            }
            return h;
        }

        fn rotate_right(self: *@This()) *@This() {
            const x = self.lnode.?;
            self.lnode = x.rnode;
            x.rnode = self;
            x.color = self.color;
            self.color = .Red;
            return x;
        }

        fn rotate_left(self: *@This()) *@This() {
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
        fn flip_color(self: *@This()) void {
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
        fn fixup(self: *@This()) *@This() {
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

        pub fn insert(self: *?*@This(), allocator: Allocator, item: T) Allocator.Error!?T {
            if (self.* == null) {
                self.* = try @This().new(allocator, item, null, null);
                return null;
            }

            var node = self.*.?;
            check_inv(node);

            var old: ?T = null;
            switch (Con.PartialOrd.on(*const Key)(Self.get_key(&item), Self.get_key(&node.item)).?) {
                .lt => old = try insert(&node.lnode, allocator, item),
                .eq => {
                    old = node.item;
                    node.item = item;
                },
                .gt => old = try insert(&node.rnode, allocator, item),
            }

            self.* = node.fixup();
            return old;
        }

        // Checks if node `self` is not `null` and the value of the color field is equal to `.Red`.
        fn isRed(self: ?*const @This()) bool {
            return if (self) |node| node.color == .Red else false;
        }

        // move a red link to the left
        fn move_redleft(self: *@This()) *@This() {
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
        fn move_redright(self: *@This()) *@This() {
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

        fn min(self: *@This()) *@This() {
            var h: *@This() = self;
            while (h.lnode) |lnode| : (h = lnode) {}
            return h;
        }

        pub fn delete(self: *?*@This(), allocator: Allocator, key: *const Key) ?T {
            if (self.* == null)
                return null;

            var h = self.*.?;
            // removed value if it found
            var old: ?T = null;
            if (Con.PartialOrd.on(*const Key)(key, Self.get_key(&h.item)).?.compare(.lt)) {
                // not found the value `value.*`
                if (h.lnode == null) {
                    return null;
                }
                if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                    h = h.move_redleft();
                old = delete(&h.lnode, allocator, key);
            } else {
                if (isRed(h.lnode)) {
                    // right-leaning 3node
                    h = h.rotate_right();
                    assert(h.rnode != null);
                }

                // If `h` is right rotated, then right node is non-null.
                // Therefore `h` is not right rotated.

                // Found a node to be deleted on the leaf
                if (Con.PartialOrd.on(*const Key)(key, Self.get_key(&h.item)).?.compare(.eq) and h.rnode == null) {
                    assert(h.lnode == null);
                    old = h.item;
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
                    assert(Con.PartialOrd.on(*const Key)(key, Self.get_key(&h.item)).?.compare(.neq));
                    return null;
                }

                if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                    h = h.move_redright();

                if (Con.PartialOrd.on(*const Key)(key, Self.get_key(&h.item)).?.compare(.eq)) {
                    // const rm = h.rnode.?.min();
                    // h.key = rm.key;
                    old = h.item;
                    h.item = delete_min(&h.rnode, allocator).?;
                } else {
                    old = delete(&h.rnode, allocator, key);
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
        pub fn delete_min(self: *?*@This(), allocator: Allocator) ?T {
            if (self.* == null)
                return null;

            var h: *@This() = self.*.?;
            var old: ?T = null;
            if (h.lnode == null) {
                // std.debug.print("delete_min: lnode=null: {}\n", .{h.value});
                old = h.item;
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

            old = @This().delete_min(&h.lnode, allocator);
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
        pub fn delete_max(self: *?*@This(), allocator: Allocator) ?T {
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
                // std.debug.print("delete_max: {}\n", .{h.value});
                old = h.item;
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

            old = @This().delete_max(&h.rnode, allocator);
            self.* = h.fixup();
            return old;
        }
    };
}
