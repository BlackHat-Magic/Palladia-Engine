const std = @import("std");
const sdl = @import("sdl.zig").c;
const pool_mod = @import("pool.zig");
const world_mod = @import("world.zig");
const resource_mod = @import("resource.zig");
const scheduler_mod = @import("system/scheduler.zig");
const context = @import("system/context.zig");
const render_system_mod = @import("systems/render.zig");
const registry_mod = @import("draw2d/registry.zig");

const Entity = pool_mod.Entity;
const SystemStage = context.SystemStage;
const Time = context.Time;
const Input = context.Input;

pub const AppConfig = struct {
    name: [:0]const u8,
    version: [:0]const u8,
    identifier: [:0]const u8,
    width: u32,
    height: u32,
};

pub const RenderTarget = union(enum) {
    swapchain: *sdl.SDL_Window,
    texture: struct {
        texture: *sdl.SDL_GPUTexture,
        width: u32,
        height: u32,
    },
};

pub fn build(comptime root_plugin: type) type {
    return struct {
        pub const Systems = root_plugin.Systems;

        pub fn run() void {
            @panic("App.run() requires config. Use App.runWith(.{...}, AppConfig, Components, ResourceDefs, setup)");
        }

        pub fn runWith(
            comptime user_systems: anytype,
            comptime app_config: AppConfig,
            comptime Components: type,
            comptime ResourceDefs: type,
            comptime setup_fn: anytype,
        ) void {
            const World = world_mod.World(Components);

            const all_systems = comptime blk: {
                var arr: [Systems.len + user_systems.len + 1]type = undefined;
                for (Systems, 0..) |sys, i| arr[i] = sys;
                for (user_systems, 0..) |sys, i| arr[Systems.len + i] = sys;
                arr[Systems.len + user_systems.len] = render_system_mod.RenderSystem;
                break :blk arr;
            };
            const TypedScheduler = scheduler_mod.Scheduler(World, ResourceDefs, all_systems);

            _ = sdl.SDL_SetAppMetadata(app_config.name.ptr, app_config.version.ptr, app_config.identifier.ptr);

            if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
                std.debug.panic("Failed to init SDL: {s}", .{sdl.SDL_GetError()});
            }
            defer sdl.SDL_Quit();

            const device = sdl.SDL_CreateGPUDevice(sdl.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse {
                std.debug.panic("Failed to create GPU device: {s}", .{sdl.SDL_GetError()});
            };
            defer sdl.SDL_DestroyGPUDevice(device);

            const window = sdl.SDL_CreateWindow(
                app_config.name.ptr,
                @intCast(app_config.width),
                @intCast(app_config.height),
                sdl.SDL_WINDOW_RESIZABLE,
            ) orelse {
                std.debug.panic("Failed to create window: {s}", .{sdl.SDL_GetError()});
            };
            defer sdl.SDL_DestroyWindow(window);

            if (!sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
                std.debug.panic("Failed to claim window for GPU: {s}", .{sdl.SDL_GetError()});
            }

            render_system_mod.RenderSystem.initDepthFormat(device);
            if (!sdl.TTF_Init()) {
                std.debug.panic("Failed to init SDL_ttf: {s}", .{sdl.SDL_GetError()});
            }
            defer sdl.TTF_Quit();
            const depth_format = render_system_mod.RenderSystem.getDepthFormat();

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            var world = World.init(allocator);
            defer world.deinit();

            const ResourcesStore = resource_mod.Resources(ResourceDefs);
            var resources = ResourcesStore.init();

            var time = Time.init();
            var input = Input.init();
            var active_camera: context.ActiveCamera = .{};

            resources.set("device", device);
            resources.set("window", window);
            resources.set("time", &time);
            resources.set("input", &input);
            resources.set("active_camera", &active_camera);

            const tex_registry = allocator.create(registry_mod.TextureRegistry) catch @panic("OOM creating texture_registry");
            tex_registry.* = .{};
            resources.set("texture_registry", tex_registry);

            const font_registry = allocator.create(registry_mod.FontRegistry) catch @panic("OOM creating font_registry");
            font_registry.* = .{};
            resources.set("font_registry", font_registry);

            const Ctx = Context(Components, ResourceDefs);
            var ctx: Ctx = .{
                .device = device,
                .window = window,
                .world = &world,
                .resources = &resources,
                .allocator = allocator,
                .depth_format = depth_format,
            };

            const setup_info = @typeInfo(@TypeOf(setup_fn));
            if (setup_info == .@"fn") {
                const params = setup_info.@"fn".params;
                if (params.len == 1) {
                    setup_fn(&ctx);
                } else if (params.len == 2) {
                    setup_fn(&ctx, &world);
                } else if (params.len == 3) {
                    setup_fn(&ctx, &world, &resources);
                }
            }

            render_system_mod.RenderSystem.initDraw2D(device, window, allocator) catch @panic("Failed to init Draw2D renderer");

            mainLoop: while (true) {
                TypedScheduler.runStage(.PreUpdate, &world, &resources);

                if (input.quit_requested) {
                    break :mainLoop;
                }

                TypedScheduler.runStage(.Update, &world, &resources);
                TypedScheduler.runStage(.PostUpdate, &world, &resources);

                if (ctx.camera_entity) |cam| {
                    active_camera.entity = cam;
                    TypedScheduler.runStage(.Render, &world, &resources);
                }
            }

            render_system_mod.RenderSystem.deinit(device);
            sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
        }

        pub fn Context(comptime Components: type, comptime ResourceDefs: type) type {
            return struct {
                device: *sdl.SDL_GPUDevice,
                window: *sdl.SDL_Window,
                world: *world_mod.World(Components),
                resources: *resource_mod.Resources(ResourceDefs),
                allocator: std.mem.Allocator,
                camera_entity: ?Entity = null,
                depth_format: sdl.SDL_GPUTextureFormat,

                const Self = @This();

                pub fn setCamera(self: *Self, entity: Entity) void {
                    self.camera_entity = entity;
                }

                pub fn getDevice(self: *const Self) *sdl.SDL_GPUDevice {
                    return self.device;
                }

                pub fn getWindow(self: *const Self) *sdl.SDL_Window {
                    return self.window;
                }
            };
        }
    };
}

pub fn Plugin(comptime plugin: anytype) type {
    comptime var system_count: usize = 0;

    const systems_type = @TypeOf(@field(plugin, "systems"));
    if (@typeInfo(systems_type) == .@"struct") {
        system_count = @typeInfo(systems_type).@"struct".fields.len;
    }

    comptime var systems: [system_count]type = undefined;
    comptime var sys_idx: usize = 0;

    const systems_value = @field(plugin, "systems");
    inline for (@typeInfo(systems_type).@"struct".fields) |sys_field| {
        systems[sys_idx] = @field(systems_value, sys_field.name);
        sys_idx += 1;
    }

    return struct {
        pub const Systems = systems;
        pub const system_count_val = system_count;
    };
}

pub const TimeSystem = struct {
    pub const stage = SystemStage.PreUpdate;

    pub const Res = struct {
        time: *Time,
    };

    pub fn run(res: Res, world: anytype) void {
        _ = world;
        res.time.update();
    }
};

pub const InputSystem = struct {
    pub const stage = SystemStage.PreUpdate;

    pub const Res = struct {
        input: *Input,
    };

    pub fn run(res: Res, world: anytype) void {
        _ = world;
        res.input.update();
    }
};
