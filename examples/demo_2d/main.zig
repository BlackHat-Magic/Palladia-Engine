const std = @import("std");
const palladia = @import("palladia");
const sdl = palladia.sdl;

const Transform = palladia.Transform;
const CameraComponent = palladia.CameraComponent;
const MeshComponent = palladia.MeshComponent;
const MaterialComponent = palladia.MaterialComponent;
const FPSCameraController = palladia.FPSCameraController;
const PointLightComponent = palladia.PointLightComponent;
const AmbientLightComponent = palladia.AmbientLightComponent;
const DrawCanvas = palladia.DrawCanvas;
const DrawRect = palladia.DrawRect;

const Time = palladia.system.Time;
const Input = palladia.system.Input;

const Components = struct {
    transform: Transform,
    camera: CameraComponent,
    mesh: MeshComponent,
    material: MaterialComponent,
    controller: FPSCameraController,
    point_light: PointLightComponent,
    ambient_light: AmbientLightComponent,
    draw_canvas: DrawCanvas,
};

const ResourceDefs = struct {
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    time: *Time,
    input: *Input,
    active_camera: *const palladia.system.ActiveCamera,
    texture_registry: *palladia.TextureRegistry,
    font_registry: *palladia.FontRegistry,
};

const app_config = palladia.app.AppConfig{
    .name = "Palladia Engine - 2D Drawing Demo",
    .version = "0.1.0",
    .identifier = "com.palladia.demo_2d",
    .width = 1280,
    .height = 720,
};

const App = palladia.app.App(palladia.RootPlugin);
const Ctx = App.Context(Components, ResourceDefs);

