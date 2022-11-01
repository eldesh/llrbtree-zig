const std = @import("std");

const config = @import("config.zig");
const key_value = @import("./key_value.zig");
const node = @import("../node.zig");
const entry = @import("./entry.zig");
const static_stack = @import("../static_stack.zig");

const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const Entry = entry.Entry;
const StaticStack = static_stack.StaticStack;

const print = std.debug.print;

/// Derive methods defined only for Node specified for Key/Value type.
fn NodeKeyValue(comptime Self: type) type {
    // short hands
    const Item = Self.Item;
    const Key = Self.Item.Key;
    const Value = Self.Item.Value;
    const Alloc = Self.Alloc;
    const Config = Self.Config;

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

        pub fn destroy_item(self: *Self, cfg: *const Config) void {
            var tup = self.item.toTuple();
            if (cfg.key_is_owned)
                Con.Destroy.destroy(tup[0], cfg.key_alloc);

            if (cfg.value_is_owned)
                Con.Destroy.destroy(tup[1], cfg.value_alloc);
        }

        pub fn entry(self: *?*Self, key: Key, cmp: fn (*const Key, *const Key) Order) Entry(Key, Value, Alloc) {
            var stack = StaticStack(*?*Self, Self.MaxPathLength).new();
            stack.force_push(self);
            while (stack.force_peek().*) |n| {
                switch (cmp(&key, Self.get_key(&n.item))) {
                    .lt => {
                        // print("{} < {}\n", .{ key, Self.get_key(&n.item).* });
                        stack.force_push(&n.lnode);
                    },
                    .eq => {
                        // print("found: {}\n", .{key});
                        return Entry(Key, Value, Alloc).new_occupied(n.item.key(), n.item.value_mut());
                    },
                    .gt => {
                        // print("{} > {}\n", .{ key, Self.get_key(&n.item).* });
                        stack.force_push(&n.rnode);
                    },
                }
            }
            // not found a value associated for the key
            // print("not found: {}\n", .{key});
            return Entry(Key, Value, Alloc).new_vacant(stack, key);
        }
    };
}

pub fn Node(comptime Key: type, comptime Value: type, comptime Alloc: Allocator) type {
    return node.Node(NodeKeyValue, key_value.KeyValue(Key, Value), Key, Alloc, config.Config(Alloc));
}
