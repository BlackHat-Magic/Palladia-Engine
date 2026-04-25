const std = @import("std");
const sdl = @import("../sdl.zig").c;
const draw2d = @import("../components/draw2d.zig");

pub const TextureRegistry = struct {
    textures: std.ArrayListUnmanaged(*sdl.SDL_GPUTexture) = .{},
    next_id: draw2d.TextureId = 1,

    pub fn register(self: *TextureRegistry, allocator: std.mem.Allocator, texture: *sdl.SDL_GPUTexture) !draw2d.TextureId {
        const id = self.next_id;
        self.next_id += 1;
        try self.textures.append(allocator, texture);
        return id;
    }

    pub fn get(self: *const TextureRegistry, id: draw2d.TextureId) ?*sdl.SDL_GPUTexture {
        if (id == 0) return null;
        const index = id - 1;
        if (index >= self.textures.items.len) return null;
        return self.textures.items[@intCast(index)];
    }

    pub fn deinit(self: *TextureRegistry, allocator: std.mem.Allocator) void {
        self.textures.deinit(allocator);
    }
};

pub const FontRegistry = struct {
    fonts: std.ArrayListUnmanaged(*sdl.TTF_Font) = .{},
    next_id: draw2d.FontId = 1,

    pub fn register(self: *FontRegistry, allocator: std.mem.Allocator, font: *sdl.TTF_Font) !draw2d.FontId {
        const id = self.next_id;
        self.next_id += 1;
        try self.fonts.append(allocator, font);
        return id;
    }

    pub fn get(self: *const FontRegistry, id: draw2d.FontId) ?*sdl.TTF_Font {
        if (id == 0) return null;
        const index = id - 1;
        if (index >= self.fonts.items.len) return null;
        return self.fonts.items[@intCast(index)];
    }

    pub fn deinit(self: *FontRegistry, allocator: std.mem.Allocator) void {
        self.fonts.deinit(allocator);
    }
};

test "TextureRegistry register and get" {
    const allocator = std.testing.allocator;
    var reg = TextureRegistry{};

    const dummy: *sdl.SDL_GPUTexture = @ptrFromInt(0xDEAD);
    const id = try reg.register(allocator, dummy);
    try std.testing.expectEqual(@as(draw2d.TextureId, 1), id);
    try std.testing.expectEqual(@as(?*sdl.SDL_GPUTexture, dummy), reg.get(id));

    try std.testing.expectEqual(@as(?*sdl.SDL_GPUTexture, null), reg.get(0));

    reg.deinit(allocator);
}

test "FontRegistry register and get" {
    const allocator = std.testing.allocator;
    var reg = FontRegistry{};

    const dummy: *sdl.TTF_Font = @ptrFromInt(0xBEEF);
    const id = try reg.register(allocator, dummy);
    try std.testing.expectEqual(@as(draw2d.FontId, 1), id);
    try std.testing.expectEqual(@as(?*sdl.TTF_Font, dummy), reg.get(id));

    try std.testing.expectEqual(@as(?*sdl.TTF_Font, null), reg.get(0));

    reg.deinit(allocator);
}
