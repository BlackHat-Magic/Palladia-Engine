const std = @import("std");

pub const TextureId = u32;
pub const FontId = u32;

pub const DrawRect = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    color: [4]f32 = .{ 0, 0, 0, 0 },
    texture_id: ?TextureId = null,
    filled: bool = true,
    border_thickness: f32 = 0,
    rotation: f32 = 0,
    corner_radius: f32 = 0,
};

pub const DrawSprite = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    texture_id: TextureId,
    uv: [4]f32 = .{ 0, 0, 1, 1 },
    color: [4]f32 = .{ 0, 0, 0, 0 },
    filled: bool = true,
    border_thickness: f32 = 0,
    rotation: f32 = 0,
    corner_radius: f32 = 0,
};

pub const DrawText = struct {
    x: f32 = 0,
    y: f32 = 0,
    text: []const u8,
    font_id: FontId = 0,
    color: [4]f32 = .{ 0, 0, 0, 0 },
    scale: f32 = 1,
    rotation: f32 = 0,
};

pub const DrawCommand = union(enum) {
    rect: DrawRect,
    sprite: DrawSprite,
    text: DrawText,
};

pub const DrawCanvas = struct {
    z_index: f32 = 0,
    commands: std.ArrayList(DrawCommand),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DrawCanvas {
        return .{
            .commands = std.ArrayList(DrawCommand).initCapacity(allocator, 64) catch @panic("OOM"),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DrawCanvas) void {
        self.commands.deinit(self.allocator);
    }

    pub fn drawRect(self: *DrawCanvas, x: f32, y: f32, w: f32, h: f32, color: [4]f32) !void {
        try self.commands.append(self.allocator, .{ .rect = .{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .color = color,
        } });
    }

    pub fn drawRectOpts(self: *DrawCanvas, x: f32, y: f32, w: f32, h: f32, color: [4]f32, opts: DrawRect) !void {
        var r = opts;
        r.x = x;
        r.y = y;
        r.w = w;
        r.h = h;
        r.color = color;
        try self.commands.append(self.allocator, .{ .rect = r });
    }

    pub fn drawSprite(self: *DrawCanvas, x: f32, y: f32, w: f32, h: f32, texture_id: TextureId, uv: [4]f32, color: [4]f32) !void {
        try self.commands.append(self.allocator, .{ .sprite = .{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .texture_id = texture_id,
            .uv = uv,
            .color = color,
        } });
    }

    pub fn drawSpriteOpts(self: *DrawCanvas, x: f32, y: f32, w: f32, h: f32, texture_id: TextureId, uv: [4]f32, color: [4]f32, opts: struct {
        filled: bool = true,
        border_thickness: f32 = 0,
        rotation: f32 = 0,
        corner_radius: f32 = 0,
    }) !void {
        try self.commands.append(self.allocator, .{ .sprite = .{
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .texture_id = texture_id,
            .uv = uv,
            .color = color,
            .filled = opts.filled,
            .border_thickness = opts.border_thickness,
            .rotation = opts.rotation,
            .corner_radius = opts.corner_radius,
        } });
    }

    pub fn drawText(self: *DrawCanvas, x: f32, y: f32, text: []const u8, font_id: FontId, color: [4]f32, scale: f32) !void {
        try self.commands.append(self.allocator, .{ .text = .{
            .x = x,
            .y = y,
            .text = text,
            .font_id = font_id,
            .color = color,
            .scale = scale,
        } });
    }

    pub fn drawTextRot(self: *DrawCanvas, x: f32, y: f32, text: []const u8, font_id: FontId, color: [4]f32, scale: f32, rotation: f32) !void {
        try self.commands.append(self.allocator, .{ .text = .{
            .x = x,
            .y = y,
            .text = text,
            .font_id = font_id,
            .color = color,
            .scale = scale,
            .rotation = rotation,
        } });
    }

    pub fn clear(self: *DrawCanvas) void {
        self.commands.clearRetainingCapacity();
    }

    pub fn reset(self: *DrawCanvas) void {
        self.commands.clearRetainingCapacity();
    }

    pub fn setZIndex(self: *DrawCanvas, z: f32) void {
        self.z_index = z;
    }
};

test "DrawCanvas basic operations" {
    const allocator = std.testing.allocator;
    var canvas = DrawCanvas.init(allocator);
    defer canvas.deinit();

    try canvas.drawRect(10, 20, 100, 50, .{ 1, 0, 0, 1 });
    try canvas.drawRect(30, 40, 60, 80, .{ 0, 1, 0, 0.5 });
    try canvas.drawSprite(0, 0, 64, 64, 1, .{ 0, 0, 1, 1 }, .{ 1, 1, 1, 1 });

    try std.testing.expectEqual(@as(usize, 3), canvas.commands.items.len);

    canvas.clear();
    try std.testing.expectEqual(@as(usize, 0), canvas.commands.items.len);
}

test "DrawCanvas z-index" {
    const allocator = std.testing.allocator;
    var canvas = DrawCanvas.init(allocator);
    defer canvas.deinit();

    try std.testing.expectEqual(@as(f32, 0), canvas.z_index);
    canvas.setZIndex(5.5);
    try std.testing.expectEqual(@as(f32, 5.5), canvas.z_index);
}
