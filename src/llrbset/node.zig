const std = @import("std");

const Con = @import("basis_concept");

const node = @import("../node.zig");
const config = @import("./config.zig");

const Allocator = std.mem.Allocator;

pub fn NodeValue(comptime Self: type) type {
    return struct {
        pub fn get_key(item: *const Self.Item) *const Self.Item {
            return item;
        }

        pub fn destroy_item(self: *Self, alloc: Allocator, cfg: *const Self.Config) void {
            switch (cfg.item) {
                .OwnedAlloc => |item_alloc| Con.Destroy.destroy(self.item, item_alloc),
                .Owned => Con.Destroy.destroy(self.item, alloc),
                .NotOwned => {},
            }
        }
    };
}

pub fn Node(comptime Value: type) type {
    return node.Node(NodeValue, Value, Value, config.Config);
}
