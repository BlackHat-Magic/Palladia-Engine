const std = @import("std");
const palladia = @import("palladia");
const sdl = palladia.sdl;

const Transform = palladia.Transform;
const MeshComponent = palladia.MeshComponent;
const CameraComponent = palladia.CameraComponent;
const MaterialComponent = palladia.MaterialComponent;
const FPSCameraController = palladia.FPSCameraController;
const PointLightComponent = palladia.PointLightComponent;
const AmbientLightComponent = palladia.AmbientLightComponent;

const Time = palladia.system.Time;
const Input = palladia.system.Input;
const ActiveCamera = palladia.system.ActiveCamera;

const Components = struct {
    transform: Transform,
    mesh: MeshComponent,
    camera: CameraComponent,
    material: MaterialComponent,
    controller: FPSCameraController,
    point_light: PointLightComponent,
    ambient_light: AmbientLightComponent,
};

const ResourcesDef = struct {
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    time: *Time,
    input: *Input,
    active_camera: *ActiveCamera,
};

const World = palladia.World(Components);
const ResourcesStore = palladia.resource.Resources(ResourcesDef);
const Scheduler = palladia.system.Scheduler(World, ResourcesDef, .{
    palladia.systems.FPSCameraEventSystem,
    palladia.systems.FPSCameraUpdateSystem,
    palladia.systems.RenderSystem,
});

const AppState = struct {
    world: World,
    resources: ResourcesStore,
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    quit: bool,
    keyboard_state: []const bool,
    white_texture: *sdl.SDL_GPUTexture,
    sampler: *sdl.SDL_GPUSampler,
    last_time: u64,
    time: Time,
    input: Input,
    active_camera: ActiveCamera,
    ico_mesh: MeshComponent,
    frame_count: u64,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Stress Test - Icosahedrons",
        640,
        480,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_VULKAN,
    ) orelse {
        std.log.err("Couldn't create window: {s}", .{sdl.SDL_GetError()});
        return error.WindowCreateFailed;
    };
    defer sdl.SDL_DestroyWindow(window);

    const device = sdl.SDL_CreateGPUDevice(sdl.SDL_GPU_SHADERFORMAT_SPIRV, false, null) orelse {
        std.log.err("Couldn't create GPU device: {s}", .{sdl.SDL_GetError()});
        return error.GPUDeviceFailed;
    };
    defer sdl.SDL_DestroyGPUDevice(device);

    if (!sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
        std.log.err("Couldn't claim window: {s}", .{sdl.SDL_GetError()});
        return error.ClaimWindowFailed;
    }

    const swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window);

    var state: AppState = undefined;
    state.world = World.init(allocator);

    const resources = ResourcesStore.init();

    const keyboard_state_raw = sdl.SDL_GetKeyboardState(null);
    const keyboard_state = keyboard_state_raw[0..@as(usize, @intCast(sdl.SDL_SCANCODE_COUNT))];

    state.device = device;
    state.window = window;
    state.quit = false;
    state.keyboard_state = keyboard_state;
    state.last_time = sdl.SDL_GetPerformanceCounter();
    state.time = .{};
    state.input = .{ .keyboard = keyboard_state };
    state.active_camera = .{};
    state.resources = resources;
    state.frame_count = 0;

    const white_texture = try palladia.material.createWhiteTexture(device);
    state.white_texture = white_texture;

    const sampler = try palladia.material.createDefaultSampler(device);
    state.sampler = sampler;

    state.ico_mesh = try palladia.geometry.createIcosahedron(device, .{
        .radius = 0.5,
    });

    try createEntities(&state, swapchain_format);

    state.resources.set("device", state.device);
    state.resources.set("window", state.window);
    state.resources.set("time", &state.time);
    state.resources.set("input", &state.input);
    state.resources.set("active_camera", &state.active_camera);

    _ = sdl.SDL_SetWindowRelativeMouseMode(window, true);

    while (!state.quit) {
        try handleEvents(&state);
        try update(&state);
        render(&state);
    }

    palladia.systems.RenderSystem.deinit(device);
    sdl.SDL_ReleaseGPUTexture(device, state.white_texture);
    sdl.SDL_ReleaseGPUSampler(device, state.sampler);

    if (state.ico_mesh.vertex_buffer) |vb| sdl.SDL_ReleaseGPUBuffer(device, vb);
    if (state.ico_mesh.index_buffer) |ib| sdl.SDL_ReleaseGPUBuffer(device, ib);

    state.world.deinit();
}

