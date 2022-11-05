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

        const Vacant = VacantEntry(K, V);
        const Occupied = OccupiedEntry(K, V);

        Vacant: Vacant,
        Occupied: Occupied,

        /// Construct a `Entry.Vacant`.
        pub fn new_vacant(stack: Stack, key: Key, alloc: Allocator) Self {
            return .{ .Vacant = Vacant.new(stack, key, alloc) };
        }

        /// Construct a `Entry.Occupied`.
        pub fn new_occupied(key: *const Key, value: *Value) Self {
            return .{ .Occupied = Occupied.new(key, value) };
        }

        /// Get pointer to key
        pub fn get_key(self: *const Self) *const Key {
            return switch (self.*) {
                .Vacant => |*vacant| vacant.get_key(),
                .Occupied => |*occupied| occupied.get_key(),
            };
        }

        /// Inserts a new value and returns a pointer to the value held by the Node.
        /// If the node is a vacant entry, `value` is inserted and a pointer to the value is returned.
        /// If it is an occupied entry, `value` is inserted and and the old value held by the entry is returned.
        pub fn insert(self: *Self, value: Value) Allocator.Error!*Value {
            switch (self.*) {
                .Vacant => |*vacant| {
                    var old = try vacant.insert_entry(value) catch |err| switch (err) {
                        Vacant.Error.AlreadyInserted => unreachable,
                        else => |aerr| aerr,
                    };
                    self.* = Self.new_occupied(old.key(), old.value_mut());
                    return old.value_mut();
                },
                .Occupied => |*occupied| return occupied.get_value_mut(),
            }
        }

        /// Update a value with function `f` if the entry is occupied.
        ///
        /// ```zig
        /// var map = LLRBTreeMap(u32, []const u8).new(.{ .value = .NotOwned });
        /// defer map.destroy();
        /// _ = try map.insert(42, "foo");
        /// var entry = map.entry(42);
        /// _ = entry.modify(struct {
        ///     fn bar(s: *[]const u8) void { s.* = "bar"; }
        /// }.bar);
        /// try testing.expectEqualStrings("bar", map.get(&@as(u32, 42)).?.*);
        /// ```
        pub fn modify(self: *Self, f: fn (*Value) void) *Self {
            switch (self.*) {
                .Occupied => |*occupied| f(occupied.get_value_mut()),
                else => {},
            }
            return self;
        }
    };
}

/// An empty entry associated with a key.
/// It is able to insert a new value for the key.
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
        key: Key,
        inserted: bool,
        alloc: Allocator,

        fn new(stack: Stack, key: Key, alloc: Allocator) Self {
            {
                var muts = stack;
                assert(muts.force_peek().* == null);
            }
            return .{ .stack = stack, .key = key, .inserted = false, .alloc = alloc };
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
                var leaf = try node.Node(K, V).new(self.alloc, kv, null, null);
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

/// Occupancy entry specified by key.
/// It is able to be updated the value for the key.
/// Bacause it must be maintained order relation, the key is not able to be updated.
pub fn OccupiedEntry(comptime K: type, comptime V: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Key: type = K;
        pub const Value: type = V;

        key: *const Key,
        value: *Value,

        fn new(key: *const Key, value: *Value) Self {
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

        /// Inserts a new value for the key.
        pub fn insert(self: *Self, value: Value) Value {
            const old = self.value.*;
            self.value.* = value;
            return old;
        }
    };
}
