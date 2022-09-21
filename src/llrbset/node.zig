const node = @import("../node.zig");

pub fn NodeValue(comptime Self: type) type {
    return struct {
        pub fn get_key(item: *const Self.Item) *const Self.Item {
            return item;
        }
    };
}

pub fn Node(comptime Value: type) type {
    return node.Node(NodeValue, Value, Value);
}
