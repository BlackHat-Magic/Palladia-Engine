const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MaterialComponent = @import("../components/material.zig").MaterialComponent;

const common = @import("common.zig");
const loadShader = common.loadShader;
const loadShaderFromBytes = common.loadShaderFromBytes;
const createWhiteTexture = common.createWhiteTexture;

pub const ui_vert_spv align(4) = @embedFile("../shaders/spirv/ui.vert.spv");
pub const ui_frag_spv align(4) = @embedFile("../shaders/spirv/ui.frag.spv");

pub const UIMaterialArgs = struct {
    texture: ?*sdl.SDL_GPUTexture = null,
    sampler: ?*sdl.SDL_GPUSampler = null,
};

pub fn createUIMaterial(
    device: *sdl.SDL_GPUDevice,
    format: sdl.SDL_GPUTextureFormat,
    args: UIMaterialArgs,
) !MaterialComponent {
    const vertex_shader = try loadShaderFromBytes(
        device,
        ui_vert_spv,
        sdl.SDL_GPU_SHADERSTAGE_VERTEX,
        .{ .sampler_count = 0, .uniform_buffer_count = 0, .storage_buffer_count = 0 },
    );
    errdefer sdl.SDL_ReleaseGPUShader(device, vertex_shader);

    const fragment_shader = try loadShaderFromBytes(
        device,
        ui_frag_spv,
        sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        .{ .sampler_count = 1, .uniform_buffer_count = 0, .storage_buffer_count = 0 },
    );
    errdefer sdl.SDL_ReleaseGPUShader(device, fragment_shader);

    const pipe_info = sdl.SDL_GPUGraphicsPipelineCreateInfo{
        .target_info = .{
            .num_color_targets = 1,
            .color_target_descriptions = &[_]sdl.SDL_GPUColorTargetDescription{.{
                .format = format,
                .blend_state = .{
                    .enable_blend = true,
                    .src_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
                    .dst_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                    .color_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
                    .src_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
                    .dst_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                    .alpha_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
                    .color_write_mask = 0xF,
                    .enable_color_write_mask = true,
                },
            }},
            .has_depth_stencil_target = false,
        },
        .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &[_]sdl.SDL_GPUVertexBufferDescription{.{
                .slot = 0,
                .pitch = @sizeOf(UIVertex),
                .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                .instance_step_rate = 0,
            }},
            .num_vertex_buffers = 1,
            .num_vertex_attributes = 4,
            .vertex_attributes = &[_]sdl.SDL_GPUVertexAttribute{
                .{ .location = 0, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(UIVertex, "position") },
                .{ .location = 1, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(UIVertex, "res") },
                .{ .location = 2, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = @offsetOf(UIVertex, "color") },
                .{ .location = 3, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = @offsetOf(UIVertex, "uv") },
            },
        },
        .rasterizer_state = .{
            .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = sdl.SDL_GPU_CULLMODE_NONE,
            .front_face = sdl.SDL_GPU_FRONTFACE_CLOCKWISE,
        },
        .multisample_state = .{
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
            .enable_mask = false,
        },
    };

    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(device, &pipe_info);
    if (pipeline == null) {
        return error.PipelineCreateFailed;
    }

    const white_tex = try createWhiteTexture(device);
    errdefer sdl.SDL_ReleaseGPUTexture(device, white_tex);

    return .{
        .color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        .texture = args.texture orelse white_tex,
        .sampler = args.sampler,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .pipeline = pipeline.?,
    };
}

pub const UIVertex = extern struct {
    position: [2]f32,
    res: [2]f32,
    color: [4]f32,
    uv: [2]f32,
};
