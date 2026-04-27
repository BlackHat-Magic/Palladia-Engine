const std = @import("std");
const sdl = @import("../sdl.zig").c;
const draw2d = @import("../components/draw2d.zig");

pub fn HandlePool(comptime T: type) type {
    return struct {
        const Id = u32;

        items: std.ArrayListUnmanaged(T) = .{},
        next_id: Id = 1,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return .{
                .items = try std.ArrayListUnmanaged(T).initCapacity(allocator, 16),
                .next_id = 1,
            };
        }

        pub fn register(self: *@This(), allocator: std.mem.Allocator, value: T) !Id {
            const id = self.next_id;
            self.next_id += 1;
            try self.items.append(allocator, value);
            return id;
        }

        pub fn get(self: *const @This(), id: Id) ?T {
            if (id == 0) return null;
            const index = id - 1;
            if (index >= self.items.items.len) return null;
            return self.items.items[@intCast(index)];
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }
    };
}

pub const TextureRegistry = HandlePool(*sdl.SDL_GPUTexture);
pub const FontRegistry = HandlePool(*sdl.TTF_Font);

test "HandlePool basic operations" {
    const allocator = std.testing.allocator;
    var pool = try HandlePool(u32).init(allocator);

    const id = try pool.register(allocator, 42);
    try std.testing.expectEqual(@as(u32, 1), id);
    try std.testing.expectEqual(@as(?u32, 42), pool.get(id));
    try std.testing.expectEqual(@as(?u32, null), pool.get(0));
    try std.testing.expectEqual(@as(?u32, null), pool.get(999));

    pool.deinit(allocator);
}

test "TextureRegistry and FontRegistry init" {
    const allocator = std.testing.allocator;
    var tex = try TextureRegistry.init(allocator);
    defer tex.deinit(allocator);
    var font = try FontRegistry.init(allocator);
    defer font.deinit(allocator);
}