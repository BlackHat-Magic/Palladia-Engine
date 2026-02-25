const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const Vertex = common.Vertex;

pub fn createRing(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        inner_radius: f32 = 0.5,
        outer_radius: f32 = 1.0,
        theta_segments: u32 = 32,
        phi_segments: u32 = 8,
        theta_start: f32 = 0.0,
        theta_length: f32 = std.math.pi * 2.0,
    },
) !MeshComponent {
    if (args.theta_segments < 3 or args.phi_segments < 1) return error.InvalidSegments;
    if (args.inner_radius >= args.outer_radius) return error.InvalidRadii;

    const num_theta = args.theta_segments + 1;
    const num_phi = args.phi_segments + 1;
    const num_vertices = num_theta * num_phi;

    var vertices = try std.heap.page_allocator.alloc(Vertex, num_vertices);
    defer std.heap.page_allocator.free(vertices);

    var indices = try std.heap.page_allocator.alloc(u32, args.theta_segments * args.phi_segments * 6);
    defer std.heap.page_allocator.free(indices);

    var vertex_idx: u32 = 0;
    for (0..num_theta) |i| {
        const theta_frac = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(args.theta_segments));
        const theta = args.theta_start + theta_frac * args.theta_length;
        const cos_theta = @cos(theta);
        const sin_theta = @sin(theta);

        for (0..num_phi) |j| {
            const phi_frac = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(args.phi_segments));
            const radius = args.inner_radius + phi_frac * (args.outer_radius - args.inner_radius);

            const x = radius * cos_theta;
            const y = radius * sin_theta;

            const uv_x = (cos_theta * (radius / args.outer_radius) + 1.0) * 0.5;
            const uv_y = (sin_theta * (radius / args.outer_radius) + 1.0) * 0.5;

            vertices[vertex_idx] = .{
                .pos = .{ x, y, 0 },
                .normal = .{ 0, 0, 1 },
                .uv = .{ uv_x, uv_y },
            };
            vertex_idx += 1;
        }
    }

    var index_idx: usize = 0;
    for (0..args.theta_segments) |i| {
        for (0..args.phi_segments) |j| {
            const a: u32 = @intCast(i * num_phi + j);
            const b: u32 = @intCast(i * num_phi + j + 1);
            const c: u32 = @intCast((i + 1) * num_phi + j + 1);
            const d: u32 = @intCast((i + 1) * num_phi + j);

            indices[index_idx] = a;
            indices[index_idx + 1] = b;
            indices[index_idx + 2] = c;
            indices[index_idx + 3] = a;
            indices[index_idx + 4] = c;
            indices[index_idx + 5] = d;
            index_idx += 6;
        }
    }

    const vbo = try uploadVertices(device, vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = num_vertices,
        .index_buffer = ibo,
        .num_indices = @intCast(args.theta_segments * args.phi_segments * 6),
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
