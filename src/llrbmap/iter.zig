const node = @import("./node.zig");
const iter = @import("../iter.zig");

/// Make an iterator enumerates all key/value pairs of a `LLRBTreeMap` by ascending order.
///
/// # Details
/// An iterator enumerates all key/value pairs([`key_value.KeyValue`]) of a `LLRBTreeMap` by ascending order.
/// `Item` of the iterator is const pointer to key/value of the tree.
///
/// # Example
/// ```zig
/// var iter: Iter(K, V) = tree.iter();
/// while (iter.next()) |item| {
///   _ = item.key();
///   _ = item.value();
/// }
/// ```
pub fn Iter(comptime K: type, comptime V: type) type {
    return iter.Iter(node.Node(K, V), *const node.Node(K, V).Item);
}

/// Make an iterator enumerates all keys of a `LLRBTreeMap` by ascending order.
///
/// # Details
/// Make an iterator of const pointers which points to keys.
/// Then `Item` of the iterator is const pointer to a key of the tree.
///
/// # Example
/// ```zig
/// var keys: Keys(K, V) = map.keys();
/// while (keys.next()) |key| {
///   _ = key;
/// }
/// ```
pub fn Keys(comptime K: type, comptime V: type) type {
    return iter.Iter(node.Node(K, V), *const K);
}

/// Make an iterator enumerates all values of a `LLRBTreeMap` by ascending order of associated keys.
///
/// # Details
/// Make an iterator of const pointers which points to values.
/// Then `Item` of the iterator is const pointer to a value of the tree.
///
/// # Example
/// ```zig
/// var values: Values(K, V) = map.values();
/// while (values.next()) |value| {
///   _ = value;
/// }
/// ```
pub fn Values(comptime K: type, comptime V: type) type {
    return iter.Iter(node.Node(K, V), *const V);
}
