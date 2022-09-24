const std = @import("std");

const node = @import("./node.zig");
const static_stack = @import("../static_stack.zig");
const key_value = @import("./key_value.zig");

const Allocator = std.mem.Allocator;
const StaticStack = static_stack.StaticStack;
const Node = node.Node;

const assert = std.debug.assert;

pub fn Entry(comptime K: type, comptime V: type) type {
    return union(enum) {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        const Stack = StaticStack(*?*Node(Key, Value), Node(Key, Value).MaxPathLength);

        Vacant: VacantEntry(K, V),
        Occupied: OccupiedEntry(K, V),

        pub fn new_vacant(stack: Stack, allocator: Allocator, key: Key) Self {
            return .{ .Vacant = VacantEntry(Key, Value).new(stack, allocator, key) };
        }

        pub fn new_occupied(key: *const Key, value: *Value) Self {
            return .{ .Occupied = OccupiedEntry(Key, Value).new(key, value) };
        }

        pub fn get_key(self: *const Self) *const Key {
            return switch (self.*) {
                .Vacant => |vacant| vacant.get_key(),
                .Occupied => |occupied| occupied.get_key(),
            };
        }

        pub fn insert(self: *Self, value: Value) Allocator.Error!*Value {
            switch (self.*) {
                .Vacant => |*vacant| {
                    var old: *V = try vacant.insert(value) catch |err| switch (err) {
                        VacantEntry(K, V).Error.AlreadyInserted => unreachable,
                        else => |aerr| aerr,
                    };
                    self.* = Self.new_occupied(vacant.get_key(), old);
                    return old;
                },
                .Occupied => |*occupied| return occupied.get_value_mut(),
            }
        }

        pub fn modify(self: *Self, f: fn (*Value) void) *Self {
            switch (self.*) {
                .Occupied => |*occupied| f(occupied.get_value_mut()),
                else => {},
            }
            return self;
        }
    };
}

pub fn VacantEntry(comptime K: type, comptime V: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;
        pub const Error = error{AlreadyInserted} || Allocator.Error;

        const Stack = StaticStack(*?*Node(Key, Value), Node(Key, Value).MaxPathLength);

        /// # Invariant
        /// `stack.force_peek().* == null`
        stack: Stack,
        allocator: Allocator,
        key: Key,
        inserted: bool,

        pub fn new(stack: Stack, allocator: Allocator, key: Key) Self {
            {
                var muts = stack;
                assert(muts.force_peek().* == null);
            }
            return .{ .stack = stack, .allocator = allocator, .key = key, .inserted = false };
        }

        pub fn get_key(self: *const Self) *const Key {
            return &self.key;
        }

        pub fn insert(self: *Self, value: V) Error!*Value {
            if (self.inserted)
                return Error.AlreadyInserted;
            defer self.inserted = true;

            // insert a value to the Leaf
            const kv = key_value.make(self.key, value);
            var top = self.stack.force_peek();
            self.stack.force_pop();
            top.* = try node.Node(K, V).new(self.allocator, kv, null, null);

            const ptr = top.*.?.get_item_mut().value_mut();
            // fixup node up to the root
            while (!self.stack.is_empty()) : (self.stack.force_pop()) {
                const np = self.stack.force_peek();
                np.* = np.*.?.fixup();
            }
            return ptr;
        }
    };
}

pub fn OccupiedEntry(comptime K: type, comptime V: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        key: *const Key,
        value: *Value,

        pub fn new(key: *const Key, value: *Value) Self {
            return .{ .key = key, .value = value };
        }

        pub fn get_key(self: *const Self) *const Key {
            return self.key;
        }

        pub fn get_value(self: *const Self) *const Value {
            return self.value;
        }

        pub fn get_value_mut(self: *Self) *Value {
            return self.value;
        }

        pub fn insert(self: *Self, value: Value) Value {
            const old = self.value.*;
            self.value.* = value;
            return old;
        }
    };
}
