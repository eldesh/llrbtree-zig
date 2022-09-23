const std = @import("std");
const Con = @import("basis_concept");
const llrbset = @import("./llrbset.zig");

const Allocator = std.mem.Allocator;
const Node = @import("./node.zig").Node;

/// A common iterator enumerates all values of `LLRBTreeSet` and `LLRBTreeMap` by asceding order.
///
/// # Details
/// An iterator enumerates all values of a `LLRBTreeSet` and `LLRBTreeMap` by asceding order.
/// `Item` of the iterator is const pointer to a value or a key/value pair of the tree.
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
pub fn Iter(comptime V: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const V;

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

        root: ?*const Node(V),
        // iteration stack
        stack: []*const Node(V),
        lrstack: []State,
        // index of stack top
        st: i32,
        allocator: Allocator,

        pub fn new(root: ?*const Node(V), allocator: Allocator) Allocator.Error!Self {
            const h = Node(V).black_height(root);
            var stack = try allocator.alloc(*const Node(V), h * 2);
            var lrstack = try allocator.alloc(State, h * 2);
            var self = Self{ .root = root, .stack = stack, .lrstack = lrstack, .st = -1, .allocator = allocator };
            if (root) |node|
                self.push_stack(node);
            return self;
        }

        fn stack_top(self: *const Self) usize {
            return @intCast(usize, self.st);
        }

        fn peek_stack(self: *const Self) *const Node(V) {
            return self.stack[@intCast(usize, self.st)];
        }

        fn push_stack(self: *Self, node: *const Node(V)) void {
            self.st += 1;
            self.stack[self.stack_top()] = node;
            self.lrstack[self.stack_top()] = State.Left;
        }

        pub fn next(self: *Self) ?Item {
            while (0 <= self.st) {
                // std.debug.print("st: {}\n", .{self.st});
                const node = self.peek_stack();
                switch (self.lrstack[self.stack_top()].next()) {
                    State.Left => {
                        if (node.lnode) |lnode| {
                            // std.debug.print("L:{}\n", .{self.st});
                            self.push_stack(lnode);
                        }
                    },
                    State.Value => {
                        // std.debug.print("V:{}\n", .{node.value});
                        return node.get_item();
                    },
                    State.Right => {
                        if (node.rnode) |rnode| {
                            // std.debug.print("R:{}\n", .{self.st});
                            self.push_stack(rnode);
                        }
                    },
                    State.Pop => {
                        // std.debug.print("P:{}\n", .{self.st});
                        self.st -= 1; // pop
                    },
                }
            }
            return null;
        }

        pub fn destroy(self: @This()) void {
            self.allocator.destroy(self.stack.ptr);
            self.allocator.destroy(self.lrstack.ptr);
        }
    };
}
