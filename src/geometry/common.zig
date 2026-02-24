const std = @import("std");
const sdl = @import("../sdl.zig").c;

pub const Vertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
};

pub fn uploadVertices(device: *sdl.SDL_GPUDevice, vertices: []const Vertex) !*sdl.SDL_GPUBuffer {
    const buffer_size = @sizeOf(Vertex) * vertices.len;

    const transfer_info = sdl.SDL_GPUTransferBufferCreateInfo{
        .size = buffer_size,
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
    };

    const transfer_buf = sdl.SDL_CreateGPUTransferBuffer(device, &transfer_info) orelse return error.TransferBufferFailed;
    defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);

    const data = sdl.SDL_MapGPUTransferBuffer(device, transfer_buf, false) orelse {
        sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);
        return error.MapFailed;
    };

    @memcpy(@as([*]u8, @ptrCast(data))[0..buffer_size], std.mem.asBytes(vertices));
    sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buf);

    const buffer_info = sdl.SDL_GPUBufferCreateInfo{
        .size = buffer_size,
        .usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
    };

    const buffer = sdl.SDL_CreateGPUBuffer(device, &buffer_info) orelse return error.BufferCreateFailed;

    const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        sdl.SDL_ReleaseGPUBuffer(device, buffer);
        return error.CommandBufferFailed;
    };

    const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse {
        sdl.SDL_SubmitGPUCommandBuffer(cmd);
        sdl.SDL_ReleaseGPUBuffer(device, buffer);
        return error.CopyPassFailed;
    };

    sdl.SDL_UploadToGPUBuffer(copy_pass, &.{
        .transfer_buffer = transfer_buf,
        .offset = 0,
    }, &.{
        .buffer = buffer,
        .offset = 0,
        .size = buffer_size,
    }, false);

    sdl.SDL_EndGPUCopyPass(copy_pass);
    sdl.SDL_SubmitGPUCommandBuffer(cmd);

    return buffer;
}

pub fn uploadIndices(device: *sdl.SDL_GPUDevice, indices: []const u32) !*sdl.SDL_GPUBuffer {
    const buffer_size = @sizeOf(u32) * indices.len;

    const transfer_info = sdl.SDL_GPUTransferBufferCreateInfo{
        .size = buffer_size,
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
    };

    const transfer_buf = sdl.SDL_CreateGPUTransferBuffer(device, &transfer_info) orelse return error.TransferBufferFailed;
    defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);

    const data = sdl.SDL_MapGPUTransferBuffer(device, transfer_buf, false) orelse {
        sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);
        return error.MapFailed;
    };

    @memcpy(@as([*]u8, @ptrCast(data))[0..buffer_size], std.mem.asBytes(indices));
    sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buf);

    const buffer_info = sdl.SDL_GPUBufferCreateInfo{
        .size = buffer_size,
        .usage = sdl.SDL_GPU_BUFFERUSAGE_INDEX,
    };

    const buffer = sdl.SDL_CreateGPUBuffer(device, &buffer_info) orelse return error.BufferCreateFailed;

    const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        sdl.SDL_ReleaseGPUBuffer(device, buffer);
        return error.CommandBufferFailed;
    };

    const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse {
        sdl.SDL_SubmitGPUCommandBuffer(cmd);
        sdl.SDL_ReleaseGPUBuffer(device, buffer);
        return error.CopyPassFailed;
    };

    sdl.SDL_UploadToGPUBuffer(copy_pass, &.{
        .transfer_buffer = transfer_buf,
        .offset = 0,
    }, &.{
        .buffer = buffer,
        .offset = 0,
        .size = buffer_size,
    }, false);

    sdl.SDL_EndGPUCopyPass(copy_pass);
    sdl.SDL_SubmitGPUCommandBuffer(cmd);

    return buffer;
}

pub fn computeNormals(vertices: []Vertex, indices: []const u32) void {
    for (vertices) |*v| {
        v.normal = .{ 0, 0, 0 };
    }

    var i: usize = 0;
    while (i < indices.len) : (i += 3) {
        const a = indices[i];
        const b = indices[i + 1];
        const c = indices[i + 2];

        const pos_a = vertices[a].pos;
        const pos_b = vertices[b].pos;
        const pos_c = vertices[c].pos;

        const edge1 = [_]f32{ pos_b[0] - pos_a[0], pos_b[1] - pos_a[1], pos_b[2] - pos_a[2] };
        const edge2 = [_]f32{ pos_c[0] - pos_a[0], pos_c[1] - pos_a[1], pos_c[2] - pos_a[2] };

        const normal = [_]f32{
            edge1[1] * edge2[2] - edge1[2] * edge2[1],
            edge1[2] * edge2[0] - edge1[0] * edge2[2],
            edge1[0] * edge2[1] - edge1[1] * edge2[0],
        };

        var len = std.math.sqrt(normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]);
        if (len > 0) {
            len = 1.0 / len;
        }

        vertices[a].normal[0] += normal[0] * len;
        vertices[a].normal[1] += normal[1] * len;
        vertices[a].normal[2] += normal[2] * len;

        vertices[b].normal[0] += normal[0] * len;
        vertices[b].normal[1] += normal[1] * len;
        vertices[b].normal[2] += normal[2] * len;

        vertices[c].normal[0] += normal[0] * len;
        vertices[c].normal[1] += normal[1] * len;
        vertices[c].normal[2] += normal[2] * len;
    }

    for (vertices) |*v| {
        var len = std.math.sqrt(v.normal[0] * v.normal[0] + v.normal[1] * v.normal[1] + v.normal[2] * v.normal[2]);
        if (len > 0) {
            len = 1.0 / len;
            v.normal[0] *= len;
            v.normal[1] *= len;
            v.normal[2] *= len;
        }
    }
}
