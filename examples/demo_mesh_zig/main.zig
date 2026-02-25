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
    meshes: [13]MeshComponent,
    current_mesh: usize,
    white_texture: *sdl.SDL_GPUTexture,
    sampler: *sdl.SDL_GPUSampler,
    last_time: u64,
    time: Time,
    input: Input,
    active_camera: ActiveCamera,
};

const GeometryType = enum {
    circle,
    plane,
    ring,
    tetrahedron,
    box,
    octahedron,
    dodecahedron,
    icosahedron,
    capsule,
    cone,
    cylinder,
    sphere,
    torus,
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
        "Palladia Engine - Demo Mesh",
        1280,
        720,
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
    state.meshes = undefined;
    state.current_mesh = @intFromEnum(GeometryType.torus);
    state.white_texture = undefined;
    state.sampler = undefined;
    state.last_time = sdl.SDL_GetPerformanceCounter();
    state.time = .{};
    state.input = .{ .keyboard = keyboard_state };
    state.active_camera = .{};
    state.resources = resources;

    const white_texture = try palladia.material.createWhiteTexture(device);
    state.white_texture = white_texture;

    const sampler = try palladia.material.createDefaultSampler(device);
    state.sampler = sampler;

    try createMeshes(&state);
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

    for (state.meshes) |mesh| {
        if (mesh.vertex_buffer) |vb| sdl.SDL_ReleaseGPUBuffer(device, vb);
        if (mesh.index_buffer) |ib| sdl.SDL_ReleaseGPUBuffer(device, ib);
    }

    state.world.deinit();
}

fn createMeshes(state: *AppState) !void {
    const device = state.device;

    state.meshes[@intFromEnum(GeometryType.circle)] = try palladia.geometry.createCircle(device, .{
        .radius = 0.5,
        .segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.plane)] = try palladia.geometry.createPlane(device, .{
        .width = 1.0,
        .height = 1.0,
    });

    state.meshes[@intFromEnum(GeometryType.ring)] = try palladia.geometry.createRing(device, .{
        .inner_radius = 0.25,
        .outer_radius = 0.5,
        .theta_segments = 16,
        .phi_segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.tetrahedron)] = try palladia.geometry.createTetrahedron(device, .{
        .radius = 0.5,
    });

    state.meshes[@intFromEnum(GeometryType.box)] = try palladia.geometry.createBox(device, .{
        .width = 1.0,
        .height = 1.0,
        .depth = 1.0,
    });

    state.meshes[@intFromEnum(GeometryType.octahedron)] = try palladia.geometry.createOctahedron(device, .{
        .radius = 0.5,
    });

    state.meshes[@intFromEnum(GeometryType.dodecahedron)] = try palladia.geometry.createDodecahedron(device, .{
        .radius = 0.5,
    });

    state.meshes[@intFromEnum(GeometryType.icosahedron)] = try palladia.geometry.createIcosahedron(device, .{
        .radius = 0.5,
    });

    state.meshes[@intFromEnum(GeometryType.capsule)] = try palladia.geometry.createCapsule(device, .{
        .radius = 0.5,
        .height = 1.0,
        .cap_segments = 8,
        .radial_segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.cone)] = try palladia.geometry.createCone(device, .{
        .radius = 0.5,
        .height = 1.0,
        .radial_segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.cylinder)] = try palladia.geometry.createCylinder(device, .{
        .radius_top = 0.5,
        .radius_bottom = 0.5,
        .height = 1.0,
        .radial_segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.sphere)] = try palladia.geometry.createSphere(device, .{
        .radius = 0.5,
        .width_segments = 32,
        .height_segments = 16,
    });

    state.meshes[@intFromEnum(GeometryType.torus)] = try palladia.geometry.createTorus(device, .{
        .radius = 0.5,
        .tube_radius = 0.2,
        .radial_segments = 16,
        .tubular_segments = 32,
    });
}

fn createEntities(state: *AppState, swapchain_format: sdl.SDL_GPUTextureFormat) !void {
    const device = state.device;

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

    const mesh_entity = state.world.createEntity();
    try state.world.add("transform", mesh_entity, .{
        .position = .{ 0, 0, 0 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null);
    try state.world.add("mesh", mesh_entity, state.meshes[state.current_mesh], null);

    const material = try palladia.material.createPhongMaterial(device, swapchain_format, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        .texture = state.white_texture,
        .sampler = state.sampler,
    });
    try state.world.add("material", mesh_entity, material, null);

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

    const point_light = state.world.createEntity();
    var point_ctx = palladia.systems.RenderSystem.getPointLightContextWithDevice(device);
    try state.world.add("transform", point_light, .{
        .position = .{ 2, 2, -2 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null);
    try state.world.add("point_light", point_light, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1.0 },
    }, &point_ctx);
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
                if (event.key.key == sdl.SDLK_UP) {
                    if (state.current_mesh < state.meshes.len - 1) {
                        state.current_mesh += 1;
                        if (state.world.get("mesh", @as(palladia.ecs.Entity, @intCast(1)))) |mesh| {
                            mesh.* = state.meshes[state.current_mesh];
                        }
                    }
                }
                if (event.key.key == sdl.SDLK_DOWN) {
                    if (state.current_mesh > 0) {
                        state.current_mesh -= 1;
                        if (state.world.get("mesh", @as(palladia.ecs.Entity, @intCast(1)))) |mesh| {
                            mesh.* = state.meshes[state.current_mesh];
                        }
                    }
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

    if (state.world.get("transform", @as(palladia.ecs.Entity, @intCast(1)))) |transform| {
        const rot_x = palladia.math.quatFromAxisAngle(.{ 1, 0, 0 }, 0.005);
        const rot_z = palladia.math.quatFromAxisAngle(.{ 0, 0, 1 }, 0.01);
        transform.rotation = palladia.math.quatMultiply(rot_z, palladia.math.quatMultiply(rot_x, transform.rotation));
        transform.rotation = palladia.math.quatNormalize(transform.rotation);
    }

    Scheduler.runEvent(&state.world, &state.resources);
    Scheduler.runUpdate(&state.world, &state.resources);
}

fn render(state: *AppState) void {
    Scheduler.runRender(&state.world, &state.resources);
}
