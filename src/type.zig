const std = @import("std");

var arena: *std.heap.ArenaAllocator = undefined;
var ptr_size: usize = undefined;
var registry: std.ArrayList(*const Self) = undefined;

pub fn init_all(pointer_size: usize, arena_alloc: *std.heap.ArenaAllocator) !void {
    ptr_size = pointer_size;
    arena = arena_alloc;
    registry = .init(arena.allocator());
    Error.init_errors(arena.allocator());

    _void = try .new(null, .Void);
    _bool = try .new(null, .Bool);
    _isize = try .new(null, .int(ptr_size));
    _usize = try .new(null, .uint(ptr_size));
    _voidptr = try .new(null, .VoidPtr);
    _noreturn = try .new(null, .NoReturn);
    _type = try .new(null, .Type);
    _error = try .new(null, .ERROR);
}

const Self = @This();

name: []const u8,
data: Data,

pub fn new(name: ?[]const u8, data: Data) !*const Self {
    const type_name = if (name) |n| n else try data.get_name();
    const self = Self{
        .name = type_name,
        .data = data,
    };

    for (registry.items) |item| {
        if (item.exact_eql(self)) {
            return item;
        }
    }

    const ptr = try arena.allocator().create(Self);

    ptr.* = self;
    try registry.append(ptr);

    return ptr;
}

var _void: *const Self = undefined;
var _bool: *const Self = undefined;
var _isize: *const Self = undefined;
var _usize: *const Self = undefined;
var _voidptr: *const Self = undefined;
var _noreturn: *const Self = undefined;
var _type: *const Self = undefined;
var _error: *const Self = undefined;

pub fn Void() *const Self {
    return _void;
}
pub fn Bool() *const Self {
    return _bool;
}
pub fn Isize() *const Self {
    return _isize;
}
pub fn Usize() *const Self {
    return _usize;
}
pub fn VoidPtr() *const Self {
    return _voidptr;
}
pub fn NoReturn() *const Self {
    return _noreturn;
}
pub fn Type() *const Self {
    return _type;
}
pub fn ERROR() *const Self {
    return _error;
}

// Void,
// Bool,
// Int,
// UInt,
// Float,
// VoidPtr,
// NoReturn,
// Type,

// Mut,
// Named,
// NewType,

// Array,
// Ptr,
// Tuple,
// Nullable,
// Variant,
// Result,

// ERROR,

