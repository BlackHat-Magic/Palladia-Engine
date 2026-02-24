const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const createCylinder = @import("cylinder.zig").createCylinder;

pub fn createCone(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
        height: f32 = 1.0,
        radial_segments: u32 = 16,
        height_segments: u32 = 1,
        open_ended: bool = false,
        theta_start: f32 = 0.0,
        theta_length: f32 = std.math.pi * 2.0,
    },
) !MeshComponent {
    return createCylinder(device, .{
        .radius_top = 0.0,
        .radius_bottom = args.radius,
        .height = args.height,
        .radial_segments = args.radial_segments,
        .height_segments = args.height_segments,
        .open_ended = args.open_ended,
        .theta_start = args.theta_start,
        .theta_length = args.theta_length,
    });
}
