const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
const Vertex = common.Vertex;

pub fn createCircle(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
        segments: u32 = 32,
    },
) !MeshComponent {
    if (args.segments < 3) return error.InvalidSegments;

    const num_vertices = args.segments + 1;
    const num_indices = args.segments * 3;

    var vertices = try std.heap.page_allocator.alloc(Vertex, num_vertices);
    defer std.heap.page_allocator.free(vertices);

    var indices = try std.heap.page_allocator.alloc(u32, num_indices);
    defer std.heap.page_allocator.free(indices);

    // Center vertex
    vertices[0] = .{
        .pos = .{ 0, 0, 0 },
        .normal = .{ 0, 0, 1 },
        .uv = .{ 0.5, 0.5 },
    };

    // Ring vertices
    for (0..args.segments) |i| {
        const theta = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(args.segments)) * 2.0 * std.math.pi;
        const cos_theta = @cos(theta);
        const sin_theta = @sin(theta);

        vertices[i + 1] = .{
            .pos = .{ args.radius * cos_theta, args.radius * sin_theta, 0 },
            .normal = .{ 0, 0, 1 },
            .uv = .{ 0.5 + 0.5 * cos_theta, 0.5 + 0.5 * sin_theta },
        };
    }

    // Indices
    var index_idx: usize = 0;
    for (0..args.segments) |i| {
        indices[index_idx] = 0;
        indices[index_idx + 1] = @intCast(i + 1);
        indices[index_idx + 2] = @intCast((i + 1) % args.segments + 1);
        index_idx += 3;
    }

    const vbo = try uploadVertices(device, vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = @intCast(num_vertices),
        .index_buffer = ibo,
        .num_indices = @intCast(num_indices),
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
