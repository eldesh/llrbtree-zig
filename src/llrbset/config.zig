const std = @import("std");
const Allocator = std.mem.Allocator;

/// Type of configuration parameters
pub fn Config(comptime Alloc: Allocator) type {
    return struct {
        /// Allocators for items.
        /// Defaults to `Alloc`.
        item_alloc: Allocator = Alloc,
        /// Flag to toggle whether values are owned by the set.
        /// Defaults to `true`.
        item_is_owned: bool = true,
    };
}
