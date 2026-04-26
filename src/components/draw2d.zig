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
    owned: bool = false,
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

    /// Set automatically by any mutating API. Cleared by the renderer after rebuilding.
    dirty: bool = true,

    /// Suppresses auto-dirty during bulk initialization.
    bulk_updating: bool = false,

    pub fn init(allocator: std.mem.Allocator) !DrawCanvas {
        return .{
            .commands = try std.ArrayList(DrawCommand).initCapacity(allocator, 64),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DrawCanvas) void {
        for (self.commands.items) |cmd| {
            switch (cmd) {
                .text => |t| {
                    if (t.owned) {
                        self.allocator.free(t.text);
                    }
                },
                else => {},
            }
        }
        self.commands.deinit(self.allocator);
    }

    pub fn onRemove(entity: u32, world: anytype, ctx: ?*anyopaque) void {
        _ = ctx;
        const canvas = world.get("draw_canvas", entity) orelse return;
        canvas.deinit();
    }

    pub fn drawRect(self: *DrawCanvas, r: DrawRect) !void {
        try self.commands.append(self.allocator, .{ .rect = r });
        if (!self.bulk_updating) self.dirty = true;
    }

    pub fn drawSprite(self: *DrawCanvas, s: DrawSprite) !void {
        try self.commands.append(self.allocator, .{ .sprite = s });
        if (!self.bulk_updating) self.dirty = true;
    }

    pub fn drawText(self: *DrawCanvas, t: DrawText) !void {
        const copy = try self.allocator.dupe(u8, t.text);
        errdefer self.allocator.free(copy);
        var tc = t;
        tc.text = copy;
        tc.owned = true;
        try self.commands.append(self.allocator, .{ .text = tc });
        if (!self.bulk_updating) self.dirty = true;
    }

    pub fn clear(self: *DrawCanvas) void {
        self.commands.clearRetainingCapacity();
        self.dirty = true;
    }

    pub fn setZIndex(self: *DrawCanvas, z: f32) void {
        self.z_index = z;
    }

    pub fn beginBulkUpdate(self: *DrawCanvas) void {
        self.bulk_updating = true;
    }

    pub fn endBulkUpdate(self: *DrawCanvas) void {
        self.bulk_updating = false;
        self.dirty = true;
    }

    pub fn markDirty(self: *DrawCanvas) void {
        self.dirty = true;
    }
};

test "DrawCanvas basic operations" {
    const allocator = std.testing.allocator;
    var canvas = try DrawCanvas.init(allocator);
    defer canvas.deinit();

    try canvas.drawRect(.{ .x = 10, .y = 20, .w = 100, .h = 50, .color = .{ 1, 0, 0, 1 } });
    try canvas.drawRect(.{ .x = 30, .y = 40, .w = 60, .h = 80, .color = .{ 0, 1, 0, 0.5 } });
    try canvas.drawSprite(.{ .x = 0, .y = 0, .w = 64, .h = 64, .texture_id = 1 });

    try std.testing.expectEqual(@as(usize, 3), canvas.commands.items.len);

    canvas.clear();
    try std.testing.expectEqual(@as(usize, 0), canvas.commands.items.len);
}

test "DrawCanvas z-index" {
    const allocator = std.testing.allocator;
    var canvas = try DrawCanvas.init(allocator);
    defer canvas.deinit();

    try std.testing.expectEqual(@as(f32, 0), canvas.z_index);
    canvas.setZIndex(5.5);
    try std.testing.expectEqual(@as(f32, 5.5), canvas.z_index);
}

test "DrawCanvas dirty flag" {
    const allocator = std.testing.allocator;
    var canvas = try DrawCanvas.init(allocator);
    defer canvas.deinit();

    try std.testing.expect(canvas.dirty);
    canvas.dirty = false;

    try canvas.drawRect(.{ .x = 10, .y = 20, .w = 100, .h = 50, .color = .{ 1, 0, 0, 1 } });
    try std.testing.expect(canvas.dirty);

    canvas.dirty = false;
    canvas.beginBulkUpdate();
    try canvas.drawRect(.{ .x = 20, .y = 30, .w = 50, .h = 50, .color = .{ 0, 1, 0, 1 } });
    try std.testing.expect(!canvas.dirty);
    canvas.endBulkUpdate();
    try std.testing.expect(canvas.dirty);
}

test "DrawCanvas text ownership" {
    const allocator = std.testing.allocator;
    var canvas = try DrawCanvas.init(allocator);
    defer canvas.deinit();

    const text = "Hello, World!";
    try canvas.drawText(.{ .x = 10, .y = 20, .text = text, .font_id = 1, .color = .{ 1, 1, 1, 1 }, .scale = 16 });

    const cmd = canvas.commands.items[0];
    try std.testing.expectEqualStrings(text, cmd.text.text);
    try std.testing.expect(cmd.text.owned);
}
