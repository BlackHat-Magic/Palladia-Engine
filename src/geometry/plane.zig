const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
const Vertex = common.Vertex;

pub fn createPlane(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        width: f32 = 1.0,
        height: f32 = 1.0,
        width_segments: u32 = 1,
        height_segments: u32 = 1,
    },
) !MeshComponent {
    const width_segments = if (args.width_segments < 1) @as(u32, 1) else args.width_segments;
    const height_segments = if (args.height_segments < 1) @as(u32, 1) else args.height_segments;

    const num_vertices = (width_segments + 1) * (height_segments + 1);
    const num_indices = width_segments * height_segments * 6;

    var vertices = try std.heap.page_allocator.alloc(Vertex, num_vertices);
    defer std.heap.page_allocator.free(vertices);

    var indices = try std.heap.page_allocator.alloc(u32, num_indices);
    defer std.heap.page_allocator.free(indices);

    const half_width = args.width / 2.0;
    const half_height = args.height / 2.0;
    var vertex_idx: u32 = 0;

    for (0..height_segments + 1) |iy| {
        const v = @as(f32, @floatFromInt(iy)) / @as(f32, @floatFromInt(height_segments));
        const y_pos = -half_height + args.height * v;

        for (0..width_segments + 1) |ix| {
            const u = @as(f32, @floatFromInt(ix)) / @as(f32, @floatFromInt(width_segments));
            const x_pos = -half_width + args.width * u;

            vertices[vertex_idx] = .{
                .pos = .{ x_pos, y_pos, 0 },
                .normal = .{ 0, 0, 1 },
                .uv = .{ u, 1.0 - v },
            };
            vertex_idx += 1;
        }
    }

    var index_idx: usize = 0;
    for (0..height_segments) |iy| {
        for (0..width_segments) |ix| {
            const a: u32 = @intCast(iy * (width_segments + 1) + ix);
            const b: u32 = @intCast(iy * (width_segments + 1) + ix + 1);
            const c: u32 = @intCast((iy + 1) * (width_segments + 1) + ix + 1);
            const d: u32 = @intCast((iy + 1) * (width_segments + 1) + ix);

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
        .num_indices = num_indices,
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
