const std = @import("std");
const Con = @import("basis_concept");
const llrbset = @import("./llrbset.zig");

const math = std.math;

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

pub fn ValueConstIter(comptime V: type) type {
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

        const Node: type = llrbset.LLRBTreeSet(V).Node;

        root: ?*const Node,
        // iteration stack
        stack: []*const Node,
        lrstack: []State,
        // index of stack top
        st: i32,
        allocator: Allocator,

        pub fn new(root: ?*const Node, allocator: Allocator) Allocator.Error!Self {
            const h = Node.black_height(root);
            var stack = try allocator.alloc(*const Node, h * 2);
            var lrstack = try allocator.alloc(State, h * 2);
            var self = Self{ .root = root, .stack = stack, .lrstack = lrstack, .st = -1, .allocator = allocator };
            if (root) |node|
                self.push_stack(node);
            return self;
        }

        fn stack_top(self: *const Self) usize {
            return @intCast(usize, self.st);
        }

        fn peek_stack(self: *const Self) *const Node {
            return self.stack[@intCast(usize, self.st)];
        }

        fn push_stack(self: *Self, node: *const Node) void {
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
                        return &node.value;
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
