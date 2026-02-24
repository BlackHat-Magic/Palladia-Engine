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

fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

pub fn createTorus(
    device: *sdl.SDL_GPUDevice,
    comptime args: struct {
        radius: f32 = 1.0,
        tube_radius: f32 = 0.3,
        radial_segments: u32 = 16,
        tubular_segments: u32 = 32,
        arc: f32 = std.math.pi * 2.0,
    },
) !MeshComponent {
    if (args.radial_segments < 3 or args.tubular_segments < 3) return error.InvalidSegments;
    if (args.tube_radius <= 0.0 or args.radius <= 0.0) return error.InvalidRadius;

    const is_closed = @abs(args.arc - 2.0 * std.math.pi) < 1e-6;
    const num_tubular = args.tubular_segments + (if (is_closed) @as(u32, 0) else 1);
    const num_radial = args.radial_segments;
    const num_vertices = num_tubular * num_radial;

    var vertices = try std.heap.page_allocator.alloc(Vertex, num_vertices);
    defer std.heap.page_allocator.free(vertices);

    const num_indices = args.tubular_segments * args.radial_segments * 6;
    var indices = try std.heap.page_allocator.alloc(u32, num_indices);
    defer std.heap.page_allocator.free(indices);

    var vertex_idx: u32 = 0;
    for (0..num_tubular) |tu| {
        const u = @as(f32, @floatFromInt(tu)) / @as(f32, @floatFromInt(args.tubular_segments)) * args.arc;
        const cos_u = @cos(u);
        const sin_u = @sin(u);

        for (0..num_radial) |ra| {
            const v = @as(f32, @floatFromInt(ra)) / @as(f32, @floatFromInt(args.radial_segments)) * 2.0 * std.math.pi;
            const cos_v = @cos(v);
            const sin_v = @sin(v);

            const x = (args.radius + args.tube_radius * cos_v) * cos_u;
            const y = args.tube_radius * sin_v;
            const z = (args.radius + args.tube_radius * cos_v) * sin_u;

            const tube_center: Vec3 = .{ args.radius * cos_u, 0, args.radius * sin_u };
            const pos: Vec3 = .{ x, y, z };
            const norm = normalize(sub(pos, tube_center));

            const uv_u = @as(f32, @floatFromInt(tu)) / @as(f32, @floatFromInt(args.tubular_segments));
            const uv_v = @as(f32, @floatFromInt(ra)) / @as(f32, @floatFromInt(args.radial_segments));

            vertices[vertex_idx] = .{
                .pos = pos,
                .normal = norm,
                .uv = .{ uv_u, uv_v },
            };
            vertex_idx += 1;
        }
    }

    var index_idx: usize = 0;
    for (0..args.tubular_segments) |tu| {
        var tu1: u32 = tu + 1;
        if (is_closed) {
            tu1 %= args.tubular_segments;
        }

        for (0..args.radial_segments) |ra| {
            const ra1 = (ra + 1) % args.radial_segments;

            const a = tu * num_radial + ra;
            const b = tu1 * num_radial + ra;
            const c = tu1 * num_radial + ra1;
            const d = tu * num_radial + ra1;

            indices[index_idx] = a;
            indices[index_idx + 1] = d;
            indices[index_idx + 2] = b;
            indices[index_idx + 3] = b;
            indices[index_idx + 4] = d;
            indices[index_idx + 5] = c;
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
