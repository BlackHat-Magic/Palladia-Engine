const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;

const common = @import("common.zig");
const uploadVertices = common.uploadVertices;
const uploadIndices = common.uploadIndices;
const computeNormals = common.computeNormals;
const Vertex = common.Vertex;

pub fn createBox(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        width: f32 = 1.0,
        height: f32 = 1.0,
        depth: f32 = 1.0,
    },
) !MeshComponent {
    const wx = args.width / 2.0;
    const hy = args.height / 2.0;
    const lz = args.depth / 2.0;

    var vertices: [24]Vertex = undefined;

    inline for ([_]struct { f32, f32, f32, f32, f32, f32, f32, f32 }{
        .{ -wx, -hy, -lz, 0, 0, 0, 0, 1 },
        .{ wx, -hy, -lz, 0, 0, 0, 1, 1 },
        .{ wx, hy, -lz, 0, 0, 0, 1, 0 },
        .{ -wx, hy, -lz, 0, 0, 0, 0, 0 },

        .{ -wx, -hy, lz, 0, 0, 0, 0, 1 },
        .{ wx, -hy, lz, 0, 0, 0, 1, 1 },
        .{ wx, hy, lz, 0, 0, 0, 1, 0 },
        .{ -wx, hy, lz, 0, 0, 0, 0, 0 },

        .{ -wx, hy, -lz, 0, 0, 0, 1, 0 },
        .{ -wx, hy, lz, 0, 0, 0, 1, 1 },
        .{ -wx, -hy, lz, 0, 0, 0, 0, 1 },
        .{ -wx, -hy, -lz, 0, 0, 0, 0, 0 },

        .{ wx, hy, -lz, 0, 0, 0, 1, 1 },
        .{ wx, -hy, -lz, 0, 0, 0, 0, 1 },
        .{ wx, -hy, lz, 0, 0, 0, 0, 0 },
        .{ wx, hy, lz, 0, 0, 0, 1, 0 },

        .{ -wx, hy, -lz, 0, 0, 0, 0, 0 },
        .{ wx, hy, -lz, 0, 0, 0, 1, 0 },
        .{ wx, hy, lz, 0, 0, 0, 1, 1 },
        .{ -wx, hy, lz, 0, 0, 0, 0, 1 },

        .{ -wx, -hy, -lz, 0, 0, 0, 0, 1 },
        .{ -wx, -hy, lz, 0, 0, 0, 0, 0 },
        .{ wx, -hy, lz, 0, 0, 0, 1, 0 },
        .{ wx, -hy, -lz, 0, 0, 0, 1, 1 },
    }, 0..) |v, i| {
        vertices[i] = .{
            .pos = .{ v[0], v[1], v[2] },
            .normal = .{ v[3], v[4], v[5] },
            .uv = .{ v[6], v[7] },
        };
    }

    const indices = [_]u32{
        0,  2,  1,  2,  0,  3,
        4,  5,  6,  6,  7,  4,
        9,  8,  11, 11, 10, 9,
        15, 13, 12, 13, 15, 14,
        16, 18, 17, 18, 16, 19,
        20, 23, 22, 22, 21, 20,
    };

    computeNormals(&vertices, &indices);

    const vbo = try uploadVertices(device, &vertices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, vbo);

    const ibo = try uploadIndices(device, &indices);
    errdefer sdl.SDL_ReleaseGPUBuffer(device, ibo);

    return .{
        .vertex_buffer = vbo,
        .num_vertices = 24,
        .index_buffer = ibo,
        .num_indices = 36,
        .index_size = sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT,
    };
}
