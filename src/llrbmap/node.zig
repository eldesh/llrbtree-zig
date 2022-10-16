const std = @import("std");
const Con = @import("basis_concept");

const key_value = @import("./key_value.zig");
const node = @import("../node.zig");
const entry = @import("./entry.zig");
const static_stack = @import("../static_stack.zig");

const Allocator = std.mem.Allocator;
const Entry = entry.Entry;
const StaticStack = static_stack.StaticStack;

const print = std.debug.print;

/// Derive methods defined only for Node specified for Key/Value type.
fn NodeKeyValue(comptime Self: type) type {
    const Item = Self.Item;
    const Key = Self.Item.Key;
    const Value = Self.Item.Value;
    return struct {
        pub fn get_key(item: *const Item) *const Key {
            return item.key();
        }

        pub fn get_value(item: *const Item) *const Value {
            return item.value();
        }

        pub fn get_value_mut(item: *Item) *Value {
            return item.value();
        }

        pub fn entry(self: *?*Self, allocator: Allocator, key: Key) Entry(Key, Value) {
            var stack = StaticStack(*?*Self, Self.MaxPathLength).new();
            stack.force_push(self);
            while ((stack.force_peek()).*) |n| {
                switch (Con.Ord.on(*const Key)(&key, Self.get_key(&n.item))) {
                    .lt => {
                        // print("{} < {}\n", .{ key, Self.get_key(&n.item).* });
                        stack.force_push(&n.lnode);
                    },
                    .eq => {
                        // print("found: {}\n", .{key});
                        return Entry(Key, Value).new_occupied(n.item.key(), n.item.value_mut());
                    },
                    .gt => {
                        // print("{} > {}\n", .{ key, Self.get_key(&n.item).* });
                        stack.force_push(&n.rnode);
                    },
                }
            }
            // not found a value associated for the key
            // print("not found: {}\n", .{key});
            return Entry(Key, Value).new_vacant(stack, allocator, key);
        }
    };
}

pub fn Node(comptime Key: type, comptime Value: type) type {
    return node.Node(NodeKeyValue, key_value.KeyValue(Key, Value), Key);
}
