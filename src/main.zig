const std = @import("std");
const Con = @import("./basis-concept-zig");

const testing = std.testing;

const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

/// Red-Black tree
pub fn RedBlackTree(comptime K: type, comptime V: type) type {
    comptime assert(Con.isPartialOrd(K));

    return struct {
        pub const Self = @This();
        pub const Key = K;
        pub const Value = V;

        // pub const Entry = struct {
        //     key: *const Key,
        //     val: *Value,
        // };

        allocator: Allocator,

        pub fn new(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        // pub fn keys(self: *const Self) iter.KeyConstIter(K, V) {
        // }

        // pub fn mut_keys(self: *Self) iter.KeyIter(K, V) {
        // }

        // pub fn values(self: *const Self) iter.ValueConstIter(K, V) {
        // }

        // pub fn mut_values(self: *Self) iter.ValueIter(K, V) {
        // }

        // pub fn destroy(self: Self) void {
        // }

        // pub fn insert(self: *Self, key: K, value: V) !Entry {
        // }

        // pub fn remove(self: *Self, key: *K) ?Value {
        // }

        // pub fn get(self: *Self, key: *K) ?Entry {
        // }

        // pub fn mut_get(self: *Self, key: *K) ?Entry {
        // }
    };
}
