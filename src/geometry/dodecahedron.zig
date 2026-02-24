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

pub fn createDodecahedron(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
    },
) !MeshComponent {
    const phi = (1.0 + @sqrt(5.0)) / 2.0;
    const phi_inv = 1.0 / phi;

    const raw_vertices_flat = [_]f32{ 1, 1, 1, 1, 1, -1, 1, -1, 1, 1, -1, -1, -1, 1, 1, -1, 1, -1, -1, -1, 1, -1, -1, -1, phi_inv, phi, 0, -phi_inv, phi, 0, phi_inv, -phi, 0, -phi_inv, -phi, 0, phi, 0, phi_inv, phi, 0, -phi_inv, -phi, 0, phi_inv, -phi, 0, -phi_inv, 0, phi_inv, phi, 0, -phi_inv, phi, 0, phi_inv, -phi, 0, -phi_inv, -phi };

    const num_vertices: u32 = 20;
    var vertices: [20]Vertex = undefined;

    for (0..20) |i| {
        const raw_pos: Vec3 = .{ raw_vertices_flat[i * 3], raw_vertices_flat[i * 3 + 1], raw_vertices_flat[i * 3 + 2] };
        const scaled_pos: Vec3 = .{ raw_pos[0] * args.radius, raw_pos[1] * args.radius, raw_pos[2] * args.radius };
        const norm_pos = normalize(scaled_pos);

        const u = 0.5 + std.math.atan2(norm_pos[2], norm_pos[0]) / (2.0 * std.math.pi);
        const v = std.math.acos(norm_pos[1]) / std.math.pi;

        vertices[i] = .{
            .pos = scaled_pos,
            .normal = norm_pos,
            .uv = .{ u, v },
        };
    }

    const indices = [_]u32{ 1, 8, 0, 0, 12, 13, 13, 1, 0, 4, 9, 5, 5, 15, 14, 14, 4, 5, 2, 10, 3, 3, 13, 12, 12, 2, 3, 7, 11, 6, 6, 14, 15, 15, 7, 6, 2, 12, 0, 0, 16, 17, 17, 2, 0, 1, 13, 3, 3, 19, 18, 18, 1, 3, 4, 14, 6, 6, 17, 16, 16, 4, 6, 7, 15, 5, 5, 18, 19, 19, 7, 5, 4, 16, 0, 0, 8, 9, 9, 4, 0, 2, 17, 6, 6, 11, 10, 10, 2, 6, 1, 18, 5, 5, 9, 8, 8, 1, 5, 7, 19, 3, 3, 10, 11, 11, 7, 3 };

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
