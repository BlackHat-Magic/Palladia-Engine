const std = @import("std");
const sdl = @import("../sdl.zig").c;
pub fn HandlePool(comptime T: type) type {
    return struct {
        const Id = u32;

        items: std.ArrayListUnmanaged(T) = .{},
        next_id: Id = 1,

        pub fn register(self: *@This(), allocator: std.mem.Allocator, value: T) !Id {
            try self.items.append(allocator, value);
            const id = self.next_id;
            self.next_id += 1;
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
    var pool = HandlePool(u32){};

    const id1 = try pool.register(allocator, 42);
    try std.testing.expectEqual(@as(u32, 1), id1);
    try std.testing.expectEqual(@as(?u32, 42), pool.get(id1));

    const id2 = try pool.register(allocator, 99);
    try std.testing.expectEqual(@as(u32, 2), id2);
    try std.testing.expectEqual(@as(?u32, 99), pool.get(id2));

    try std.testing.expectEqual(@as(?u32, null), pool.get(0));
    try std.testing.expectEqual(@as(?u32, null), pool.get(999));

    pool.deinit(allocator);
}

test "TextureRegistry and FontRegistry exist" {
    _ = TextureRegistry{};
    _ = FontRegistry{};
}
