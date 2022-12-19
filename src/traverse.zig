//! Traversal order for iteration

const std = @import("std");
const assert = std.debug.assert;

/// Kind of traversal operation for depth first search
pub const Op = enum(u8) {
    /// access to the left side child
    Left = 0,
    /// access to the value
    Value = 1,
    /// access to the right side child
    Right = 2,
    /// pop the item of the stack for traversal tree
    Pop = 3,
};

/// Traversal order for tree iteration
pub const Traverse = struct {
    pub const Self: type = @This();

    order: [4]Op,

    pub fn new(order: [4]Op) Self {
        return Self{ .order = order };
    }

    pub fn get(self: *const Self, idx: usize) Op {
        assert(idx < 4);
        return self.order[idx];
    }

    /// Get the next operation along the `self.order`
    pub fn next(self: *const Self, op: Op) Op {
        for (self.order) |o, i| {
            if (o == op)
                return self.order[(i + 1) % self.order.len];
        }
        unreachable;
    }
};

/// The array of operation for In-order traversal
pub const Inorder: Traverse =
    Traverse.new([4]Op{ .Left, .Value, .Right, .Pop });
