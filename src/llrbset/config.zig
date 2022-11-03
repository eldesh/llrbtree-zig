const ownership = @import("../ownership.zig");
const Ownership = ownership.Ownership;

/// Type of ownership configuration of items held in the map.
pub const Config: type = struct {
    /// Allocators for items.
    /// Defaults to `Owned`.
    item: Ownership = Ownership.owned(),
};
