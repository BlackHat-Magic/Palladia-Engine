const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
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

pub fn createTetrahedron(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
    },
) !MeshComponent {
    const num_vertices: u32 = 4;
    var vertices: [4]Vertex = undefined;

    const raw_vertices = [4]Vec3{
        .{ 1, 1, 1 },
        .{ 1, -1, -1 },
        .{ -1, 1, -1 },
        .{ -1, -1, 1 },
    };

    for (0..4) |i| {
        const pos = normalize(raw_vertices[i]);
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

    const num_indices: u32 = 12;
    const indices = [_]u32{
        0, 1, 2,
        0, 3, 1,
        0, 2, 3,
        1, 3, 2,
    };

    const vbo = try uploadVertices(device, &vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, &indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = num_vertices,
        .index_buffer = ibo,
        .num_indices = num_indices,
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
