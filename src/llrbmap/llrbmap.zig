const std = @import("std");
const builtin = @import("builtin");
const Con = @import("basis_concept");
const node_color = @import("../node_color.zig");
const key_value = @import("./key_value.zig");
pub const iters = @import("./iter.zig");
const math = std.math;

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const NodeColor = node_color.NodeColor;
pub const KeyValue = key_value.KeyValue;

pub fn LLRBTreeMap(comptime K: type, comptime V: type) type {
    comptime assert(Con.isPartialOrd(K));

    return struct {
        pub const Self = @This();
        pub const Key = K;
        pub const Value = V;

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
            key_value: KeyValue(Key, Value),
            // left child node
            lnode: ?*Node,
            // right child node
            rnode: ?*Node,

            fn get_key(self: *const @This()) *const Key {
                return self.key_value.key();
            }

            fn get_value(self: *const @This()) *const Value {
                return self.key_value.value();
            }

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

            fn new(alloc: Allocator, key: Key, value: Value, lnode: ?*Node, rnode: ?*Node) Allocator.Error!*Node {
                var node = try alloc.create(Node);
                node.* = .{ .color = .Red, .key_value = key_value.make(key, value), .lnode = lnode, .rnode = rnode };
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

            pub fn contains_key(self: ?*const Node, key: *const Key) bool {
                if (self) |n| {
                    return switch (Con.PartialOrd.on(*const Key)(key, n.get_key()).?) {
                        .lt => Node.contains_key(n.lnode, key),
                        .eq => true,
                        .gt => Node.contains_key(n.rnode, key),
                    };
                }
                return false;
            }

            pub fn get(self: ?*const Node, key: *const Key) ?*const Value {
                if (self) |n| {
                    return switch (Con.PartialOrd.on(*const Key)(key, n.get_key()).?) {
                        .lt => Node.get(n.lnode, key),
                        .eq => n.get_value(),
                        .gt => Node.get(n.rnode, key),
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

            fn insert_node(self: *?*Node, allocator: Allocator, key: Key, value: Value) Allocator.Error!?Value {
                if (self.* == null) {
                    self.* = try Node.new(allocator, key, value, null, null);
                    return null;
                }

                var node = self.*.?;
                check_inv(node);

                var old: ?Value = null;
                switch (Con.PartialOrd.on(*const Key)(&key, node.get_key()).?) {
                    .lt => old = try insert_node(&node.lnode, allocator, key, value),
                    .eq => {
                        old = node.key_value.toTuple()[1];
                        node.key_value = key_value.make(key, value);
                    },
                    .gt => old = try insert_node(&node.rnode, allocator, key, value),
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

            fn delete(self: *?*Node, allocator: Allocator, key: *const Key) ?Value {
                if (self.* == null)
                    return null;

                var h = self.*.?;
                // removed value if it found
                var old: ?Value = null;
                if (Con.PartialOrd.on(*const Key)(key, h.get_key()).?.compare(.lt)) {
                    // not found the value `value.*`
                    if (h.lnode == null) {
                        return null;
                    }
                    if (!isRed(h.lnode) and !isRed(h.lnode.?.lnode))
                        h = h.move_redleft();
                    old = Node.delete(&h.lnode, allocator, key);
                } else {
                    if (isRed(h.lnode)) {
                        // right-leaning 3node
                        h = h.rotate_right();
                        assert(h.rnode != null);
                    }

                    // If `h` is right rotated, then right node is non-null.
                    // Therefore `h` is not right rotated.

                    // Found a node to be deleted on the leaf
                    if (Con.PartialOrd.on(*const Key)(key, h.get_key()).?.compare(.eq) and h.rnode == null) {
                        assert(h.lnode == null);
                        old = h.key_value.toTuple()[1];
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
                        assert(Con.PartialOrd.on(*const Key)(key, h.get_key()).?.compare(.neq));
                        return null;
                    }

                    if (!isRed(h.rnode) and !isRed(h.rnode.?.lnode))
                        h = h.move_redright();

                    if (Con.PartialOrd.on(*const Key)(key, h.get_key()).?.compare(.eq)) {
                        // const rm = h.rnode.?.min();
                        // h.key = rm.key;
                        old = h.key_value.toTuple()[1];
                        h.key_value = Node.delete_min(&h.rnode, allocator).?;
                    } else {
                        old = Node.delete(&h.rnode, allocator, key);
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
            fn delete_min(self: *?*Node, allocator: Allocator) ?KeyValue(Key, Value) {
                if (self.* == null)
                    return null;

                var h: *Node = self.*.?;
                var old: ?KeyValue(Key, Value) = null;
                if (h.lnode == null) {
                    // std.debug.print("delete_min: lnode=null: {}\n", .{h.value});
                    old = h.key_value;
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

                old = Node.delete_min(&h.lnode, allocator);
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
            fn delete_max(self: *?*Node, allocator: Allocator) ?KeyValue(Key, Value) {
                if (self.* == null)
                    return null;

                var h = self.*.?;
                if (isRed(h.lnode))
                    // to right leaning
                    h = h.rotate_right();

                // 2 red nodes are not contiguous
                assert(!isRed(h.lnode));

                var old: ?KeyValue(Key, Value) = null;
                if (h.rnode == null) {
                    // std.debug.print("delete_max: {}\n", .{h.value});
                    old = h.key_value;
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

                old = Node.delete_max(&h.rnode, allocator);
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

        /// Returns an iterator which enumerates all key/value pairs of the tree.
        ///
        /// # Details
        /// Returns an iterator which enumerates all key/value paris of the tree.
        /// The keys of the paris are enumerated by asceding order.
        /// Also, the tree must no be modified while the iterator is alive.
        pub fn iter(self: *const Self) Allocator.Error!iters.Iter(Key, Value) {
            return iters.Iter(Key, Value).new(self.root, self.allocator);
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
            const old = try Node.insert_node(&self.root, self.allocator, key, value);
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
        pub fn delete(self: *Self, key: *const Key) ?Value {
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
            var old: ?KeyValue(Key, Value) = null;
            Node.check_inv(self.root);
            old = Node.delete_min(&self.root, self.allocator);
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
            var old: ?KeyValue(Key, Value) = null;
            Node.check_inv(self.root);
            old = Node.delete_max(&self.root, self.allocator);
            if (self.root) |root|
                root.color = .Black;
            Node.check_inv(self.root);
            return old;
        }

        /// Checks to see if it contains a value for the specified `key`.
        pub fn contains_key(self: *const Self, key: *const Key) bool {
            return Node.contains_key(self.root, key);
        }

        /// Checks whether a node contains a value equal to `value` and returns a pointer to that value.
        /// If not found, returns `null`.
        pub fn get(self: *const Self, key: *const Key) ?*const Value {
            return Node.get(self.root, key);
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

        var iter = try tree.iter();
        defer iter.destroy();

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

        var iter = try tree.iter();
        defer iter.destroy();
        while (iter.next()) |item| {
            _ = item;
            // std.debug.print("item: {}\n", .{item.*});
        }
    }
}
