const std = @import("std");

var arena: *std.heap.ArenaAllocator = undefined;
var ptr_size: u8 = undefined;
var registry: std.ArrayList(*const Type) = undefined;

pub fn init_all(pointer_size: u8, arena_alloc: *std.heap.ArenaAllocator) !void {
    ptr_size = pointer_size;
    arena = arena_alloc;
    registry = .init(arena.allocator());

    _void = try .new(null, .Void);
    _bool = try .new(null, .Bool);
    _isize = try .new(null, .int(ptr_size));
    _usize = try .new(null, .uint(ptr_size));
    _voidptr = try .new(null, .VoidPtr);
    _noreturn = try .new(null, .NoReturn);
    _error = try .new(null, .Error);
}

const Type = @This();

name: []const u8,
data: Data,

pub fn new(name: ?[]const u8, data: Data) !*const Type {
    const type_name = if (name) |n| n else try data.get_name();
    const self = Type {
        .name = type_name,
        .data = data,
    };

    for (registry.items) |item| {
        if (item.exact_eql(self)) {
            return item;
        }
    }

    const ptr = try arena.allocator().create(Type);

    ptr.* = self;
    try registry.append(ptr);

    return ptr;
}

pub fn exact_eql(left: Type, right: Type) bool {
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) {
        return false;
    }

    return switch (left.data) {
        .Void => true,
        .Bool => true,
        .Int => {
            const l = left.data.Int;
            const r = right.data.Int;
            return l == r;
        },
        .UInt => {
            const l = left.data.UInt;
            const r = right.data.UInt;
            return l == r;
        },
        .Float => {
            const l = left.data.Float;
            const r = right.data.Float;
            return l == r;
        },
        .VoidPtr => true,
        .NoReturn => true,

        .Mut => {
            const l = left.data.Mut;
            const r = right.data.Mut;
            return l.exact_eql(r.*);
        },
        .Named => {
            const l = left.data.Named;
            const r = right.data.Named;
            return l.name == r.name and l.type.exact_eql(r.type.*);
        },
        .NewType => {
            const l = left.data.NewType;
            const r = right.data.NewType;
            return l.exact_eql(r.*);
        },

        .Array => {
            const l = left.data.Array;
            const r = right.data.Array;
            return l.len == r.len and l.type.exact_eql(r.type.*);
        },
        .Ptr => {
            const l = left.data.Ptr;
            const r = right.data.Ptr;
            return l.exact_eql(r.*);
        },
        .Tuple => {
            const l = left.data.Tuple;
            const r = right.data.Tuple;

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
        .Nullable => {
            const l = left.data.Nullable;
            const r = right.data.Nullable;
            return l.exact_eql(r.*);
        },
        .Variant => {
            const l = left.data.Variant;
            const r = right.data.Variant;

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

        .Error => true,
    };
}

var _void: *const Type = undefined;
var _bool: *const Type = undefined;
var _isize: *const Type = undefined;
var _usize: *const Type = undefined;
var _voidptr: *const Type = undefined;
var _noreturn: *const Type = undefined;
var _error: *const Type = undefined;

pub fn Void() *const Type {
    return _void;
}
pub fn Bool() *const Type {
    return _bool;
}
pub fn Isize() *const Type {
    return _isize;
}
pub fn Usize() *const Type {
    return _usize;
}
pub fn VoidPtr() *const Type {
    return _voidptr;
}
pub fn NoReturn() *const Type {
    return _noreturn;
}
pub fn Error() *const Type {
    return _error;
}

// Void,
// Bool,
// Int,
// UInt,
// Float,
// VoidPtr,
// NoReturn,

// Mut,
// Named,
// NewType,

// Array,
// Ptr,
// Tuple,
// Nullable,
// Variant,

// Error,

pub const Data = union(enum) {
    Void,
    Bool,
    Int: u8,
    UInt: u8,
    Float: u8,
    VoidPtr,
    NoReturn,

    Mut: *const Type,
    Named: Named,
    NewType: *const Type,

    Array: Array,
    Ptr: *const Type,
    Tuple: []const *const Type,
    Nullable: *const Type,
    Variant: []const *const Type,

    Error,

    pub fn int(size: u8) Data {
        return .{ .Int = size };
    }

    pub fn uint(size: u8) Data {
        return .{ .UInt = size };
    }

    pub fn float(size: u8) Data {
        return .{ .Float = size };
    }

    pub fn mut(base: *const Type) Data {
        return .{ .Mut = base };
    }

    pub fn named(name: ?[]const u8, base: *const Type) Data {
        return .{ .Named = .{
            .name = name,
            .type = base,
        } };
    }

    pub fn ptr(base: *const Type) Data {
        return .{ .Ptr = base };
    }

    pub fn nullable(base: *const Type) Data {
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

            .Error => "ERROR",
        };
    }
};

pub const Named = struct {
    name: ?[]const u8,
    type: *const Type,
};

pub const Array = struct {
    len: u64,
    type: *const Type,
};
