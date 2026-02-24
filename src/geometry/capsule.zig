const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const createLathe = @import("lathe.zig").createLathe;

pub fn createCapsule(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
        height: f32 = 1.0,
        cap_segments: u32 = 8,
        radial_segments: u32 = 16,
    },
) !MeshComponent {
    const cap_segments = if (args.cap_segments < 1) @as(u32, 1) else args.cap_segments;
    const num_points: u32 = (cap_segments + 1) * 2;
    const points_len = if (args.height <= 0.0) num_points - 1 else num_points;

    var points = try std.heap.page_allocator.alloc([2]f32, points_len);
    defer std.heap.page_allocator.free(points);

    const half_height = args.height * 0.5;
    var idx: u32 = 0;

    for (0..cap_segments + 1) |i| {
        const theta = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(cap_segments)) * std.math.pi * 0.5;
        points[idx] = .{ args.radius * @sin(theta), -half_height - args.radius * @cos(theta) };
        idx += 1;
    }

    const top_start = if (args.height <= 0.0) @as(i32, @intCast(cap_segments - 1)) else @as(i32, @intCast(cap_segments));
    var i: i32 = top_start;
    while (i >= 0) : (i -= 1) {
        const theta = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(cap_segments)) * std.math.pi * 0.5;
        points[idx] = .{ args.radius * @sin(theta), half_height + args.radius * @cos(theta) };
        if (i < top_start or args.height > 0.0) {
            idx += 1;
        }
    }

    return createLathe(device, .{
        .path = points[0..@intCast(idx)],
        .segments = args.radial_segments,
    });
}