fn createEntities(state: *AppState, swapchain_format: sdl.SDL_GPUTextureFormat) !void {
    const device = state.device;

    var prng = std.Random.DefaultPrng.init(42);
    const rand = prng.random();

    var spawned: u32 = 0;

    var i: i32 = -10;
    while (i < 10) : (i += 1) {
        var j: i32 = -10;
        while (j < 10) : (j += 1) {
            var k: i32 = -10;
            while (k < 10) : (k += 1) {
                const ico = state.world.createEntity();

                try state.world.add("mesh", ico, state.ico_mesh, null);

                const r = rand.float(f32);
                const g = rand.float(f32);
                const b = rand.float(f32);

                const material = try palladia.material.createPhongMaterial(device, swapchain_format, .{
                    .color = .{ .r = r, .g = g, .b = b, .a = 1.0 },
                    .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    .texture = state.white_texture,
                    .sampler = state.sampler,
                });
                try state.world.add("material", ico, material, null);

                const rand_rot_x = rand.float(f32) * 2.0 * std.math.pi;
                const rand_rot_y = rand.float(f32) * 2.0 * std.math.pi;
                const rand_rot_z = rand.float(f32) * 2.0 * std.math.pi;

                try state.world.add("transform", ico, .{
                    .position = .{
                        @as(f32, @floatFromInt(i)) * 2.0,
                        @as(f32, @floatFromInt(j)) * 2.0,
                        @as(f32, @floatFromInt(k)) * 2.0,
                    },
                    .rotation = palladia.math.quatFromEuler(.{ rand_rot_x, rand_rot_y, rand_rot_z }),
                    .scale = .{ 1, 1, 1 },
                }, null);

                spawned += 1;
            }
        }
        std.log.info("spawned {} icos", .{spawned});
    }

    const ambient_light = state.world.createEntity();
    var ambient_ctx = palladia.systems.RenderSystem.getAmbientLightContextWithDevice(device);
    try state.world.add("transform", ambient_light, .{
        .position = .{ 0, 0, 0 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null);
    try state.world.add("ambient_light", ambient_light, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 0.1 },
    }, &ambient_ctx);

    var point_ctx = palladia.systems.RenderSystem.getPointLightContextWithDevice(device);
    for (0..4) |_| {
        const point_light = state.world.createEntity();

        const px: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;
        const py: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;
        const pz: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;

        try state.world.add("transform", point_light, .{
            .position = .{
                @as(f32, @floatFromInt(px * 2 + 1)),
                @as(f32, @floatFromInt(py * 2 + 1)),
                @as(f32, @floatFromInt(pz * 2 + 1)),
            },
            .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
            .scale = .{ 1, 1, 1 },
        }, null);
        try state.world.add("point_light", point_light, .{
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1.0 },
        }, &point_ctx);
    }

    const player = state.world.createEntity();
    try state.world.add("transform", player, .{
        .position = .{ 0, 0, -2 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null);
    try state.world.add("camera", player, .{
        .fov = 70.0,
        .near_clip = 0.01,
        .far_clip = 1000.0,
    }, null);
    try state.world.add("controller", player, .{
        .mouse_sense = 0.01,
        .move_speed = 3.0,
    }, null);

    state.active_camera.entity = player;
}

fn handleEvents(state: *AppState) !void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_QUIT => {
                state.quit = true;
            },
            sdl.SDL_EVENT_KEY_DOWN => {
                if (event.key.key == sdl.SDLK_ESCAPE) {
                    state.quit = true;
                }
            },
            else => {},
        }
    }
}

fn update(state: *AppState) !void {
    const now = sdl.SDL_GetPerformanceCounter();
    const frequency = sdl.SDL_GetPerformanceFrequency();
    const dt: f32 = @as(f32, @floatFromInt(now - state.last_time)) / @as(f32, @floatFromInt(frequency));
    const total: f32 = @as(f32, @floatFromInt(now)) / @as(f32, @floatFromInt(frequency));
    state.last_time = now;

    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;
    var mouse_xrel: f32 = 0;
    var mouse_yrel: f32 = 0;
    _ = sdl.SDL_GetMouseState(&mouse_x, &mouse_y);
    _ = sdl.SDL_GetRelativeMouseState(&mouse_xrel, &mouse_yrel);

    state.time.dt = dt;
    state.time.total = total;
    state.time.frame += 1;

    state.input.keyboard = state.keyboard_state;
    state.input.mouse_x = mouse_x;
    state.input.mouse_y = mouse_y;
    state.input.mouse_xrel = mouse_xrel;
    state.input.mouse_yrel = mouse_yrel;

    const frame_start = sdl.SDL_GetTicksNS();

    var transform_iter = state.world.iter("mesh");
    while (transform_iter.next()) |entry| {
        const entity = entry.entity;
        if (state.world.get("transform", entity)) |transform| {
            const rot_x = palladia.math.quatFromAxisAngle(.{ 1, 0, 0 }, 0.005);
            const rot_z = palladia.math.quatFromAxisAngle(.{ 0, 0, 1 }, 0.01);
            transform.rotation = palladia.math.quatMultiply(rot_z, palladia.math.quatMultiply(rot_x, transform.rotation));
            transform.rotation = palladia.math.quatNormalize(transform.rotation);
        }
    }

    const rot_time = sdl.SDL_GetTicksNS() - frame_start;

    Scheduler.runEvent(&state.world, &state.resources);
    Scheduler.runUpdate(&state.world, &state.resources);

    const render_start = sdl.SDL_GetTicksNS();
    Scheduler.runRender(&state.world, &state.resources);
    const render_time = sdl.SDL_GetTicksNS() - render_start;

    if (state.frame_count % 10 == 0) {
        const rot_ms: f64 = @as(f64, @floatFromInt(rot_time)) / 1e6;
        const render_ms: f64 = @as(f64, @floatFromInt(render_time)) / 1e6;
        std.log.info("rot: {d:.3}\trender: {d:.3}", .{ rot_ms, render_ms });
    }
    state.frame_count += 1;
}

fn render(state: *AppState) void {
    _ = state;
}