fn setup(ctx: *Ctx) void {
    const device = ctx.device;
    const font_reg = ctx.resources.getConst("font_registry").?;
    const tex_reg = ctx.resources.getConst("texture_registry").?;

    // Load font
    const font = sdl.TTF_OpenFont("assets/Roboto-Regular.ttf", 48);
    if (font == null) {
        std.debug.print("Failed to load font: {s}\n", .{sdl.SDL_GetError()});
        return;
    }
    const font_id = font_reg.register(ctx.allocator, font.?) catch return;

    // Load sprite texture
    const tex = palladia.material.loadTexture(device, "assets/test.png") catch return;
    const tex_id = tex_reg.register(ctx.allocator, tex) catch return;

    // Camera
    const cam = ctx.world.createEntity();
    ctx.world.add("transform", cam, .{
        .position = .{ 0, 0, -2 },
        .rotation = palladia.math.quatFromEuler(.{ 0, 0, 0 }),
        .scale = .{ 1, 1, 1 },
    }, null) catch {};
    ctx.world.add("camera", cam, .{
        .fov = 70.0,
        .near_clip = 0.01,
        .far_clip = 1000.0,
    }, null) catch {};
    ctx.world.add("controller", cam, .{
        .mouse_sense = 0.01,
        .move_speed = 3.0,
    }, null) catch {};
    ctx.setCamera(cam);
    _ = sdl.SDL_SetWindowRelativeMouseMode(ctx.window, true);

    // -- Canvas 1 (z=0): Background --
    {
        const e = ctx.world.createEntity();
        const canvas = DrawCanvas.init(ctx.allocator);
        ctx.world.add("draw_canvas", e, canvas, null) catch {};
        var dc = ctx.world.get("draw_canvas", e).?;
        dc.setZIndex(0);
        dc.drawRect(0, 0, 1280, 720, .{ 0.05, 0.05, 0.15, 1 }) catch {};
    }

    // -- Canvas 2 (z=1): Solid rects --
    {
        const e = ctx.world.createEntity();
        const canvas = DrawCanvas.init(ctx.allocator);
        ctx.world.add("draw_canvas", e, canvas, null) catch {};
        var dc = ctx.world.get("draw_canvas", e).?;
        dc.setZIndex(1);

        dc.drawRect(50, 50, 200, 120, .{ 0.9, 0.2, 0.2, 1 }) catch {};
        dc.drawRectOpts(300, 50, 200, 120, .{ 0.2, 0.8, 0.2, 0.85 }, DrawRect{ .rotation = 0.4 }) catch {};
        dc.drawRectOpts(550, 50, 200, 120, .{ 0.2, 0.3, 0.9, 0.85 }, DrawRect{ .corner_radius = 20 }) catch {};
        dc.drawRectOpts(800, 50, 200, 120, .{ 0.9, 0.8, 0.1, 0.7 }, DrawRect{ .rotation = -0.3, .corner_radius = 30 }) catch {};
        dc.drawRectOpts(150, 110, 180, 100, .{ 0.7, 0.2, 0.8, 0.5 }, DrawRect{}) catch {};
        dc.drawRectOpts(400, 110, 100, 180, .{ 0.1, 0.7, 0.7, 0.8 }, DrawRect{ .corner_radius = 8, .rotation = 0.1 }) catch {};
    }

    // -- Canvas 3 (z=2): Border-only rects --
    {
        const e = ctx.world.createEntity();
        const canvas = DrawCanvas.init(ctx.allocator);
        ctx.world.add("draw_canvas", e, canvas, null) catch {};
        var dc = ctx.world.get("draw_canvas", e).?;
        dc.setZIndex(2);

        dc.drawRectOpts(50, 250, 200, 120, .{ 1, 1, 1, 1 }, DrawRect{ .filled = false, .border_thickness = 3 }) catch {};
        dc.drawRectOpts(300, 250, 200, 120, .{ 0.3, 1, 0.3, 1 }, DrawRect{ .filled = false, .border_thickness = 4, .rotation = 0.2 }) catch {};
        dc.drawRectOpts(550, 250, 200, 120, .{ 0.1, 0.8, 1, 1 }, DrawRect{ .filled = false, .border_thickness = 5, .corner_radius = 15, .rotation = -0.15 }) catch {};
        dc.drawRectOpts(800, 250, 200, 120, .{ 1, 0.2, 0.2, 1 }, DrawRect{ .filled = false, .border_thickness = 8, .corner_radius = 25 }) catch {};
    }

    // -- Canvas 4 (z=3): Text --
    {
        const e = ctx.world.createEntity();
        const canvas = DrawCanvas.init(ctx.allocator);
        ctx.world.add("draw_canvas", e, canvas, null) catch {};
        var dc = ctx.world.get("draw_canvas", e).?;
        dc.setZIndex(3);

        dc.drawText(50, 420, "Hello, Palladia!", font_id, .{ 1, 0.9, 0.3, 1 }, 48) catch {};
        dc.drawText(50, 480, "2D Drawing Demo", font_id, .{ 0.4, 0.8, 1, 1 }, 36) catch {};
        dc.drawTextRot(50, 530, "Rotated Text", font_id, .{ 0.2, 1, 0.4, 1 }, 32, -0.15) catch {};
        dc.drawText(50, 590, "Rects, Sprites, Text, Rotation, Rounded Corners", font_id, .{ 0.6, 0.6, 0.6, 1 }, 24) catch {};
    }

    // -- Canvas 5 (z=4): Sprites --
    {
        const e = ctx.world.createEntity();
        const canvas = DrawCanvas.init(ctx.allocator);
        ctx.world.add("draw_canvas", e, canvas, null) catch {};
        var dc = ctx.world.get("draw_canvas", e).?;
        dc.setZIndex(4);

        dc.drawSprite(800, 400, 192, 192, tex_id, .{ 0, 0, 1, 1 }, .{ 1, 1, 1, 1 }) catch {};
        dc.drawSpriteOpts(1050, 400, 128, 128, tex_id, .{ 0, 0, 1, 1 }, .{ 0.5, 0.8, 1, 0.9 }, .{ .rotation = 0.6 }) catch {};
        dc.drawSpriteOpts(800, 600, 96, 96, tex_id, .{ 0, 0, 1, 1 }, .{ 1, 0.6, 0.6, 0.85 }, .{ .corner_radius = 12 }) catch {};
    }
}

pub fn main() !void {
    App.runWith(
        .{
            palladia.systems.FPSCameraEventSystem,
            palladia.systems.FPSCameraUpdateSystem,
        },
        app_config,
        Components,
        ResourceDefs,
        setup,
    );
}
