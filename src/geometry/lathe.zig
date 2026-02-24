const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;
const Vec2 = [2]f32;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
const Vertex = common.Vertex;

pub fn createLathe(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        path: []const Vec2,
        segments: u32,
        phi_start: f32 = 0.0,
        phi_length: f32 = std.math.pi * 2.0,
    },
) !MeshComponent {
    if (args.path.len < 2) return error.InvalidPath;
    if (args.segments < 3) return error.InvalidSegments;

    const num_phi = args.segments + 1;
    const num_vertices = @as(u32, @intCast(args.path.len)) * num_phi;
    var vertices = try std.heap.page_allocator.alloc(Vertex, num_vertices);
    defer std.heap.page_allocator.free(vertices);

    var vertex_idx: u32 = 0;
    for (args.path, 0..) |point, i| {
        const u = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(args.path.len - 1));

        for (0..num_phi) |j| {
            const phi_frac = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(args.segments));
            const phi = args.phi_start + phi_frac * args.phi_length;
            const cos_phi = @cos(phi);
            const sin_phi = @sin(phi);

            const x = point[0] * cos_phi;
            const y = point[1];
            const z = point[0] * sin_phi;

            const v = phi_frac;

            vertices[vertex_idx] = .{
                .pos = .{ x, y, z },
                .normal = .{ 0, 0, 0 },
                .uv = .{ v, u },
            };
            vertex_idx += 1;
        }
    }

    const num_indices = @as(u32, @intCast(args.path.len - 1)) * args.segments * 6;
    var indices = try std.heap.page_allocator.alloc(u32, num_indices);
    defer std.heap.page_allocator.free(indices);

    var index_idx: u32 = 0;
    for (0..args.path.len - 1) |i| {
        for (0..args.segments) |j| {
            const a = @as(u32, @intCast(i * @as(usize, num_phi) + j));
            const b = @as(u32, @intCast(i * @as(usize, num_phi) + (j + 1) % args.segments));
            const c = @as(u32, @intCast((i + 1) * @as(usize, num_phi) + (j + 1) % args.segments));
            const d = @as(u32, @intCast((i + 1) * @as(usize, num_phi) + j));

            indices[index_idx] = a;
            indices[index_idx + 1] = c;
            indices[index_idx + 2] = b;
            indices[index_idx + 3] = a;
            indices[index_idx + 4] = d;
            indices[index_idx + 5] = c;
            index_idx += 6;
        }
    }

    computeNormals(vertices, indices);

    const vbo = try uploadVertices(device, vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = num_vertices,
        .index_buffer = ibo,
        .num_indices = num_indices,
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
