const sdl = @import("../sdl.zig").c;
const Entity = @import("../pool.zig").Entity;

pub const SystemStage = enum(usize) {
    Init,
    DeInit,
    PreUpdate,
    Update,
    PostUpdate,
    Render,
};

pub const Time = struct {
    dt: f32 = 0,
    frame: u64 = 0,
    start_ns: u64,
    last_ns: u64,

    pub fn elapsed(self: *const Time) f32 {
        const now_ns = sdl.SDL_GetTicksNS();
        return @as(f32, @floatFromInt(now_ns - self.start_ns)) / 1_000_000_000.0;
    }

    pub fn init() Time {
        const now = sdl.SDL_GetTicksNS();
        return .{
            .start_ns = now,
            .last_ns = now,
        };
    }

    pub fn update(self: *Time) void {
        const now_ns = sdl.SDL_GetTicksNS();
        const delta_ns = now_ns - self.last_ns;
        self.dt = @as(f32, @floatFromInt(delta_ns)) / 1_000_000_000.0;
        self.frame += 1;
        self.last_ns = now_ns;
    }
};

pub const Input = struct {
    keyboard_state: [*]const bool = undefined,
    num_keys: i32 = 0,
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    mouse_xrel: f32 = 0,
    mouse_yrel: f32 = 0,
    mouse_buttons: u32 = 0,
    mouse_wheel_x: f32 = 0,
    mouse_wheel_y: f32 = 0,
    quit_requested: bool = false,

    pub fn keyPressed(self: *const Input, scancode: sdl.SDL_Scancode) bool {
        const idx: usize = @intCast(scancode);
        if (idx >= @as(usize, @intCast(self.num_keys))) return false;
        return self.keyboard_state[idx];
    }

    pub fn mouseButtonPressed(self: *const Input, button: u5) bool {
        return (self.mouse_buttons & (@as(u32, 1) << button)) != 0;
    }

    pub fn leftPressed(self: *const Input) bool {
        return self.mouseButtonPressed(sdl.SDL_BUTTON_LEFT);
    }

    pub fn rightPressed(self: *const Input) bool {
        return self.mouseButtonPressed(sdl.SDL_BUTTON_RIGHT);
    }

    pub fn middlePressed(self: *const Input) bool {
        return self.mouseButtonPressed(sdl.SDL_BUTTON_MIDDLE);
    }

    pub fn init() Input {
        var self: Input = .{};
        self.keyboard_state = sdl.SDL_GetKeyboardState(&self.num_keys);
        return self;
    }

    pub fn update(self: *Input) void {
        self.mouse_xrel = 0;
        self.mouse_yrel = 0;
        self.mouse_wheel_x = 0;
        self.mouse_wheel_y = 0;
        self.quit_requested = false;

        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => {
                    self.quit_requested = true;
                },
                sdl.SDL_EVENT_MOUSE_MOTION => {
                    self.mouse_x = event.motion.x;
                    self.mouse_y = event.motion.y;
                    self.mouse_xrel += event.motion.xrel;
                    self.mouse_yrel += event.motion.yrel;
                },
                sdl.SDL_EVENT_MOUSE_WHEEL => {
                    self.mouse_wheel_x += event.wheel.x;
                    self.mouse_wheel_y += event.wheel.y;
                },
                else => {},
            }
        }

        var mx: f32 = undefined;
        var my: f32 = undefined;
        self.mouse_buttons = sdl.SDL_GetMouseState(&mx, &my);
        if (self.mouse_xrel == 0 and self.mouse_yrel == 0) {
            self.mouse_x = mx;
            self.mouse_y = my;
        }
    }
};

pub const ActiveCamera = struct {
    entity: ?Entity = null,
};
