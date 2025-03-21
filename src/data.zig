const std = @import("std");

pub const Single = struct {
    size: usize,
    valid_zero: bool = true,
};

pub const Repeat = struct {
    layout: *const Layout,
    amount: usize,
};

// Repeat,
// And,
// Or,
// Tag,
// Single,
// Zero,

pub const Layout = union(enum) {
    Repeat: Repeat,
    And: []const Layout,
    Or: []const Layout,
    Tag: usize,
    Single: Single,
    Zero,

    pub fn size(self: Layout) usize {
        return switch (self) {
            .Repeat => |val| val.amount * val.layout.size(),
            .And => |val| {
                var total: usize = 0;
                for (val) |v| {
                    total += v.size();
                }
                return val;
            },
            .Or => |val| {
                var max: usize = 0;
                for (val) |v| {
                    if (max < v.size()) {
                        max = v.size();
                    }
                }
                return max;
            },
            .Tag => |val| std.math.log2(val),
            .Single => |val| val.size,
            .Zero => 0,
        };
    }

    pub fn normalize(self: Layout, alloc: std.mem.Allocator) !Layout {
        return switch (self) {
            .Repeat => |val| {
                if (val.amount == 0) {
                    return .Zero;
                }
                if (val.amount == 1) {
                    return val.layout.*;
                }
                const inner = try val.layout.normalize(alloc);
                if (inner.size() == 0) {
                    return .Zero;
                }
                if (inner == .Repeat) {
                    return .{ .Repeat = .{
                        .layout = inner.Repeat.layout,
                        .amount = val.amount * inner.Repeat.amount,
                    } };
                }
            },
            .And => |val| self,
            .Or => |val| self,
            .Tag => |val| self,
            .Single => |val| self,
            .Zero => |val| self,
        }
    }
};
