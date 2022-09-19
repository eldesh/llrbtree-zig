const std = @import("std");

const Tuple = std.meta.Tuple;

/// A type of key/value pair.
pub fn KeyValue(comptime Key: type, comptime Value: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Key: type = Key;
        pub const Value: type = Value;

        _key: Key,
        _value: Value,

        // pub fn new(key_: Key, value_: Value) Self {
        //     return .{ .key = key_, .value = value_ };
        // }

        pub fn key(self: *const Self) *const Key {
            return &self._key;
        }

        pub fn value(self: *const Self) *const Value {
            return &self._value;
        }

        pub fn toTuple(self: Self) Tuple(&[_]type{ Key, Value }) {
            return .{ self._key, self._value };
        }

        pub fn fromTuple(tuple: Tuple(&[_]type{ Key, Value })) Self {
            return Self{ .key = tuple[0], .value = tuple[1] };
        }

        pub fn asTuple(self: *const Self) Tuple(&[_]type{ *const Key, *const Value }) {
            return .{ self.key(), self.value() };
        }
    };
}

pub fn make(key: anytype, value: anytype) KeyValue(@TypeOf(key), @TypeOf(value)) {
    return KeyValue(@TypeOf(key), @TypeOf(value)){ ._key = key, ._value = value };
}
