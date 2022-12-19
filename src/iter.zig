const std = @import("std");
const Con = @import("basis_concept");
const iter = @import("iter-zig");
const static_stack = @import("./static_stack.zig");
const compat = @import("./compat.zig");
const traverse = @import("./traverse.zig");

const Tuple = std.meta.Tuple;
const StaticStack = static_stack.StaticStack;
const Op = traverse.Op;

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
    const Stack: type = StaticStack(Tuple(&.{ *const Node, Op }), Node.MaxPathLength);

    // type of projection function value from a node
    const Proj = compat.Func(*const Node, V);
    return struct {
        pub const Self: type = @This();
        pub const Item: type = V;
        pub usingnamespace Derive(@This());

        root: ?*const Node,
        stack: Stack,
        proj: Proj,
        trav: traverse.Traverse,

        pub fn new(root: ?*const Node, proj: Proj, trav: traverse.Traverse) Self {
            var stack = Stack.new();
            if (root) |n|
                stack.force_push(.{ n, trav.get(0) });
            return .{ .root = root, .stack = stack, .proj = proj, .trav = trav };
        }

        pub fn next(self: *Self) ?Item {
            while (self.stack.peek_ref() catch null) |n| {
                const now = n.*[1];
                n.*[1] = self.trav.next(n.*[1]);
                switch (now) {
                    Op.Left => {
                        if (n.*[0].lnode) |lnode| {
                            // std.debug.print("L:{}\n", .{self.st});
                            self.stack.force_push(.{ lnode, self.trav.get(0) });
                        }
                    },
                    Op.Value => {
                        // std.debug.print("V:{}\n", .{n.value});
                        return self.proj(n.*[0]);
                    },
                    Op.Right => {
                        if (n.*[0].rnode) |rnode| {
                            // std.debug.print("R:{}\n", .{self.st});
                            self.stack.force_push(.{ rnode, self.trav.get(0) });
                        }
                    },
                    Op.Pop => {
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
    comptime return MakeIter(iter.prelude.DeriveIterator, Node, V);
}
