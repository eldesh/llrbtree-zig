const std = @import("std");

const Allocator = std.mem.Allocator;

/// Type of configuration parameters
pub fn Config(comptime Alloc: Allocator) type {
    return struct {
        /// Allocators for keys.
        /// Defaults to `Alloc`.
        key_alloc: Allocator = Alloc,
        /// Allocators for values.
        /// Defaults to `Alloc`.
        value_alloc: Allocator = Alloc,
        /// Flag to toggle whether keys are owned by the map.
        /// Defaults to `true`.
        key_is_owned: bool = true,
        /// Flag to toggle whether values are owned by the map.
        /// Defaults to `true`.
        value_is_owned: bool = true,
    };
}
