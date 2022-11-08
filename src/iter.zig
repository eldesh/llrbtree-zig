const std = @import("std");
const Con = @import("basis_concept");
const iter = @import("iter-zig");
const static_stack = @import("./static_stack.zig");

const Allocator = std.mem.Allocator;
const Tuple = std.meta.Tuple;
const StaticStack = static_stack.StaticStack;

// Inner states of Iter of LLRBTree for depth first iteration
const State = enum(u8) {
    Left = 0,
    Value = 1,
    Right = 2,
    Pop = 3,
    // Updates the current state to the next and returns old state.
    //
    // Updates are cycled in order:
    // Left -> Value -> Right -> Pop -> Left ...
    fn next(self: *@This()) @This() {
        const old = self.*;
        self.* = @intToEnum(@This(), (@enumToInt(self.*) + 1) % 4);
        return old;
    }
};

/// An iterator enumerates all values of a `LLRBTreeSet` by asceding order.
///
/// # Details
/// An iterator enumerates all values of a `LLRBTreeSet` by asceding order.
/// `Item` of the iterator is const pointer to value of the tree.
///
/// # Notice
/// This iterator allocates a stack area on the heap to hold intermediate state when iterating through the tree.
/// It should be released with `destroy`.
///
/// # Example
/// ```zig
/// var iter = tree.iter();
/// defer iter.destroy();
/// while (iter.next()) |item| {
///   _ = item;
/// }
/// ```
pub fn MakeIter(comptime Derive: fn (type) type, comptime Node: type, comptime V: type) type {
    // Avoid compilation error:
    // ```
    // ./src/iter.zig:29:12: error: struct
    //   '.rbtree-zig.iter.MakeIter(DeriveIterator, Node...)
    // depends on itself
    // ```
    const Stack: type = StaticStack(Tuple(&.{ *const Node, State }), Node.MaxPathLength);
    return struct {
        pub const Self: type = @This();
        pub const Item: type = V;
        pub usingnamespace Derive(@This());

        root: ?*const Node,
        stack: Stack,
        proj: fn (*const Node) V,

        pub fn new(root: ?*const Node, proj: fn (*const Node) Item) Self {
            var stack = Stack.new();
            if (root) |n|
                stack.force_push(.{ n, State.Left });
            return .{ .root = root, .stack = stack, .proj = proj };
        }

        pub fn next(self: *Self) ?Item {
            while (!self.stack.is_empty()) {
                const n = self.stack.force_peek_ref();
                switch (n.*[1].next()) {
                    State.Left => {
                        if (n.*[0].lnode) |lnode| {
                            // std.debug.print("L:{}\n", .{self.st});
                            self.stack.force_push(.{ lnode, State.Left });
                        }
                    },
                    State.Value => {
                        // std.debug.print("V:{}\n", .{n.value});
                        return self.proj(n.*[0]);
                    },
                    State.Right => {
                        if (n.*[0].rnode) |rnode| {
                            // std.debug.print("R:{}\n", .{self.st});
                            self.stack.force_push(.{ rnode, State.Left });
                        }
                    },
                    State.Pop => {
                        // std.debug.print("P:{}\n", .{self.st});
                        self.stack.force_pop();
                    },
                }
            }
            return null;
        }

        pub fn destroy(self: *Self) void {
            _ = self;
        }
    };
}

pub fn Iter(comptime Node: type, comptime V: type) type {
    return MakeIter(iter.DeriveIterator, Node, V);
}
