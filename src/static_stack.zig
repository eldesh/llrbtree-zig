const std = @import("std");

pub fn StaticStack(comptime T: type, comptime N: comptime_int) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub const Size: comptime_int = N;

        pub const Error = error{ StackFull, StackEmpty };

        stack: [N]T,
        top: u32,

        pub fn new() Self {
            return .{ .stack = undefined, .top = 0 };
        }

        pub fn is_empty(self: *const Self) bool {
            return self.top == 0;
        }

        pub fn is_full(self: *const Self) bool {
            return self.top == @as(u32, N);
        }

        pub fn push(self: *Self, value: T) Error!void {
            if (self.is_full())
                return Error.StackFull;
            self.stack[self.top] = value;
            self.top += 1;
        }

        pub fn peek(self: *Self) Error!T {
            if (self.is_empty())
                return Error.StackEmpty;
            return self.stack[self.top - 1];
        }

        pub fn pop(self: *Self) Error!void {
            if (self.is_empty())
                return Error.StackEmpty;
            self.top -= 1;
        }

        pub fn force_push(self: *Self, value: T) void {
            self.push(value) catch unreachable;
        }

        pub fn force_peek(self: *Self) T {
            return self.peek() catch unreachable;
        }

        pub fn force_pop(self: *Self) void {
            self.pop() catch unreachable;
        }
    };
}