pub const Data = union(enum) {
    Void,
    Bool,
    Int: usize,
    UInt: usize,
    Float: usize,
    VoidPtr,
    NoReturn,
    Type,

    Mut: *const Self,
    Named: Named,
    NewType: NewType,

    Array: Array,
    Ptr: *const Self,
    Tuple: []const *const Self,
    Nullable: *const Self,
    Variant: []const *const Self,
    Result: Result,

    ERROR,

    pub fn int(bits: usize) Data {
        return .{ .Int = bits };
    }

    pub fn uint(bits: usize) Data {
        return .{ .UInt = bits };
    }

    pub fn float(bits: usize) Data {
        return .{ .Float = bits };
    }

    pub fn mut(base: *const Self) Data {
        return .{ .Mut = base };
    }

    pub fn named(name: ?[]const u8, base: *const Self) Data {
        return .{ .Named = .{
            .name = name,
            .type = base,
        } };
    }

    pub fn ptr(base: *const Self) Data {
        return .{ .Ptr = base };
    }

    pub fn nullable(base: *const Self) Data {
        return .{ .Nullable = base };
    }

    pub fn get_name(self: Data) ![]const u8 {
        return switch (self) {
            .Void => "void",
            .Bool => "bool",
            .Int => |val| try std.fmt.allocPrint(arena.allocator(), "i{}", .{val}),
            .UInt => |val| try std.fmt.allocPrint(arena.allocator(), "u{}", .{val}),
            .Float => |val| try std.fmt.allocPrint(arena.allocator(), "f{}", .{val}),
            .VoidPtr => "voidptr",
            .NoReturn => "noreturn",
            .Type => "type",

            .Mut => |val| try std.fmt.allocPrint(arena.allocator(), "mut {s}", .{val.name}),
            .Named => |val| {
                if (val.name) |name| {
                    return try std.fmt.allocPrint(arena.allocator(), "{s}: {s}", .{ name, val.type.name });
                } else {
                    return try std.fmt.allocPrint(arena.allocator(), "named {s}", .{val.type.name});
                }
            },
            .NewType => |val| val.name,

            .Array => |val| try std.fmt.allocPrint(arena.allocator(), "[{}]{s}", .{ val.len, val.type.name }),
            .Ptr => |val| try std.fmt.allocPrint(arena.allocator(), "*{s}", .{val.name}),
            .Tuple => |val| {
                var res = std.ArrayList(u8).init(arena.allocator());

                try res.append('(');
                for (val, 0..) |t, i| {
                    if (i != 0) {
                        try res.appendSlice(", ");
                    }

                    try res.appendSlice(t.name);
                }
                try res.append(')');

                return try res.toOwnedSlice();
            },
            .Nullable => |val| try std.fmt.allocPrint(arena.allocator(), "?{s}", .{val.name}),
            .Variant => |val| {
                var res = std.ArrayList(u8).init(arena.allocator());

                try res.append('<');
                for (val, 0..) |t, i| {
                    if (i != 0) {
                        try res.appendSlice(", ");
                    }

                    try res.appendSlice(t.name);
                }
                try res.append('>');

                return try res.toOwnedSlice();
            },
            .Result => |val| try std.fmt.allocPrint(arena.allocator(), "!{s}", .{val.type.name}),

            .ERROR => "ERROR",
        };
    }

    // Size in bits
    pub fn size(self: Data) usize {
        return switch (self) {
            .Void => 0,
            .Bool => 1,
            .Int => |val| val,
            .UInt => |val| val,
            .Float => |val| val,
            .VoidPtr => ptr_size,
            .NoReturn => 0,
            .Type => 0,

            .Mut => |val| val.data.size(),
            .Named => |val| val.type.data.size(),
            .NewType => |val| val.type.data.size(),

            .Array => |val| val.len * val.type.data.size(),
            .Ptr => ptr_size,
            .Tuple => |val| {
                var sum: usize = 0;
                for (val) |t| {
                    sum += t.data.size();
                }
                return sum;
            },
            .Nullable => |val| 1 + val.data.size(),
            .Variant => |val| {
                if (val.len == 0) {
                    return 0;
                }
                var max: usize = 0;
                for (val) |t| {
                    if (max < t.data.size()) {
                        max = t.data.size();
                    }
                }
                return @log2(val.len) + max;
            },
            .Result => |val| @max(ptr_size, val.type.data.size()),

            .ERROR => 0,
        };
    }

    pub fn exact_eql(left: Data, right: Data) bool {
        if (std.meta.activeTag(left) != std.meta.activeTag(right)) {
            return false;
        }

        return switch (left) {
            .Void => true,
            .Bool => true,
            .Int => {
                const l = left.Int;
                const r = right.Int;
                return l == r;
            },
            .UInt => {
                const l = left.UInt;
                const r = right.UInt;
                return l == r;
            },
            .Float => {
                const l = left.Float;
                const r = right.Float;
                return l == r;
            },
            .VoidPtr => true,
            .NoReturn => true,
            .Type => true,

            .Mut => {
                const l = left.Mut;
                const r = right.Mut;
                return l.exact_eql(r.*);
            },
            .Named => {
                const l = left.Named;
                const r = right.Named;
                return l.name == r.name and l.type.exact_eql(r.type.*);
            },
            .NewType => {
                const l = left.NewType;
                const r = right.NewType;
                return std.mem.eql(u8, l.name, r.name);
            },

            .Array => {
                const l = left.Array;
                const r = right.Array;
                return l.len == r.len and l.type.exact_eql(r.type.*);
            },
            .Ptr => {
                const l = left.Ptr;
                const r = right.Ptr;
                return l.exact_eql(r.*);
            },
            .Tuple => {
                const l = left.Tuple;
                const r = right.Tuple;

                if (l.len != r.len) {
                    return false;
                }

                for (l, r) |li, ri| {
                    if (!li.data.exact_eql(ri.data)) {
                        return false;
                    }
                }

                return true;
            },
            .Nullable => {
                const l = left.Nullable;
                const r = right.Nullable;
                return l.exact_eql(r.*);
            },
            .Variant => {
                const l = left.Variant;
                const r = right.Variant;

                if (l.len != r.len) {
                    return false;
                }

                for (l, r) |li, ri| {
                    if (!li.exact_eql(ri.*)) {
                        return false;
                    }
                }

                return true;
            },
            .Result => {
                const l = left.Result;
                const r = right.Result;

                if (l.type != r.type) {
                    return false;
                }

                if (l.errors.len != r.errors.len) {
                    return false;
                }

                for (l.errors, r.errors) |el, er| {
                    if (el.id != er.id) {
                        return false;
                    }
                }

                return true;
            },

            .ERROR => true,
        };
    }
};

pub const Named = struct {
    name: ?[]const u8,
    type: *const Self,
};

pub const NewType = struct {
    name: []const u8,
    type: *const Self,
};

pub const Error = struct {
    name: []const u8,
    id: usize,
    type: *const Self,

    var next_id: usize = 0;
    var errors: std.StringHashMap(*const Error) = undefined;

    pub fn init_errors(alloc: std.mem.Allocator) void {
        errors = .init(alloc);
    }

    pub fn get(name: []const u8) ?*const Error {
        return errors.get(name);
    }

    pub fn new(name: []const u8, t: *const Self) !*const Error {
        const res = try errors.getOrPut(name);

        if (!res.found_existing) {
            res.value_ptr.* = .{
                .name = name,
                .id = next_id,
                .type = t,
            };

            next_id += 1;
        }

        return res.value_ptr.*;
    }
};

pub const Array = struct {
    len: usize,
    type: *const Self,
};

pub const Result = struct {
    type: *const Self,
    // Sorted for ids
    errors: []const Error,

    pub fn new_in_place(t: *const Self, errors: []Error) Result {
        std.mem.sort(Error, errors, void, struct {
            pub fn less_than(_: @TypeOf(void), lhs: Error, rhs: Error) bool {
                return lhs.id < rhs.id;
            }
        }.less_than);

        return .{
            .type = t,
            .errors = errors,
        };
    }

    pub fn new(t: *const Self, errors: []const Error) !Result {
        return new_in_place(t, try arena.allocator().dupe(Error, errors));
    }
};
