const std = @import("std");
const sdl = @import("../sdl.zig").c;

pub fn loadShader(
    device: *sdl.SDL_GPUDevice,
    filename: [:0]const u8,
    stage: sdl.SDL_GPUShaderStage,
    comptime args: struct {
        sampler_count: u32 = 0,
        uniform_buffer_count: u32 = 0,
        storage_buffer_count: u32 = 0,
        storage_texture_count: u32 = 0,
    },
) !*sdl.SDL_GPUShader {
    const path_info = sdl.SDL_GetPathInfo(filename, null);
    if (path_info == false) {
        std.log.err("Couldn't read file {s}: {s}\n", .{ filename, sdl.SDL_GetError() });
        return error.FileNotFound;
    }

    var code_size: u64 = 0;
    const code = sdl.SDL_LoadFile(filename, &code_size);
    if (code == null) {
        std.log.err("Couldn't read file {s}: {s}\n", .{ filename, sdl.SDL_GetError() });
        return error.FileReadFailed;
    }
    defer sdl.SDL_free(code);

    const shader_info = sdl.SDL_GPUShaderCreateInfo{
        .code = code,
        .code_size = code_size,
        .entrypoint = "main",
        .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = stage,
        .num_samplers = args.sampler_count,
        .num_uniform_buffers = args.uniform_buffer_count,
        .num_storage_buffers = args.storage_buffer_count,
        .num_storage_textures = args.storage_texture_count,
    };

    const shader = sdl.SDL_CreateGPUShader(device, &shader_info);
    if (shader == null) {
        std.log.err("Couldn't create GPU Shader: {s}\n", .{sdl.SDL_GetError()});
        return error.ShaderCreateFailed;
    }

    return shader;
}

pub fn loadTexture(device: *sdl.SDL_GPUDevice, file_path: [:0]const u8) !*sdl.SDL_GPUTexture {
    const surface = sdl.IMG_Load(file_path);
    if (surface == null) {
        std.log.err("Failed to load texture: {s}\n", .{sdl.SDL_GetError()});
        return error.TextureLoadFailed;
    }
    defer sdl.SDL_DestroySurface(surface);

    const abgr_surface = sdl.SDL_ConvertSurface(surface, sdl.SDL_PIXELFORMAT_ABGR8888);
    defer sdl.SDL_DestroySurface(abgr_surface);

    if (abgr_surface == null) {
        std.log.err("Failed to convert surface format: {s}\n", .{sdl.SDL_GetError()});
        return error.SurfaceConvertFailed;
    }

    const tex_create_info = sdl.SDL_GPUTextureCreateInfo{
        .type = sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .width = @intCast(abgr_surface.*.w),
        .height = @intCast(abgr_surface.*.h),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .props = 0,
    };

    const texture = sdl.SDL_CreateGPUTexture(device, &tex_create_info);
    if (texture == null) {
        std.log.err("Failed to create texture: {s}\n", .{sdl.SDL_GetError()});
        return error.TextureCreateFailed;
    }

    const transfer_info = sdl.SDL_GPUTransferBufferCreateInfo{
        .size = @intCast(abgr_surface.*.pitch * abgr_surface.*.h),
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .props = 0,
    };

    const transfer_buf = sdl.SDL_CreateGPUTransferBuffer(device, &transfer_info);
    if (transfer_buf == null) {
        std.log.err("Failed to create transfer buffer: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTexture(device, texture.?);
        return error.TransferBufferFailed;
    }

    const data_ptr = sdl.SDL_MapGPUTransferBuffer(device, transfer_buf, false);
    if (data_ptr == null) {
        std.log.err("Failed to map transfer buffer: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);
        sdl.SDL_ReleaseGPUTexture(device, texture.?);
        return error.MapFailed;
    }

    @memcpy(@as([*]u8, @ptrCast(data_ptr))[0..transfer_info.size], @as([*]const u8, @ptrCast(abgr_surface.*.pixels))[0..transfer_info.size]);
    sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buf);

    const upload_cmd = sdl.SDL_AcquireGPUCommandBuffer(device);
    if (upload_cmd == null) {
        std.log.err("Failed to acquire GPU command buffer: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);
        sdl.SDL_ReleaseGPUTexture(device, texture.?);
        return error.CommandBufferFailed;
    }

    const copy_pass = sdl.SDL_BeginGPUCopyPass(upload_cmd);
    if (copy_pass == null) {
        std.log.err("Failed to begin GPU copy pass: {s}\n", .{sdl.SDL_GetError()});
        _ = sdl.SDL_SubmitGPUCommandBuffer(upload_cmd);
        sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);
        sdl.SDL_ReleaseGPUTexture(device, texture.?);
        return error.CopyPassFailed;
    }

    const src_info = sdl.SDL_GPUTextureTransferInfo{
        .transfer_buffer = transfer_buf,
        .offset = 0,
        .pixels_per_row = @intCast(abgr_surface.*.w),
        .rows_per_layer = @intCast(abgr_surface.*.h),
    };

    const dst_region = sdl.SDL_GPUTextureRegion{
        .texture = texture.?,
        .w = @intCast(abgr_surface.*.w),
        .h = @intCast(abgr_surface.*.h),
        .d = 1,
        .x = 0,
        .y = 0,
        .z = 0,
    };

    sdl.SDL_UploadToGPUTexture(copy_pass, &src_info, &dst_region, false);
    sdl.SDL_EndGPUCopyPass(copy_pass);
    _ = sdl.SDL_SubmitGPUCommandBuffer(upload_cmd);
    sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);

    return texture.?;
}

