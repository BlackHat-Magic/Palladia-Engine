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

const Components = struct {
    transform: Transform,
    mesh: MeshComponent,
    camera: CameraComponent,
    material: MaterialComponent,
    controller: FPSCameraController,
    point_light: PointLightComponent,
    ambient_light: AmbientLightComponent,
    rotation: Rotation,
};

const ResourceDefs = struct {
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    time: *Time,
    input: *Input,
    active_camera: *const palladia.system.ActiveCamera,
};

const Rotation = struct {
    speed: f32 = 1.0,
};

const app_config = palladia.app.AppConfig{
    .name = "Palladia Engine - Demo Mesh",
    .version = "0.1.0",
    .identifier = "com.palladia.demo_mesh",
    .width = 1280,
    .height = 720,
};

const RotationSystem = struct {
    pub const stage = palladia.system.SystemStage.Update;

    pub const Res = struct {
        time: *Time,
    };

    pub const Query = struct {
        transform: *Transform,
        rotation: *const Rotation,
    };

    pub fn runEntity(res: Res, entity: palladia.ecs.Entity, q: Query) void {
        _ = entity;
        _ = res;
        const rot_x = palladia.math.quatFromAxisAngle(.{ 1, 0, 0 }, 0.005 * q.rotation.speed);
        const rot_z = palladia.math.quatFromAxisAngle(.{ 0, 0, 1 }, 0.01 * q.rotation.speed);
        q.transform.rotation = palladia.math.quatMultiply(rot_z, palladia.math.quatMultiply(rot_x, q.transform.rotation));
        q.transform.rotation = palladia.math.quatNormalize(q.transform.rotation);
    }
};

const App = palladia.app.App(palladia.RootPlugin);
const Ctx = App.Context(Components, ResourceDefs);

fn setup(ctx: *Ctx) void {
    const device = ctx.device;
    const swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(device, ctx.window);

    const player = ctx.world.createEntity();
    ctx.world.add("transform", player, .{
        .position = .{ 0, 0, -2 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("camera", player, .{
        .fov = 70.0,
        .near_clip = 0.01,
        .far_clip = 1000.0,
    }, null) catch {};
    ctx.world.add("controller", player, .{
        .mouse_sense = 0.01,
        .move_speed = 3.0,
    }, null) catch {};

    ctx.setCamera(player);

    const white_texture = palladia.material.createWhiteTexture(device) catch return;
    const sampler = palladia.material.createDefaultSampler(device) catch return;

    const mesh = palladia.geometry.createTorus(device, .{
        .radius = 0.5,
        .tube_radius = 0.2,
        .radial_segments = 16,
        .tubular_segments = 32,
    }) catch return;

    const mesh_entity = ctx.world.createEntity();
    ctx.world.add("transform", mesh_entity, .{
        .position = .{ 0, 0, 0 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("mesh", mesh_entity, mesh, null) catch {};
    ctx.world.add("rotation", mesh_entity, .{ .speed = 1.0 }, null) catch {};

    const material = palladia.material.createPhongMaterial(device, swapchain_format, ctx.depth_format, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        .texture = white_texture,
        .sampler = sampler,
    }) catch null;
    if (material) |mat| {
        ctx.world.add("material", mesh_entity, mat, null) catch {};
    }

    var ambient_ctx = palladia.systems.RenderSystem.getAmbientLightContext(device);
    const ambient_light = ctx.world.createEntity();
    ctx.world.add("transform", ambient_light, .{
        .position = .{ 0, 0, 0 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("ambient_light", ambient_light, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 0.1 },
    }, &ambient_ctx) catch {};

    var point_ctx = palladia.systems.RenderSystem.getPointLightContext(device);
    const point_light = ctx.world.createEntity();
    ctx.world.add("transform", point_light, .{
        .position = .{ 2, 2, -2 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("point_light", point_light, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1.0 },
    }, &point_ctx) catch {};

    _ = sdl.SDL_SetWindowRelativeMouseMode(ctx.window, true);
}

pub fn main() !void {
    App.runWith(
        .{
            palladia.systems.FPSCameraEventSystem,
            palladia.systems.FPSCameraUpdateSystem,
            RotationSystem,
        },
        app_config,
        Components,
        ResourceDefs,
        setup,
    );
}
