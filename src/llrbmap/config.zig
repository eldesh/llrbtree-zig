const ownership = @import("../ownership.zig");
const Ownership = ownership.Ownership;

/// Type of ownership configuration of items held in the map.
pub const Config: type = struct {
    /// Ownership of keys.
    /// Defaults to `Owned`.
    key: Ownership = Ownership.owned(),
    /// Ownership of values.
    /// Defaults to `Owned`.
    value: Ownership = Ownership.owned(),
};
