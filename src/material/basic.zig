const std = @import("std");
const sdl = @import("../sdl.zig").c;
const MaterialComponent = @import("../components/material.zig").MaterialComponent;

const common = @import("common.zig");
const loadShader = common.loadShader;
const createWhiteTexture = common.createWhiteTexture;

pub fn createBasicMaterial(
    device: *sdl.SDL_GPUDevice,
    format: sdl.SDL_GPUTextureFormat,
    comptime args: struct {
        color: sdl.SDL_FColor = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
        cullmode: sdl.SDL_GPUCullMode = sdl.SDL_GPU_CULLMODE_BACK,
        texture: ?*sdl.SDL_GPUTexture = null,
        sampler: ?*sdl.SDL_GPUSampler = null,
        shader_path: []const u8 = "shaders",
    },
) !MaterialComponent {
    const vertex_shader = try loadShader(
        device,
        try std.fmt.allocPrintZ(std.heap.page_allocator, "{s}/basic_material.vert.spv", .{args.shader_path}),
        sdl.SDL_GPU_SHADERSTAGE_VERTEX,
        .{ .sampler_count = 0, .uniform_buffer_count = 2, .storage_buffer_count = 0 },
    );
    errdefer sdl.SDL_ReleaseGPUShader(device, vertex_shader);

    const fragment_shader = try loadShader(
        device,
        try std.fmt.allocPrintZ(std.heap.page_allocator, "{s}/basic_material.frag.spv", .{args.shader_path}),
        sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        .{ .sampler_count = 1, .uniform_buffer_count = 1, .storage_buffer_count = 2 },
    );
    errdefer sdl.SDL_ReleaseGPUShader(device, fragment_shader);

    const pipe_info = sdl.SDL_GPUGraphicsPipelineCreateInfo{
        .target_info = .{
            .num_color_targets = 1,
            .color_target_descriptions = &[_]sdl.SDL_GPUColorTargetDescription{.{ .format = format }},
            .has_depth_stencil_target = true,
            .depth_stencil_format = sdl.SDL_GPU_TEXTUREFORMAT_D24_UNORM,
        },
        .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &[_]sdl.SDL_GPUVertexBufferDescription{.{
                .slot = 0,
                .pitch = 8 * @sizeOf(f32),
                .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                .instance_step_rate = 0,
            }},
            .num_vertex_buffers = 1,
            .num_vertex_attributes = 3,
            .vertex_attributes = &[_]sdl.SDL_GPUVertexAttribute{
                .{ .location = 0, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, .offset = 0 },
                .{ .location = 1, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, .offset = 3 * @sizeOf(f32) },
                .{ .location = 2, .buffer_slot = 0, .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = 6 * @sizeOf(f32) },
            },
        },
        .rasterizer_state = .{
            .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = args.cullmode,
            .front_face = sdl.SDL_GPU_FRONTFACE_CLOCKWISE,
        },
        .depth_stencil_state = .{
            .enable_depth_test = true,
            .enable_depth_write = true,
            .compare_op = sdl.SDL_GPU_COMPAREOP_LESS,
            .enable_stencil_test = false,
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

    const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        sdl.SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
        return error.CommandBufferFailed;
    };

    const ubo_size = @sizeOf(sdl.SDL_FColor);
    var fragment_ubo: [ubo_size]u8 = undefined;
    @memcpy(&fragment_ubo, std.mem.asBytes(&args.color));

    sdl.SDL_PushGPUFragmentUniformData(cmd, 0, &fragment_ubo, ubo_size);
    _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);

    const white_tex = try createWhiteTexture(device);
    errdefer sdl.SDL_ReleaseGPUTexture(device, white_tex);

    return .{
        .color = args.color,
        .emissive = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        .texture = args.texture orelse white_tex,
        .sampler = args.sampler,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .pipeline = pipeline,
    };
}
