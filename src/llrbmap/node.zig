const key_value = @import("./key_value.zig");
const node = @import("../node.zig");

pub fn NodeKeyValue(comptime Self: type) type {
    return struct {
        pub fn get_key(item: *const Self.Item) *const Self.Item.Key {
            return item.key();
        }

        pub fn get_value(item: *const Self) *const Self.Item.Value {
            return item.value();
        }
    };
}

pub fn Node(comptime Key: type, comptime Value: type) type {
    return node.Node(NodeKeyValue, key_value.KeyValue(Key, Value), Key);
}
