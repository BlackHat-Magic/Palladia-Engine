const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;
const Vec2 = [2]f32;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
const Vertex = common.Vertex;

pub fn createCylinder(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius_top: f32 = 1.0,
        radius_bottom: f32 = 1.0,
        height: f32 = 1.0,
        radial_segments: u32 = 16,
        height_segments: u32 = 1,
        open_ended: bool = false,
        theta_start: f32 = 0.0,
        theta_length: f32 = std.math.pi * 2.0,
    },
) !MeshComponent {
    if (args.radial_segments < 3 or args.height_segments < 1) return error.InvalidSegments;

    const num_points = args.height_segments + 1 + (if (!args.open_ended) @as(u32, 2) else 0);

    var points = try std.heap.page_allocator.alloc(Vec2, num_points);
    defer std.heap.page_allocator.free(points);

    const half_height = args.height / 2.0;
    var idx: u32 = 0;

    if (!args.open_ended) {
        points[idx] = .{ 0, -half_height };
        idx += 1;
    }

    points[idx] = .{ args.radius_bottom, -half_height };
    idx += 1;

    for (1..args.height_segments) |i| {
        const frac = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(args.height_segments));
        points[idx] = .{
            args.radius_bottom + frac * (args.radius_top - args.radius_bottom),
            -half_height + frac * args.height,
        };
        idx += 1;
    }

    points[idx] = .{ args.radius_top, half_height };
    idx += 1;

    if (!args.open_ended) {
        points[idx] = .{ 0, half_height };
    }

    const lathe = @import("lathe.zig").createLathe;
    return lathe(device, .{
        .path = points[0..@intCast(if (!args.open_ended) idx + 1 else idx)],
        .segments = args.radial_segments,
        .phi_start = args.theta_start,
        .phi_length = args.theta_length,
    });
}
