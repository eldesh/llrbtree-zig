const std = @import("std");

const node = @import("./node.zig");
const static_stack = @import("../static_stack.zig");
const key_value = @import("./key_value.zig");

const Allocator = std.mem.Allocator;
const StaticStack = static_stack.StaticStack;
const Node = node.Node;

const assert = std.debug.assert;

/// Entry resulting from searches by key.
///
/// - `Vacant`
///   An empty entry associated with the key.
///   It is able to insert a new value for the key.
/// - `Occupied`
///   A key/value occupied entry.
///   It is able to update the value.
pub fn Entry(comptime K: type, comptime V: type) type {
    return union(enum) {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        const Stack = StaticStack(*?*Node(Key, Value), Node(Key, Value).MaxPathLength);

        Vacant: VacantEntry(K, V),
        Occupied: OccupiedEntry(K, V),

        /// Construct a `Entry.Vacant`.
        pub fn new_vacant(stack: Stack, allocator: Allocator, key: Key) Self {
            return .{ .Vacant = VacantEntry(Key, Value).new(stack, allocator, key) };
        }

        /// Construct a `Entry.Occupied`.
        pub fn new_occupied(key: *const Key, value: *Value) Self {
            return .{ .Occupied = OccupiedEntry(Key, Value).new(key, value) };
        }

        pub fn get_key(self: *const Self) *const Key {
            return switch (self.*) {
                .Vacant => |*vacant| vacant.get_key(),
                .Occupied => |*occupied| occupied.get_key(),
            };
        }

        /// Insert new value and returns a pointer to the value held in the Node.
        pub fn insert(self: *Self, value: Value) Allocator.Error!*Value {
            switch (self.*) {
                .Vacant => |*vacant| {
                    var old = try vacant.insert_entry(value) catch |err| switch (err) {
                        VacantEntry(K, V).Error.AlreadyInserted => unreachable,
                        else => |aerr| aerr,
                    };
                    self.* = Self.new_occupied(old.key(), old.value_mut());
                    return old.value_mut();
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

        fn insert_entry(self: *Self, value: Value) Error!*key_value.KeyValue(Key, Value) {
            if (self.inserted)
                return Error.AlreadyInserted;
            defer self.inserted = true;

            // pop the pointer to the vacant entry
            var n = pop: {
                const top = self.stack.force_peek();
                self.stack.force_pop();
                assert(top.* == null); // vacant
                break :pop top;
            };
            // insert a value to the leaf
            n.* = new: {
                const kv = key_value.make(self.key, value);
                var leaf = try node.Node(K, V).new(self.allocator, kv, null, null);
                break :new leaf;
            };
            // hold the pointer to the inserted k/v
            const kvp = n.*.?.get_item_mut();
            // fixup node up to the root from the leaf
            while (!self.stack.is_empty()) : (self.stack.force_pop()) {
                n = self.stack.force_peek();
                n.* = n.*.?.fixup();
            }
            // update the color of the root node to black
            n.*.?.color = .Black;
            return kvp;
        }

        pub fn insert(self: *Self, value: Value) Error!*Value {
            var pkv = try self.insert_entry(value);
            return pkv.value_mut();
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
