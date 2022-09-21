const key_value = @import("./key_value.zig");
const node = @import("../node.zig");

pub fn NodeKeyValue(comptime Self: type) type {
    return struct {
        pub fn get_key(self: *const Self) *const Self.Item.Key {
            return self.item.key();
        }

        pub fn get_value(self: *const Self) *const Self.Item.Value {
            return self.item.value();
        }
    };
}

pub fn Node(comptime Key: type, comptime Value: type) type {
    return node.Node(NodeKeyValue, key_value.KeyValue(Key, Value), Key);
}
