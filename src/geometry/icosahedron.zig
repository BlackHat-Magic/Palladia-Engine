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

pub fn createIcosahedron(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
    },
) !MeshComponent {
    const num_vertices: u32 = 12;
    var vertices: [12]Vertex = undefined;

    const t = (1.0 + @sqrt(5.0)) / 2.0;
    const raw_positions = [12]Vec3{
        .{ -1, t, 0 },
        .{ 1, t, 0 },
        .{ -1, -t, 0 },
        .{ 1, -t, 0 },
        .{ 0, -1, t },
        .{ 0, 1, t },
        .{ 0, -1, -t },
        .{ 0, 1, -t },
        .{ t, 0, -1 },
        .{ t, 0, 1 },
        .{ -t, 0, -1 },
        .{ -t, 0, 1 },
    };

    for (0..12) |i| {
        const pos = normalize(raw_positions[i]);
        const scaled_pos: Vec3 = .{ pos[0] * args.radius, pos[1] * args.radius, pos[2] * args.radius };

        const u = 0.5 + std.math.atan2(scaled_pos[2], scaled_pos[0]) / (2.0 * std.math.pi);
        const v = std.math.acos(scaled_pos[1]) / std.math.pi;

        vertices[i] = .{
            .pos = scaled_pos,
            .normal = .{ 0, 0, 0 },
            .uv = .{ u, v },
        };
    }

    const indices = [_]u32{
        0,  5,  1,  0, 1, 7,  0, 7,  10, 0,  10, 11,
        0,  11, 5,  1, 5, 9,  5, 11, 4,  11, 10, 2,
        10, 7,  6,  7, 1, 8,  3, 9,  4,  3,  4,  2,
        3,  2,  6,  3, 6, 8,  3, 8,  9,  4,  9,  5,
        2,  4,  11, 6, 2, 10, 8, 6,  7,  9,  8,  1,
    };

    common.computeNormals(&vertices, &indices);

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
