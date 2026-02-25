const sdl = @import("../sdl.zig").c;
const Entity = @import("../pool.zig").Entity;

pub const SystemStage = enum {
    event,
    update,
    render,
};

pub const Time = struct {
    dt: f32 = 0,
    total: f32 = 0,
    frame: u64 = 0,
};

pub const Input = struct {
    keyboard: []const bool,
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    mouse_xrel: f32 = 0,
    mouse_yrel: f32 = 0,

    pub fn keyPressed(self: *const Input, scancode: sdl.SDL_Scancode) bool {
        return self.keyboard[@intCast(scancode)];
    }
};

pub const ActiveCamera = struct {
    entity: ?Entity = null,
};
