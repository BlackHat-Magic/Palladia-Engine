const std = @import("std");
const sdl = @import("../sdl.zig").c;
const math = @import("../math.zig");
const SystemContext = @import("../system/context.zig").SystemContext;
const SystemStage = @import("../system/context.zig").SystemStage;
const Renderer = @import("../system/context.zig").Renderer;
const Entity = @import("../pool.zig").Entity;
const Transform = @import("../components/transform.zig").Transform;
const CameraComponent = @import("../components/camera.zig").CameraComponent;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;
const MaterialComponent = @import("../components/material.zig").MaterialComponent;
const AmbientLightComponent = @import("../components/ambientlight.zig").AmbientLightComponent;
const PointLightComponent = @import("../components/pointlight.zig").PointLightComponent;
const PointLight = @import("../components/pointlight.zig").PointLight;

pub const RenderSystem = struct {
    pub const stage = SystemStage.render;

    pub fn run(ctx: *SystemContext, world: anytype) void {
        const renderer = ctx.renderer;
        const cam_entity = ctx.active_camera orelse return;

        const cam_trans = world.get("transform", cam_entity) orelse return;
        const cam_comp = world.get("camera", cam_entity) orelse return;

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(renderer.device);
        var swapchain: ?*sdl.SDL_GPUTexture = null;
        var width: c_int = 0;
        var height: c_int = 0;

        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd, renderer.window, &swapchain, &width, &height)) {
            sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        if (swapchain == null) {
            sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        renderer.width = @intCast(width);
        renderer.height = @intCast(height);

        var color_target = sdl.SDL_GPUColorTargetInfo{
            .texture = swapchain.?,
            .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
            .store_op = sdl.SDL_GPU_STOREOP_STORE,
        };

        var depth_target = sdl.SDL_GPUDepthStencilTargetInfo{
            .texture = renderer.depth_texture.?,
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

            const buffers = [_]?*sdl.SDL_GPUBuffer{ renderer.ambient_ssbo, renderer.point_ssbo };
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
};

fn countComponents(world: anytype, comptime name: []const u8) u32 {
    var iter = world.iter(name);
    var count: u32 = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    return count;
}
