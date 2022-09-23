const std = @import("std");

const node = @import("./node.zig");
const static_stack = @import("../static_stack.zig");
const key_value = @import("./key_value.zig");

const Allocator = std.mem.Allocator;
const StaticStack = static_stack.StaticStack;
const Node = node.Node;

const assert = std.debug.assert;

pub fn Entry(comptime K: type, comptime V: type) type {
    const N = Node(K, V).MaxPathLength;
    return union(enum) {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        Vacant: VacantEntry(K, V),
        Occupied: OccupiedEntry(K, V),

        pub fn new_vacant(stack: StaticStack(*?*Node(K, V), N), allocator: Allocator, key: K) Self {
            return .{ .Vacant = VacantEntry(K, V).new(stack, allocator, key) };
        }

        pub fn new_occupied(value: *Value) Self {
            return .{ .Occupied = OccupiedEntry(K, V).new(value) };
        }

        pub fn insert(self: *Self, value: Value) Allocator.Error!?Value {
            switch (self.*) {
                .Vacant => |*vacant| {
                    try vacant.insert(value);
                    return null;
                },
                .Occupied => |*occupied| return occupied.insert(value),
            }
        }
    };
}

pub fn VacantEntry(comptime K: type, comptime V: type) type {
    const N = Node(K, V).MaxPathLength;
    return struct {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        stack: StaticStack(*?*Node(Key, Value), N),
        allocator: Allocator,
        key: Key,

        pub fn new(stack: StaticStack(*?*Node(K, V), N), allocator: Allocator, key: K) Self {
            // assert(null == (stack.peek() catch unreachable).*);
            return .{ .stack = stack, .allocator = allocator, .key = key };
        }

        pub fn insert(self: *Self, value: V) Allocator.Error!void {
            const newpair = key_value.make(self.key, value);
            self.stack.force_peek().* = try node.Node(K, V).new(self.allocator, newpair, null, null);
            self.stack.force_pop();

            while (!self.stack.is_empty()) : (self.stack.force_pop()) {
                const np = self.stack.force_peek();
                np.* = np.*.?.fixup();
            }
        }
    };
}

pub fn OccupiedEntry(comptime K: type, comptime V: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        value: *Value,

        pub fn new(value: *Value) Self {
            return .{ .value = value };
        }

        pub fn insert(self: *Self, value: V) V {
            const old = self.value.*;
            self.value.* = value;
            return old;
        }
    };
}
