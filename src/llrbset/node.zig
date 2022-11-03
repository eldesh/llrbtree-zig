const std = @import("std");

const Con = @import("basis_concept");

const config = @import("config.zig");
const node = @import("../node.zig");

pub fn NodeValue(comptime Self: type) type {
    return struct {
        const Item = Self.Item;
        const Config = Self.Config;

        pub fn get_key(item: *const Self.Item) *const Self.Item {
            return item;
        }

        pub fn destroy_item(self: *Self, cfg: *const Config) void {
            if (cfg.item_is_owned)
                Con.Destroy.destroy(self.item, cfg.item_alloc);
        }
    };
}

pub fn Node(comptime Value: type) type {
    return node.Node(NodeValue, Value, Value, config.Config(std.testing.allocator));
}
