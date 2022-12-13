const std = @import("std");
const builtin = @import("builtin");
pub const basis = @import("basis_concept");

const SemVer = std.SemanticVersion;
const trait = std.meta.trait;
const assert = std.debug.assert;

// pub usingnamespace basis;
/// workaround criteria
pub const zig091 = SemVer.parse("0.9.1") catch unreachable;
/// *this* is older than or equals to zig-0.9.1 (<= 0.9.1).
pub const older_zig091: bool = builtin.zig_version.order(zig091).compare(.lte);
/// *this* is newer than zig-0.9.1 (> 0.9.1)
pub const newer_zig091: bool = builtin.zig_version.order(zig091).compare(.gt);

pub fn Func(comptime Arg: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg) Result;
        } else {
            return fn (Arg) Result;
        }
    }
}

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
