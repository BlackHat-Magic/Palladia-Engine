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
};

const ResourceDefs = struct {
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    time: *Time,
    input: *Input,
};

const app_config = palladia.app.AppConfig{
    .name = "Stress Test - Icosahedrons",
    .version = "0.1.0",
    .identifier = "com.palladia.stress_test_ico",
    .width = 640,
    .height = 480,
};

const App = palladia.app.App(palladia.RootPlugin);
const Ctx = App.Context(Components, ResourceDefs);

var ico_mesh: palladia.MeshComponent = undefined;
var white_texture: *sdl.SDL_GPUTexture = undefined;
var sampler: *sdl.SDL_GPUSampler = undefined;

const RotationSystem = struct {
    pub const stage = palladia.system.SystemStage.Update;

    pub const Query = struct {
        transform: *Transform,
        mesh: *const MeshComponent,
    };

    pub fn runEntity(entity: palladia.ecs.Entity, q: Query) void {
        _ = entity;
        const rot_x = palladia.math.quatFromAxisAngle(.{ 1, 0, 0 }, 0.005);
        const rot_z = palladia.math.quatFromAxisAngle(.{ 0, 0, 1 }, 0.01);
        q.transform.rotation = palladia.math.quatMultiply(rot_z, palladia.math.quatMultiply(rot_x, q.transform.rotation));
        q.transform.rotation = palladia.math.quatNormalize(q.transform.rotation);
    }
};

fn setup(ctx: *Ctx) void {
    const device = ctx.device;
    const swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(device, ctx.window);

    white_texture = palladia.material.createWhiteTexture(device) catch return;
    sampler = palladia.material.createDefaultSampler(device) catch return;

    ico_mesh = palladia.geometry.createIcosahedron(device, .{
        .radius = 0.5,
    }) catch return;

    var prng = std.Random.DefaultPrng.init(42);
    const rand = prng.random();

    var spawned: u32 = 0;

    var i: i32 = -10;
    while (i < 10) : (i += 1) {
        var j: i32 = -10;
        while (j < 10) : (j += 1) {
            var k: i32 = -10;
            while (k < 10) : (k += 1) {
                const ico = ctx.world.createEntity();

                ctx.world.add("mesh", ico, ico_mesh, null) catch {};

                const r = rand.float(f32);
                const g = rand.float(f32);
                const b = rand.float(f32);

                const material = palladia.material.createPhongMaterial(device, swapchain_format, ctx.depth_format, .{
                    .color = .{ .r = r, .g = g, .b = b, .a = 1.0 },
                    .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                    .texture = white_texture,
                    .sampler = sampler,
                }) catch null;
                if (material) |mat| {
                    ctx.world.add("material", ico, mat, null) catch {};
                }

                const rand_rot_x = rand.float(f32) * 2.0 * std.math.pi;
                const rand_rot_y = rand.float(f32) * 2.0 * std.math.pi;
                const rand_rot_z = rand.float(f32) * 2.0 * std.math.pi;

                ctx.world.add("transform", ico, .{
                    .position = .{
                        @as(f32, @floatFromInt(i)) * 2.0,
                        @as(f32, @floatFromInt(j)) * 2.0,
                        @as(f32, @floatFromInt(k)) * 2.0,
                    },
                    .rotation = palladia.math.quatFromEuler(.{ rand_rot_x, rand_rot_y, rand_rot_z }),
                    .scale = .{ 1, 1, 1 },
                }, null) catch {};

                spawned += 1;
            }
        }
        std.log.info("spawned {} icos", .{spawned});
    }

    var ambient_ctx = palladia.systems.RenderSystem.getAmbientLightContextWithDevice(device);
    const ambient_light = ctx.world.createEntity();
    ctx.world.add("transform", ambient_light, .{
        .position = .{ 0, 0, 0 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("ambient_light", ambient_light, .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 0.1 },
    }, &ambient_ctx) catch {};

    var point_ctx = palladia.systems.RenderSystem.getPointLightContextWithDevice(device);
    for (0..4) |_| {
        const point_light = ctx.world.createEntity();

        const px: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;
        const py: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;
        const pz: i32 = @as(i32, @intCast(rand.int(u32) % 101)) - 50;

        ctx.world.add("transform", point_light, .{
            .position = .{
                @as(f32, @floatFromInt(px * 2 + 1)),
                @as(f32, @floatFromInt(py * 2 + 1)),
                @as(f32, @floatFromInt(pz * 2 + 1)),
            },
            .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
            .scale = .{ 1, 1, 1 },
        }, null) catch {};
        ctx.world.add("point_light", point_light, .{
            .color = .{ .r = 1, .g = 1, .b = 1, .a = 1.0 },
        }, &point_ctx) catch {};
    }

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
