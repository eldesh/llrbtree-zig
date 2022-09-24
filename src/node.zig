const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");
const node_color = @import("./node_color.zig");
const key_value = @import("./llrbmap/key_value.zig");

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;
pub const KeyValue = key_value.KeyValue;

/// Errors for invariant violation errors.
/// These errors will be occurred only for the Debug mode.
pub const InvariantError = error{
    // 2 consecutive Red nodes occurred
    TwoRedsInARow,
    // A right-leaning 3-node is occurred
    NotLeftLeaning,
    // The number of black links of a left node is not equals to the right one
    PerfectBlackBalance,
};

/// Node of LLRB Tree implementation
/// 
/// - `Derive`
///   Derive struct that implements `get_key` which project reference to value for comparing.
///   The projected function should have the type `fn (*const T) *const Key`.
/// - `T`
///   Type of value held on Node.
/// - `Key`
///   Type of value projected for ordering from `T`.
pub fn Node(comptime Derive: fn (type) type, comptime T: type, comptime Key: type) type {
    return struct {
        pub const Self = @This();
        pub const Item = T;
        /// The depth of stack for iterating trees
        ///
        /// # Details
        /// This should be greater than or equals to the maximum length of the path from the root.
        /// The path length includes the number of red-links.
        ///
        /// For 64-bit systems (i.e., pointer size is 64 bits), 
        /// the maximum number of elements in a container is 2^64.
        /// When a perfect balanced tree has 2^64 elements, the path length is 64.
        /// If red-links are included, the maximum path length is twice as long.
        pub const MaxPathLength: comptime_int = 64 * 2;
        pub usingnamespace Derive(@This());

        /// color of the incoming link (from parent)
        color: NodeColor,
        item: T,
        /// left child node
        lnode: ?*Self,
        /// right child node
        rnode: ?*Self,

        pub fn get_item(self: *const Self) *const T {
            return &self.item;
        }

        pub fn get_item_mut(self: *Self) *T {
            return &self.item;
        }

        pub fn check_inv(self: ?*Self) void {
            // enabled only when Debug mode
            if (comptime builtin.mode != std.builtin.Mode.Debug)
                return;

            if (self == null)
                return;

            self.?.check_disallowed_2reds() catch unreachable;
            self.?.check_left_leaning() catch unreachable;
            self.?.check_perfect_black_balance() catch unreachable;
        }

        fn check_disallowed_2reds(self: *const Self) InvariantError!void {
            if (isRed(self)) {
                if (isRed(self.lnode) or isRed(self.rnode))
                    return InvariantError.TwoRedsInARow;
            }

            if (self.rnode) |rnode|
                try rnode.check_disallowed_2reds();
            if (self.lnode) |lnode|
                try lnode.check_disallowed_2reds();
        }

        // isRed(self.rnode) ==> isRed(self.lnode)
        fn check_left_leaning(self: *const Self) InvariantError!void {
            if (!isRed(self.rnode) or self.lnode == null or isRed(self.lnode)) {
                if (self.rnode) |rnode|
                    try rnode.check_left_leaning();
                if (self.lnode) |lnode|
                    try lnode.check_left_leaning();
            } else {
                return InvariantError.NotLeftLeaning;
            }
        }

        fn check_perfect_black_balance(self: Self) InvariantError!void {
            var self_ = self;
            var rblack: u32 = 0;
            var lblack: u32 = 0;

            var node: ?*Self = &self_;
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
                return InvariantError.PerfectBlackBalance;
            }
            if (self.rnode) |rnode|
                try rnode.check_perfect_black_balance();
            if (self.lnode) |lnode|
                try lnode.check_perfect_black_balance();
        }

        pub fn new(alloc: Allocator, item: T, lnode: ?*Self, rnode: ?*Self) Allocator.Error!*Self {
            var node = try alloc.create(Self);
            node.* = .{ .color = .Red, .item = item, .lnode = lnode, .rnode = rnode };
            check_inv(node);
            return node;
        }

        pub fn destroy(self: ?*Self, allocator: Allocator) void {
            check_inv(self);
            if (self) |node| {
                destroy(node.lnode, allocator);
                node.lnode = null;
                destroy(node.rnode, allocator);
                node.rnode = null;
                allocator.destroy(node);
            }
        }

        pub fn contains_key(self: ?*const Self, key: *const Key) bool {
            var node = self;
            while (node) |n| {
                switch (Con.PartialOrd.on(*const Key)(key, Self.get_key(&n.item)).?) {
                    .lt => node = n.lnode,
                    .eq => return true,
                    .gt => node = n.rnode,
                }
            }
            return false;
        }

        pub fn get(self: ?*const Self, key: *const Key) ?*const T {
            var node = self;
            while (node) |n| {
                switch (Con.PartialOrd.on(*const Key)(key, Self.get_key(&n.item)).?) {
                    .lt => node = n.lnode,
                    .eq => return &n.item,
                    .gt => node = n.rnode,
                }
            }
            return null;
        }

        pub fn black_height(self: ?*const Self) usize {
            var h: usize = if (isRed(self)) 0 else 1;
            var node: ?*const Self = self;
            while (node) |n| : (node = n.lnode) {
                if (!isRed(n.lnode))
                    h += 1;
            }
            return h;
        }

        fn rotate_right(self: *Self) *Self {
            const x = self.lnode.?;
            self.lnode = x.rnode;
            x.rnode = self;
            x.color = self.color;
            self.color = .Red;
            return x;
        }

        fn rotate_left(self: *Self) *Self {
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
        fn flip_color(self: *Self) void {
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
        pub fn fixup(self: *Self) *Self {
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

        pub fn insert(self: *?*Self, allocator: Allocator, item: T) Allocator.Error!?T {
            if (self.* == null) {
                self.* = try Self.new(allocator, item, null, null);
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
        fn isRed(self: ?*const Self) bool {
            return if (self) |node| node.color == .Red else false;
        }

        // move a red link to the left
        fn move_redleft(self: *Self) *Self {
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
        fn move_redright(self: *Self) *Self {
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

        fn min(self: *Self) *Self {
            var h = self;
            while (h.lnode) |lnode| : (h = lnode) {}
            return h;
        }

        pub fn delete(self: *?*Self, allocator: Allocator, key: *const Key) ?T {
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
        pub fn delete_min(self: *?*Self, allocator: Allocator) ?T {
            if (self.* == null)
                return null;

            var h: *Self = self.*.?;
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

            old = delete_min(&h.lnode, allocator);
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
        pub fn delete_max(self: *?*Self, allocator: Allocator) ?T {
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

            old = delete_max(&h.rnode, allocator);
            self.* = h.fixup();
            return old;
        }
    };
}
