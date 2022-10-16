const std = @import("std");

const Order = std.math.Order;

// Comparison of zig-strings by lexicographic order.
// This function gives total order.
pub fn order(x: *const []const u8, y: *const []const u8) Order {
    const xlen = x.*.len;
    const ylen = y.*.len;
    switch (std.math.order(xlen, ylen)) {
        .lt => return .lt,
        .gt => return .gt,
        else => {},
    }
    for (x.*) |xc, i| {
        switch (std.math.order(xc, y.*[i])) {
            .lt => return .lt,
            .gt => return .gt,
            else => {},
        }
    }
    return .eq;
}
