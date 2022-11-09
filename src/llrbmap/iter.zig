const std = @import("std");
const node = @import("./node.zig");
const iter = @import("../iter.zig");

const Allocator = std.mem.Allocator;

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

test "llrbmap.iter" {
    const iter_zig = @import("iter-zig");
    const key_value = @import("key_value.zig");
    const assert = std.debug.assert;
    comptime {
        assert(iter_zig.isIterator(Iter(u32, f64)));
        assert(Iter(u32, f64).Item == *const key_value.KeyValue(u32, f64));
    }
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

test "llrbmap.keys" {
    const iter_zig = @import("iter-zig");
    const assert = std.debug.assert;
    comptime {
        assert(iter_zig.isIterator(Keys(u32, f64)));
        assert(Keys(u32, f64).Item == *const u32);
    }
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

test "llrbmap.values" {
    const iter_zig = @import("iter-zig");
    const assert = std.debug.assert;
    comptime {
        assert(iter_zig.isIterator(Values(u32, f64)));
        assert(Values(u32, f64).Item == *const f64);
    }
}
