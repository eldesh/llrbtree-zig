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

pub fn have_type(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        if (!trait.isContainer(T))
            return null;
        if (!@hasDecl(T, name))
            return null;

        const field = @field(T, name);
        if (@typeInfo(@TypeOf(field)) == .Type) {
            return field;
        }
        return null;
    }
}

comptime {
    const E = struct {};
    const C = struct {
        pub const Self = @This();
    };
    assert(have_type(E, "Self") == null);
    assert(have_type(C, "Self") != null);
    assert(have_type(u32, "cmp") == null);
}

pub fn have_field(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        const fields = switch (@typeInfo(T)) {
            .Struct => |s| s.fields,
            .Union => |u| u.fields,
            .Enum => |e| e.fields,
            else => false,
        };

        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                return field.field_type;
            }
        }

        return null;
    }
}

// On zig-0.10.0, `@hasDecl` crashes.
fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    comptime {
        switch (@typeInfo(T)) {
            .Struct, .Union, .Enum, .Opaque => {
                for (std.meta.declarations(T)) |decl| {
                    if (decl.is_pub) {
                        if (std.mem.eql(u8, decl.name, name))
                            return true;
                    }
                }
                return false;
            },
            else => return false,
        }
    }
}

pub fn have_fun(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        if (newer_zig091) {
            if (!std.meta.trait.isContainer(T))
                return null;
            if (!hasDecl(T, name))
                return null;
            return @as(?type, @TypeOf(@field(T, name)));
        } else {
            switch (@typeInfo(T)) {
                .Struct => |Struct| {
                    for (Struct.decls) |decl| {
                        if (std.mem.eql(u8, decl.name, name))
                            return @TypeOf(@field(T, name));
                    }
                },
                .Union => |Union| {
                    for (Union.decls) |decl| {
                        if (std.mem.eql(u8, decl.name, name))
                            return @TypeOf(@field(T, name));
                    }
                },
                .Enum => |Enum| {
                    for (Enum.decls) |decl| {
                        if (std.mem.eql(u8, decl.name, name))
                            return @TypeOf(@field(T, name));
                    }
                },
                .Opaque => |Opaque| {
                    for (Opaque.decls) |decl| {
                        if (std.mem.eql(u8, decl.name, name))
                            return @TypeOf(@field(T, name));
                    }
                },
                else => {},
            }
            return null;
        }
    }
}

/// Returns error type of the error union type `R`.
pub fn err_type(comptime R: type) type {
    comptime assert(trait.is(.ErrorUnion)(R));
    return comptime @typeInfo(R).ErrorUnion.error_set;
}

/// Returns 'right' (not error) type of the error union type `R`.
pub fn ok_type(comptime R: type) type {
    comptime assert(trait.is(.ErrorUnion)(R));
    return comptime @typeInfo(R).ErrorUnion.payload;
}

comptime {
    const FooError = error{Foo};
    assert(err_type(FooError!u32) == FooError);
    assert(ok_type(FooError!u32) == u32);
}

fn is_func_type(comptime F: type) bool {
    comptime {
        const info = @typeInfo(F);
        return switch (info) {
            .Fn => true,
            else => false,
        };
    }
}

pub fn func_arity(comptime F: type) usize {
    comptime {
        assert(is_func_type(F));
        return @typeInfo(F).Fn.args.len;
    }
}

pub fn is_unary_func_type(comptime F: type) bool {
    comptime return is_func_type(F) and @typeInfo(F).Fn.args.len == 1;
}

pub fn is_binary_func_type(comptime F: type) bool {
    comptime return is_func_type(F) and @typeInfo(F).Fn.args.len == 2;
}

pub fn domain(comptime F: type) type {
    comptime return std.meta.ArgsTuple(F);
}

pub fn codomain(comptime F: type) type {
    comptime {
        assert(is_func_type(F));
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
