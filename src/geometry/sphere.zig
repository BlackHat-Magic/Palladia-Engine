const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const createLathe = @import("lathe.zig").createLathe;

pub fn createSphere(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
        width_segments: u32 = 32,
        height_segments: u32 = 16,
        phi_start: f32 = 0.0,
        phi_length: f32 = std.math.pi * 2.0,
        theta_start: f32 = 0.0,
        theta_length: f32 = std.math.pi,
    },
) !MeshComponent {
    if (args.width_segments < 3 or args.height_segments < 2) {
        return error.InvalidSegments;
    }

    const num_points = args.height_segments + 1;
    var points = try std.heap.page_allocator.alloc([2]f32, num_points);
    defer std.heap.page_allocator.free(points);

    for (0..num_points) |i| {
        const frac = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(args.height_segments));
        const theta = args.theta_start + (1.0 - frac) * args.theta_length;
        points[i] = .{ args.radius * @sin(theta), args.radius * @cos(theta) };
    }

    return createLathe(device, .{
        .path = points,
        .segments = args.width_segments,
        .phi_start = args.phi_start,
        .phi_length = args.phi_length,
    });
}
