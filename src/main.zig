/// An example program use rbtree-zig package.
const std = @import("std");
const rbtree = @import("rbtree-zig");

const fmt = std.fmt;
const mem = std.mem;

const assert = std.debug.assert;
const print = std.debug.print;
const testing = std.testing;

/// Overview of Set of values
fn overview_of_set_features(alloc: mem.Allocator) !void {
    var set = rbtree.llrbset.LLRBTreeSet(u32).new(alloc, .{});
    defer set.destroy();
    // For adding a value, use `insert` function.
    // The old value would be returned from the function if exists already.
    _ = try set.insert(5);
    // the old value 5 is returned
    assert((try set.insert(5)).? == 5);
    assert((try set.insert(7)) == null);

    // To lookup a value from a set, use `get` function.
    // `null` is returned if it is not exists in the set.
    assert(set.get(&@as(u32, 5)).?.* == 5);
    assert(set.get(&@as(u32, 10)) == null);

    // To delete a value, use `delete` function.
    // The deleted value is returned from the function.
    assert(set.delete(&@as(u32, 5)).? == 5);
    // '3' have been deleted already
    assert(set.delete(&@as(u32, 5)) == null);

    _ = try set.insert(5);
    _ = try set.insert(9);
    // iterators enumerate values in ascending order
    var items = set.to_iter();
    assert(items.next().?.* == 5);
    assert(items.next().?.* == 7);
    assert(items.next().?.* == 9);
}

/// Overview of key/value Map
fn overview_of_map_features(alloc: mem.Allocator) !void {
    var map = rbtree.llrbmap.LLRBTreeMap(u32, []u8).new(alloc, .{});
    defer map.destroy();
    // For adding a key/value pair, use `insert` function.
    // The old value would be returned from the function if exists.
    _ = try map.insert(5, try alloc.dupe(u8, "25"));

    // the old value "25" is returned
    var old = (try map.insert(5, try alloc.dupe(u8, "20"))).?;
    defer alloc.free(old);
    assert(mem.eql(u8, old, "25"));
    assert((try map.insert(7, try alloc.dupe(u8, "28"))) == null);

    // To lookup a value associated with a key from a map, use `get` function.
    // `null` is returned if there is no value is associated with the key.
    assert(mem.eql(u8, map.get(&@as(u32, 5)).?.*, "20"));
    assert(map.get(&@as(u32, 10)) == null);

    // To delete an entry, use `delete` function.
    // The value associated with the key is returned from the function.
    var deleted = map.delete(&@as(u32, 5)).?;
    defer alloc.free(deleted);
    assert(mem.eql(u8, deleted, "20"));
    // a value associated with '5' have been deleted already
    assert(map.delete(&@as(u32, 5)) == null);

    _ = try map.insert(5, try alloc.dupe(u8, "20"));
    _ = try map.insert(9, try alloc.dupe(u8, "36"));
    // iterators enumerate values in ascending order
    var kvs = map.to_iter();
    var k0 = kvs.next().?;
    assert(k0.key().* == 5 and mem.eql(u8, k0.value().*, "20"));
    var k1 = kvs.next().?;
    assert(k1.key().* == 7 and mem.eql(u8, k1.value().*, "28"));
    var k2 = kvs.next().?;
    assert(k2.key().* == 9 and mem.eql(u8, k2.value().*, "36"));
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer testing.expect(!gpa.deinit()) catch @panic("leak");

    print("overview_of_set_features\n", .{});
    try overview_of_set_features(gpa.allocator());
    print("overview_of_map_features\n", .{});
    try overview_of_map_features(gpa.allocator());
}

test {
    try overview_of_set_features(testing.allocator);
    try overview_of_map_features(testing.allocator);
}
