const node = @import("./node.zig");
const iter = @import("../iter.zig");

/// An iterator enumerates all key/value pairs of a `LLRBTreeMap` by asceding order.
///
/// # Details
/// An iterator enumerates all key/value pairs([`key_value.KeyValue`]) of a `LLRBTreeMap` by asceding order.
/// `Item` of the iterator is const pointer to key/value of the tree.
///
/// # Example
/// ```zig
/// var iter = tree.iter();
/// while (iter.next()) |item| {
///   _ = item;
/// }
/// ```
pub fn Iter(comptime K: type, comptime V: type) type {
    return iter.Iter(node.Node(K, V));
}
