const std = @import("std");
const sdl = @import("../sdl.zig").c;
const math = @import("../math.zig");
const SystemStage = @import("../system/context.zig").SystemStage;
const ActiveCamera = @import("../system/context.zig").ActiveCamera;
const Entity = @import("../pool.zig").Entity;
const Transform = @import("../components/transform.zig").Transform;
const CameraComponent = @import("../components/camera.zig").CameraComponent;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;
const MaterialComponent = @import("../components/material.zig").MaterialComponent;

pub const RenderSystem = struct {
    pub const stage = SystemStage.render;

    pub const Res = struct {
        device: *sdl.SDL_GPUDevice,
        window: *sdl.SDL_Window,
        active_camera: *const ActiveCamera,
    };

    var depth_texture: ?*sdl.SDL_GPUTexture = null;
    var point_ssbo: ?*sdl.SDL_GPUBuffer = null;
    var ambient_ssbo: ?*sdl.SDL_GPUBuffer = null;
    var point_size: u32 = 0;
    var ambient_size: u32 = 0;
    var cached_width: u32 = 0;
    var cached_height: u32 = 0;

    pub fn deinit(device: *sdl.SDL_GPUDevice) void {
        if (depth_texture) |tex| {
            sdl.SDL_ReleaseGPUTexture(device, tex);
            depth_texture = null;
        }
        if (point_ssbo) |buf| {
            sdl.SDL_ReleaseGPUBuffer(device, buf);
            point_ssbo = null;
        }
        if (ambient_ssbo) |buf| {
            sdl.SDL_ReleaseGPUBuffer(device, buf);
            ambient_ssbo = null;
        }
    }

    pub fn run(res: Res, world: anytype) void {
        const cam_entity = res.active_camera.entity orelse return;

        const cam_trans = world.get("transform", cam_entity) orelse return;
        const cam_comp = world.get("camera", cam_entity) orelse return;

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(res.device);
        var swapchain: ?*sdl.SDL_GPUTexture = null;
        var width: c_int = 0;
        var height: c_int = 0;

        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd, res.window, &swapchain, &width, &height)) {
            sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        if (swapchain == null) {
            sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);

        ensureDepthTexture(res.device, w, h);
        ensureSSBOs(res.device);
        if (depth_texture == null) {
            sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        var color_target = sdl.SDL_GPUColorTargetInfo{
            .texture = swapchain.?,
            .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
            .store_op = sdl.SDL_GPU_STOREOP_STORE,
        };

        var depth_target = sdl.SDL_GPUDepthStencilTargetInfo{
            .texture = depth_texture.?,
            .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
            .store_op = sdl.SDL_GPU_STOREOP_STORE,
            .cycle = false,
            .clear_depth = 1.0,
            .clear_stencil = 0,
        };

        const pass = sdl.SDL_BeginGPURenderPass(cmd, &color_target, 1, &depth_target);
        defer sdl.SDL_EndGPURenderPass(pass);

        const viewport = sdl.SDL_GPUViewport{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(width),
            .h = @floatFromInt(height),
            .min_depth = 0,
            .max_depth = 1,
        };
        sdl.SDL_SetGPUViewport(pass, &viewport);

        var view: math.Mat4 = undefined;
        math.mat4Identity(&view);
        const conj_rot = math.quatConjugate(cam_trans.rotation);
        math.mat4RotateQuat(&view, conj_rot);
        math.mat4Translate(&view, math.vec3Scale(cam_trans.position, -1));

        var proj: math.Mat4 = undefined;
        const aspect: f32 = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
        math.mat4Perspective(&proj, cam_comp.fov * std.math.pi / 180.0, aspect, cam_comp.near_clip, cam_comp.far_clip);

        const VertexUBO = extern struct {
            view: [16]f32,
            proj: [16]f32,
        };
        var vertex_ubo: VertexUBO = undefined;
        @memcpy(vertex_ubo.view[0..], view[0..]);
        @memcpy(vertex_ubo.proj[0..], proj[0..]);
        sdl.SDL_PushGPUVertexUniformData(cmd, 0, &vertex_ubo, @sizeOf(VertexUBO));

        const FragmentUBO = extern struct {
            cam_pos: [4]f32,
            cam_rot: [4]f32,
            ambient_count: u32,
            point_count: u32,
            pad0: u32,
            pad1: u32,
        };
        const ambient_count = countComponents(world, "ambient_light");
        const point_count = countComponents(world, "point_light");
        const fragment_ubo = FragmentUBO{
            .cam_pos = .{ cam_trans.position[0], cam_trans.position[1], cam_trans.position[2], 0 },
            .cam_rot = .{ cam_trans.rotation[0], cam_trans.rotation[1], cam_trans.rotation[2], cam_trans.rotation[3] },
            .ambient_count = ambient_count,
            .point_count = point_count,
            .pad0 = 0,
            .pad1 = 0,
        };
        sdl.SDL_PushGPUFragmentUniformData(cmd, 0, &fragment_ubo, @sizeOf(FragmentUBO));

        var mesh_iter = world.iter("mesh");
        while (mesh_iter.next()) |entry| {
            const entity = entry.entity;
            const mesh = world.get("mesh", entity) orelse continue;
            const mat = world.get("material", entity) orelse continue;
            const trans = world.get("transform", entity) orelse continue;

            if (mat.pipeline == null) continue;

            var model: math.Mat4 = undefined;
            math.mat4Identity(&model);
            if (world.has("billboard", entity)) {
                math.mat4Translate(&model, trans.position);
                math.mat4RotateQuat(&model, cam_trans.rotation);
                math.mat4RotateY(&model, std.math.pi);
                math.mat4Scale(&model, trans.scale);
            } else {
                math.mat4Translate(&model, trans.position);
                math.mat4RotateQuat(&model, trans.rotation);
                math.mat4Scale(&model, trans.scale);
            }

            const ObjectUBO = extern struct {
                model: [16]f32,
                color: [4]f32,
            };
            var object_ubo: ObjectUBO = undefined;
            @memcpy(object_ubo.model[0..], model[0..]);
            object_ubo.color = .{ mat.color.r, mat.color.g, mat.color.b, mat.color.a };
            sdl.SDL_PushGPUVertexUniformData(cmd, 1, &object_ubo, @sizeOf(ObjectUBO));

            sdl.SDL_BindGPUGraphicsPipeline(pass, mat.pipeline);

            const vbo_binding = sdl.SDL_GPUBufferBinding{
                .buffer = mesh.vertex_buffer.?,
                .offset = 0,
            };
            sdl.SDL_BindGPUVertexBuffers(pass, 0, &vbo_binding, 1);

            const tex_bind = sdl.SDL_GPUTextureSamplerBinding{
                .texture = mat.texture,
                .sampler = mat.sampler,
            };
            sdl.SDL_BindGPUFragmentSamplers(pass, 0, &tex_bind, 1);

            const buffers = [_]?*sdl.SDL_GPUBuffer{ ambient_ssbo, point_ssbo };
            sdl.SDL_BindGPUFragmentStorageBuffers(pass, 0, &buffers, 2);

            if (mesh.index_buffer) |ib| {
                const ibo_binding = sdl.SDL_GPUBufferBinding{
                    .buffer = ib,
                    .offset = 0,
                };
                sdl.SDL_BindGPUIndexBuffer(pass, &ibo_binding, mesh.index_size);
                sdl.SDL_DrawGPUIndexedPrimitives(pass, mesh.num_indices, 1, 0, 0, 0);
            } else {
                sdl.SDL_DrawGPUPrimitives(pass, mesh.num_vertices, 1, 0, 0);
            }
        }

        sdl.SDL_SubmitGPUCommandBuffer(cmd);
    }

    fn ensureDepthTexture(device: *sdl.SDL_GPUDevice, width: u32, height: u32) void {
        if (depth_texture != null and cached_width == width and cached_height == height) {
            return;
        }

        if (depth_texture) |tex| {
            sdl.SDL_ReleaseGPUTexture(device, tex);
        }

        const depth_info = sdl.SDL_GPUTextureCreateInfo{
            .type = sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = sdl.SDL_GPU_TEXTUREFORMAT_D24_UNORM,
            .width = width,
            .height = height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .usage = sdl.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        };
        depth_texture = sdl.SDL_CreateGPUTexture(device, &depth_info);
        cached_width = width;
        cached_height = height;
    }

    fn ensureSSBOs(device: *sdl.SDL_GPUDevice) void {
        if (point_ssbo != null and ambient_ssbo != null) return;

        const ssbo_info = sdl.SDL_GPUBufferCreateInfo{
            .size = 1024,
            .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        };

        if (point_ssbo == null) {
            point_ssbo = sdl.SDL_CreateGPUBuffer(device, &ssbo_info);
            point_size = 1024;
        }
        if (ambient_ssbo == null) {
            ambient_ssbo = sdl.SDL_CreateGPUBuffer(device, &ssbo_info);
            ambient_size = 1024;
        }
    }

    fn countComponents(world: anytype, comptime name: []const u8) u32 {
        var iter = world.iter(name);
        var count: u32 = 0;
        while (iter.next()) |_| {
            count += 1;
        }
        return count;
    }
};
