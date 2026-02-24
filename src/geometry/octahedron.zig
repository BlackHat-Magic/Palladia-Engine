const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const Vertex = common.Vertex;

const Vec3 = [3]f32;

fn normalize(v: Vec3) Vec3 {
    const len = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len > 0) {
        const inv = 1.0 / len;
        return .{ v[0] * inv, v[1] * inv, v[2] * inv };
    }
    return v;
}

pub fn createOctahedron(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
    },
) !MeshComponent {
    const num_vertices: u32 = 6;
    var vertices: [6]Vertex = undefined;

    const raw_positions = [6]Vec3{
        .{ 0, 1, 0 },
        .{ 1, 0, 0 },
        .{ 0, 0, 1 },
        .{ -1, 0, 0 },
        .{ 0, 0, -1 },
        .{ 0, -1, 0 },
    };

    for (0..6) |i| {
        const pos = normalize(raw_positions[i]);
        const scaled_pos: Vec3 = .{ pos[0] * args.radius, pos[1] * args.radius, pos[2] * args.radius };
        const norm_pos = normalize(scaled_pos);

        const u = 0.5 + std.math.atan2(norm_pos[2], norm_pos[0]) / (2.0 * std.math.pi);
        const v = std.math.acos(norm_pos[1]) / std.math.pi;

        vertices[i] = .{
            .pos = scaled_pos,
            .normal = norm_pos,
            .uv = .{ u, v },
        };
    }

    const indices = [_]u32{
        0, 2, 1,
        0, 3, 2,
        0, 4, 3,
        0, 1, 4,
        5, 2, 4,
        5, 4, 1,
        5, 1, 2,
        5, 3, 4,
    };

    const vbo = try uploadVertices(device, &vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, &indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = num_vertices,
        .index_buffer = ibo,
        .num_indices = @as(u32, indices.len),
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
