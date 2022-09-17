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

        const LR = enum { Left, Right };

        const Node: type = llrbset.LLRBTreeSet(V).Node;

        root: ?*const Node,
        stack: []*const Node,
        lrstack: []LR,
        // stack top
        st: i32,
        allocator: Allocator,

        pub fn new(root: ?*const Node, allocator: Allocator) Allocator.Error!Self {
            const h = Node.black_height(root);
            var stack = try allocator.alloc(*const Node, h * 2);
            var lrstack = try allocator.alloc(LR, h * 2);
            var st: i32 = -1;
            if (root) |node| {
                st += 1;
                stack[@intCast(usize, st)] = node;
                lrstack[@intCast(usize, st)] = LR.Left;
            }
            return Self{ .root = root, .stack = stack, .lrstack = lrstack, .st = st, .allocator = allocator };
        }

        fn stack_top(self: *const Self) usize {
            return @intCast(usize, self.st);
        }

        pub fn next(self: *Self) ?Item {
            // std.debug.print("next: st: {}\n", .{self.st});
            var push = true;
            while (0 <= self.st) {
                var node: *const Node = self.stack[self.stack_top()];
                switch (self.lrstack[self.stack_top()]) {
                    LR.Left => {
                        // std.debug.print("next: Left\n", .{});
                        if (push) {
                            if (node.lnode) |lnode| {
                                // std.debug.print("next: Left: push:\n", .{});
                                self.st += 1;
                                self.stack[self.stack_top()] = lnode;
                                self.lrstack[self.stack_top()] = LR.Left;
                            } else {
                                // std.debug.print("next: Left: ret: {}\n", .{node.value});
                                self.lrstack[self.stack_top()] = LR.Right;
                                return &node.value;
                            }
                        } else {
                            self.lrstack[self.stack_top()] = LR.Right;
                            return &node.value;
                        }
                    },
                    LR.Right => {
                        // std.debug.print("next: Right: {}\n", .{node.value});
                        if (push) {
                            if (node.rnode) |rnode| {
                                // std.debug.print("next: Right: push:\n", .{});
                                self.st += 1;
                                self.stack[self.stack_top()] = rnode;
                                self.lrstack[self.stack_top()] = LR.Left;
                            } else {
                                // std.debug.print("next: Right: pop:\n", .{});
                                push = false;
                                self.st -= 1;
                            }
                        } else {
                            self.st -= 1;
                        }
                    },
                }
            }
            self.allocator.destroy(self.stack.ptr);
            self.allocator.destroy(self.lrstack.ptr);
            return null;
        }
    };
}
