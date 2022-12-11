const iter = @import("../iter.zig");
const node = @import("./node.zig");

/// An iterator enumerates all values of a `LLRBTreeSet` by asceding order.
///
/// # Details
/// An iterator enumerates all values of a `LLRBTreeSet` by asceding order.
/// `Item` of the iterator is const pointer to a value of the container.
///
/// # Example
/// ```zig
/// var iter = tree.iter();
/// while (iter.next()) |item| {
///   _ = item;
/// }
/// ```
pub fn Iter(comptime V: type) type {
    return iter.Iter(node.Node(V), *const V);
}

test "llrbset.iter" {
    const iter_zig = @import("iter-zig");
    const std = @import("std");
    const assert = std.debug.assert;
    comptime {
        assert(iter_zig.prelude.isIterator(Iter(u32)));
        assert(Iter(u32).Item == *const u32);
    }
}
