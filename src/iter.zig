const std = @import("std");
const Con = @import("basis_concept");
const static_stack = @import("./static_stack.zig");

const Allocator = std.mem.Allocator;
const Tuple = std.meta.Tuple;

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
pub fn Iter(comptime Node: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const Node.Item;

        // States of depth first iteration
        const State = enum(u8) {
            Left = 0,
            Value = 1,
            Right = 2,
            Pop = 3,
            // Get next state and returns old state.
            fn next(self: *@This()) @This() {
                const old = self.*;
                self.* = @intToEnum(@This(), (@enumToInt(self.*) + 1) % 4);
                return old;
            }
        };

        const Stack = static_stack.StaticStack(Tuple(&.{ *const Node, State }), Node.MaxPathLength);

        root: ?*const Node,
        stack: Stack,

        pub fn new(root: ?*const Node) Self {
            var stack = Stack.new();
            if (root) |n|
                stack.force_push(.{ n, State.Left });
            return .{ .root = root, .stack = stack };
        }

        pub fn next(self: *Self) ?Item {
            while (!self.stack.is_empty()) {
                // std.debug.print("st: {}\n", .{self.st});
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
                        return n.*[0].get_item();
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
