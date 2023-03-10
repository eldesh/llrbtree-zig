const std = @import("std");
const builtin = @import("builtin");
const basis = @import("basis_concept");

const assert = std.debug.assert;

// pub usingnamespace basis;
/// workaround criteria
const zig091 = std.SemanticVersion.parse("0.9.1") catch unreachable;
/// *this* is older than or equals to zig-0.9.1 (<= 0.9.1).
pub const older_zig091: bool = builtin.zig_version.order(zig091).compare(.lte);
/// *this* is newer than zig-0.9.1 (> 0.9.1)
pub const newer_zig091: bool = builtin.zig_version.order(zig091).compare(.gt);

/// Abstract function type
///
/// # Details
/// For Zig 0.9.1, `Func(A,R)` equals to `fn (A) R`, and
/// for Zig 0.10.0, it represents `*const fn (A) R`.
pub fn Func(comptime Arg: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg) Result;
        } else {
            return fn (Arg) Result;
        }
    }
}

/// Abstract function type
///
/// # Details
/// For Zig 0.9.1, `Func(A1,A2,R)` equals to `fn (A1,A2) R`, and
/// for Zig 0.10.0, it represents `*const fn (A1,A2) R`.
pub fn Func2(comptime Arg1: type, comptime Arg2: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg1, Arg2) Result;
        } else {
            return fn (Arg1, Arg2) Result;
        }
    }
}

fn is_fun(comptime F: type) bool {
    comptime {
        const info = @typeInfo(F);
        return switch (info) {
            .Fn => true,
            else => false,
        };
    }
}

fn domain(comptime F: type) type {
    comptime return std.meta.ArgsTuple(F);
}

fn codomain(comptime F: type) type {
    comptime {
        assert(is_fun(F));
        if (@typeInfo(F).Fn.return_type) |ty| {
            return ty;
        } else {
            return void;
        }
    }
}

/// Convert a function type `F` to `Func` type.
/// `F` must be a unary function type.
pub fn toFunc(comptime F: type) type {
    comptime {
        const A = domain(F);
        const R = codomain(F);
        return Func(@typeInfo(A).Struct.fields[0].field_type, R);
    }
}

/// Convert a function type `F` to `Func` type.
/// `F` must be a binary function type.
pub fn toFunc2(comptime F: type) type {
    comptime {
        const A = domain(F);
        const R = codomain(F);
        return Func2(
            @typeInfo(A).Struct.fields[0].field_type,
            @typeInfo(A).Struct.fields[1].field_type,
            R,
        );
    }
}