pub fn createWhiteTexture(device: *sdl.SDL_GPUDevice) !*sdl.SDL_GPUTexture {
    const tex_info = sdl.SDL_GPUTextureCreateInfo{
        .type = sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .width = 1,
        .height = 1,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .props = 0,
    };

    const tex = sdl.SDL_CreateGPUTexture(device, &tex_info);
    if (tex == null) {
        std.log.err("Failed to create white texture: {s}\n", .{sdl.SDL_GetError()});
        return error.TextureCreateFailed;
    }

    const pixel = [_]u8{ 255, 255, 255, 255 };

    const tinfo = sdl.SDL_GPUTransferBufferCreateInfo{
        .size = 4,
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .props = 0,
    };

    const trans = sdl.SDL_CreateGPUTransferBuffer(device, &tinfo);
    if (trans == null) {
        std.log.err("Failed to create transfer buffer for white texture: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTexture(device, tex.?);
        return error.TransferBufferFailed;
    }

    const data = sdl.SDL_MapGPUTransferBuffer(device, trans, false);
    if (data == null) {
        std.log.err("Failed to map transfer buffer for white texture: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTransferBuffer(device, trans);
        sdl.SDL_ReleaseGPUTexture(device, tex.?);
        return error.MapFailed;
    }

    @memcpy(@as([*]u8, @ptrCast(data))[0..4], &pixel);
    sdl.SDL_UnmapGPUTransferBuffer(device, trans);

    const cmd = sdl.SDL_AcquireGPUCommandBuffer(device);
    if (cmd == null) {
        std.log.err("Failed to acquire command buffer for white texture: {s}\n", .{sdl.SDL_GetError()});
        sdl.SDL_ReleaseGPUTransferBuffer(device, trans);
        sdl.SDL_ReleaseGPUTexture(device, tex.?);
        return error.CommandBufferFailed;
    }

    const copy = sdl.SDL_BeginGPUCopyPass(cmd);
    if (copy == null) {
        std.log.err("Failed to begin copy pass for white texture: {s}\n", .{sdl.SDL_GetError()});
        _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
        sdl.SDL_ReleaseGPUTransferBuffer(device, trans);
        sdl.SDL_ReleaseGPUTexture(device, tex.?);
        return error.CopyPassFailed;
    }

    const src = sdl.SDL_GPUTextureTransferInfo{
        .transfer_buffer = trans,
        .offset = 0,
        .pixels_per_row = 1,
        .rows_per_layer = 1,
    };

    const dst = sdl.SDL_GPUTextureRegion{
        .texture = tex.?,
        .w = 1,
        .h = 1,
        .d = 1,
        .x = 0,
        .y = 0,
        .z = 0,
    };

    sdl.SDL_UploadToGPUTexture(copy, &src, &dst, false);
    sdl.SDL_EndGPUCopyPass(copy);
    _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
    sdl.SDL_ReleaseGPUTransferBuffer(device, trans);

    return tex.?;
}
