const std = @import("std");

/// Kind of ownership
pub const Ownership: type = union(enum) {
    pub const Self: type = @This();

    /// owned allocated with the allocator
    OwnedAlloc: std.mem.Allocator,
    /// owned
    Owned: void,
    /// not owned
    NotOwned: void,

    /// Construct `OwnedAlloc` with the allocator
    pub fn with_alloc(alloc: std.mem.Allocator) Self {
        return Self{ .OwnedAlloc = alloc };
    }

    /// Construct `Owned`
    pub fn owned() Self {
        return Self{ .Owned = {} };
    }

    /// Construct `NotOwned`
    pub fn not_owned() Self {
        return Self{ .NotOwned = {} };
    }
};
