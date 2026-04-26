const std = @import("std");
const sdl = @import("../sdl.zig").c;
const math = @import("../math.zig");
const SystemStage = @import("../system/context.zig").SystemStage;
const ActiveCamera = @import("../system/context.zig").ActiveCamera;
const Entity = @import("../pool.zig").Entity;
const uploadIndices = @import("../geometry/common.zig").uploadIndices;
const Transform = @import("../components/transform.zig").Transform;
const CameraComponent = @import("../components/camera.zig").CameraComponent;
const MeshComponent = @import("../components/mesh.zig").MeshComponent;
const MaterialComponent = @import("../components/material.zig").MaterialComponent;
const pointlight = @import("../components/pointlight.zig");
const ambientlight = @import("../components/ambientlight.zig");
const Draw2DRenderer = @import("../draw2d/renderer.zig").Draw2DRenderer;
const UIVertex = @import("../material/ui.zig").UIVertex;
const draw2d = @import("../components/draw2d.zig");
const registry = @import("../draw2d/registry.zig");

pub const RenderSystem = struct {
    pub const stage = SystemStage.Render;

    pub const Res = struct {
        device: *sdl.SDL_GPUDevice,
        window: *sdl.SDL_Window,
        active_camera: *const ActiveCamera,
        texture_registry: ?*registry.TextureRegistry = null,
        font_registry: ?*registry.FontRegistry = null,
    };

    var depth_texture: ?*sdl.SDL_GPUTexture = null;
    var point_ssbo: ?*sdl.SDL_GPUBuffer = null;
    var ambient_ssbo: ?*sdl.SDL_GPUBuffer = null;
    var point_size: u32 = 0;
    var ambient_size: u32 = 0;
    var cached_width: u32 = 0;
    var cached_height: u32 = 0;
    var point_dirty: bool = true;
    var ambient_dirty: bool = true;
    var depth_format: sdl.SDL_GPUTextureFormat = sdl.SDL_GPU_TEXTUREFORMAT_D16_UNORM;
    var swapchain_format: sdl.SDL_GPUTextureFormat = sdl.SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM;
    var draw2d_renderer: ?Draw2DRenderer = null;
    var ui_pipeline: ?*sdl.SDL_GPUGraphicsPipeline = null;
    var ui_vert_shader: ?*sdl.SDL_GPUShader = null;
    var ui_frag_shader: ?*sdl.SDL_GPUShader = null;

    pub fn getDepthFormat() sdl.SDL_GPUTextureFormat {
        return depth_format;
    }

    pub fn initDepthFormat(device: *sdl.SDL_GPUDevice) void {
        const common = @import("../material/common.zig");
        depth_format = common.getSupportedDepthFormat(device);
    }

    pub fn initDraw2D(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window, allocator: std.mem.Allocator) !void {
        if (draw2d_renderer != null) return;
        swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window);
        const ui_material = @import("../material/ui.zig");
        const ui_mat = try ui_material.createUIMaterial(device, swapchain_format, .{});
        ui_pipeline = ui_mat.pipeline;
        ui_vert_shader = ui_mat.vertex_shader;
        ui_frag_shader = ui_mat.fragment_shader;
        draw2d_renderer = try Draw2DRenderer.init(allocator, device);
    }

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
        if (draw2d_renderer) |*r| {
            r.deinit(device);
            draw2d_renderer = null;
        }
        if (ui_pipeline) |p| {
            sdl.SDL_ReleaseGPUGraphicsPipeline(device, p);
            ui_pipeline = null;
        }
        if (ui_vert_shader) |s| {
            sdl.SDL_ReleaseGPUShader(device, s);
            ui_vert_shader = null;
        }
        if (ui_frag_shader) |s| {
            sdl.SDL_ReleaseGPUShader(device, s);
            ui_frag_shader = null;
        }
    }

    pub fn getPointLightContext(device: *sdl.SDL_GPUDevice) pointlight.Context {
        return .{
            .device = device,
            .ssbo = &point_ssbo,
            .ssbo_size = &point_size,
            .dirty = &point_dirty,
        };
    }

    pub fn getAmbientLightContext(device: *sdl.SDL_GPUDevice) ambientlight.Context {
        return .{
            .device = device,
            .ssbo = &ambient_ssbo,
            .ssbo_size = &ambient_size,
            .dirty = &ambient_dirty,
        };
    }

    pub fn run(res: Res, world: anytype) void {
        ensureSSBOs(res.device);

        if (point_dirty and point_ssbo != null) {
            var ctx = getPointLightContext(res.device);
            pointlight.PointLightComponent.rebuildSSBO(world, &ctx);
        }
        if (ambient_dirty and ambient_ssbo != null) {
            var ctx = getAmbientLightContext(res.device);
            ambientlight.AmbientLightComponent.rebuildSSBO(world, &ctx);
        }

        const cam_entity = res.active_camera.entity orelse return;

        const cam_trans = world.get("transform", cam_entity) orelse return;
        const cam_comp = world.get("camera", cam_entity) orelse return;

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(res.device);
        var swapchain: ?*sdl.SDL_GPUTexture = null;
        var width: u32 = 0;
        var height: u32 = 0;

        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd, res.window, &swapchain, &width, &height)) {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        if (swapchain == null) {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return;
        }

        const w: u32 = width;
        const h: u32 = height;

        ensureDepthTexture(res.device, w, h);
        ensureSSBOs(res.device);
        if (depth_texture == null) {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
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

        // Pre-warm text cache before render pass to avoid GPU work during the pass
        if (@hasField(@TypeOf(world.pools), "draw_canvas_pool") and draw2d_renderer != null) {
            if (res.font_registry) |font_reg| {
                var warm_iter = world.iter("draw_canvas");
                while (warm_iter.next()) |entry| {
                    const dc = world.get("draw_canvas", entry.entity) orelse continue;
                    for (dc.commands.items) |draw_cmd| {
                        switch (draw_cmd) {
                            .text => |t| {
                                if (font_reg.get(t.font_id)) |font| {
                                    _ = draw2d_renderer.?.text_cache.getOrCreate(res.device, font, t.text, t.color, t.scale) catch {};
                                }
                            },
                            else => {},
                        }
                    }
                }
                draw2d_renderer.?.text_cache.flushPendingUploads(res.device) catch {};
            }
        }

        const pass = sdl.SDL_BeginGPURenderPass(cmd, &color_target, 1, &depth_target);

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

        if (@hasField(@TypeOf(world.pools), "draw_canvas_pool") and draw2d_renderer != null and ui_pipeline != null) {
            if (res.texture_registry) |tex_reg| {
                if (res.font_registry) |font_reg| {
                    var rr = &draw2d_renderer.?;

                    const res_w: f32 = @floatFromInt(width);
                    const res_h: f32 = @floatFromInt(height);

                    const CanvasEntry = struct {
                        entity: Entity,
                        z_index: f32,
                    };

                    var canvas_entries: [256]CanvasEntry = undefined;
                    var canvas_count: usize = 0;
                    var canvas_iter = world.iter("draw_canvas");
                    while (canvas_iter.next()) |entry| {
                        if (canvas_count >= canvas_entries.len) break;
                        const canvas = world.get("draw_canvas", entry.entity) orelse continue;
                        if (canvas.commands.items.len == 0) continue;
                        canvas_entries[canvas_count] = .{
                            .entity = entry.entity,
                            .z_index = canvas.z_index,
                        };
                        canvas_count += 1;
                    }

                    if (canvas_count > 0) {
                        std.mem.sort(CanvasEntry, canvas_entries[0..canvas_count], {}, struct {
                            fn lt(_: void, a: CanvasEntry, b: CanvasEntry) bool {
                                return a.z_index < b.z_index;
                            }
                        }.lt);

                        for (canvas_entries[0..canvas_count]) |ce| {
                            const canvas = world.get("draw_canvas", ce.entity) orelse continue;
                            if (canvas.commands.items.len == 0) continue;

                            const transform = world.get("transform", ce.entity);
                            const offset_x: f32 = if (transform) |t| t.position[0] else 0;
                            const offset_y: f32 = if (transform) |t| t.position[1] else 0;

                            // Get or create cache entry for this canvas
                            const cache_gop = rr.canvas_cache.getOrPut(@intCast(ce.entity)) catch continue;
                            if (!cache_gop.found_existing) {
                                cache_gop.value_ptr.* = Draw2DRenderer.CanvasCache.init(rr.allocator);
                            }
                            const cache = cache_gop.value_ptr;

                            // Rebuild chunks if dirty
                            if (canvas.dirty) {
                                cache.clear(res.device);

                                var cmd_idx: u32 = 0;
                                const total_cmds: u32 = @intCast(canvas.commands.items.len);
                                const CHUNK_SIZE = Draw2DRenderer.CHUNK_SIZE;

                                while (cmd_idx < total_cmds) {
                                    const chunk_start = cmd_idx;
                                    var chunk_texture: *sdl.SDL_GPUTexture = rr.white_texture;
                                    var chunk_cmd_count: u32 = 0;

                                    // Determine texture for first command in chunk
                                    {
                                        const first_cmd = canvas.commands.items[chunk_start];
                                        chunk_texture = resolveTexture(first_cmd, rr, tex_reg, font_reg);
                                    }

                                    // Collect commands for this chunk (same texture, max CHUNK_SIZE)
                                    while (cmd_idx < total_cmds and chunk_cmd_count < CHUNK_SIZE) {
                                        const cur_cmd = canvas.commands.items[cmd_idx];
                                        const cmd_tex = resolveTexture(cur_cmd, rr, tex_reg, font_reg);

                                        if (chunk_cmd_count > 0 and cmd_tex != chunk_texture) {
                                            break;
                                        }

                                        chunk_texture = cmd_tex;
                                        chunk_cmd_count += 1;
                                        cmd_idx += 1;
                                    }

                                    if (chunk_cmd_count == 0) continue;

                                    // Build geometry for this chunk
                                    var vert_fallback = std.heap.stackFallback(256 * @sizeOf(UIVertex), std.heap.page_allocator);
                                    const vert_alloc = vert_fallback.get();
                                    var vertices = std.ArrayList(UIVertex).initCapacity(vert_alloc, 256) catch continue;
                                    defer vertices.deinit(vert_alloc);

                                    var idx_fallback = std.heap.stackFallback(384 * @sizeOf(u32), std.heap.page_allocator);
                                    const idx_alloc = idx_fallback.get();
                                    var indices = std.ArrayList(u32).initCapacity(idx_alloc, 384) catch continue;
                                    defer indices.deinit(idx_alloc);

                                    var cmd_i = chunk_start;
                                    while (cmd_i < chunk_start + chunk_cmd_count) : (cmd_i += 1) {
                                        const dc3 = canvas.commands.items[cmd_i];
                                        switch (dc3) {
                                            .rect => |r| {
                                                const cx = offset_x + r.x + r.w / 2.0;
                                                const cy = offset_y + r.y + r.h / 2.0;
                                                const ccr = @cos(r.rotation);
                                                const sr = @sin(r.rotation);
                                                const filled: f32 = if (r.filled) 1.0 else 0.0;
                                                const bt: f32 = if (!r.filled) @max(r.border_thickness, 0.0) else 0.0;
                                                Draw2DRenderer.emitQuad(
                                                    &vertices, &indices, vert_alloc,
                                                    offset_x + r.x, offset_y + r.y, r.w, r.h,
                                                    cx, cy, ccr, sr, r.w / 2.0, r.h / 2.0,
                                                    r.corner_radius, bt, filled, r.color,
                                                    res_w, res_h, 0, 0, 1, 1,
                                                );
                                            },
                                            .sprite => |s| {
                                                const cx = offset_x + s.x + s.w / 2.0;
                                                const cy = offset_y + s.y + s.h / 2.0;
                                                const ccr = @cos(s.rotation);
                                                const sr = @sin(s.rotation);
                                                const filled: f32 = if (s.filled) 1.0 else 0.0;
                                                const bt: f32 = if (!s.filled) @max(s.border_thickness, 0.0) else 0.0;
                                                Draw2DRenderer.emitQuad(
                                                    &vertices, &indices, vert_alloc,
                                                    offset_x + s.x, offset_y + s.y, s.w, s.h,
                                                    cx, cy, ccr, sr, s.w / 2.0, s.h / 2.0,
                                                    s.corner_radius, bt, filled, s.color,
                                                    res_w, res_h, s.uv[0], s.uv[1], s.uv[2], s.uv[3],
                                                );
                                            },
                                            .text => |t| {
                                                if (font_reg.get(t.font_id)) |font| {
                                                    const entry = rr.text_cache.get(font, t.text, t.color, t.scale) orelse continue;
                                                    const cx = offset_x + t.x + entry.w / 2.0;
                                                    const cy = offset_y + t.y + entry.h / 2.0;
                                                    const ccr = @cos(t.rotation);
                                                    const sr = @sin(t.rotation);
                                                    Draw2DRenderer.emitQuad(
                                                        &vertices, &indices, vert_alloc,
                                                        offset_x + t.x, offset_y + t.y, entry.w, entry.h,
                                                        cx, cy, ccr, sr, entry.w / 2.0, entry.h / 2.0,
                                                        0, 0, 1.0, t.color,
                                                        res_w, res_h, 0, 0, 1, 1,
                                                    );
                                                }
                                            },
                                        }
                                    }

                                    if (vertices.items.len == 0 or indices.items.len == 0) continue;

                                    const vb = uploadUIVertices(res.device, vertices.items) catch continue;
                                    const ib = uploadIndices(res.device, indices.items) catch {
                                        sdl.SDL_ReleaseGPUBuffer(res.device, vb);
                                        continue;
                                    };

                                    cache.chunks.append(rr.allocator, .{
                                        .start = chunk_start,
                                        .count = chunk_cmd_count,
                                        .vertex_buffer = vb,
                                        .index_buffer = ib,
                                        .index_count = @intCast(indices.items.len),
                                        .texture = chunk_texture,
                                    }) catch {
                                        sdl.SDL_ReleaseGPUBuffer(res.device, vb);
                                        sdl.SDL_ReleaseGPUBuffer(res.device, ib);
                                        continue;
                                    };
                                }

                                canvas.dirty = false;
                            }

                            // Draw all chunks
                            for (cache.chunks.items) |chunk| {
                                sdl.SDL_BindGPUGraphicsPipeline(pass, ui_pipeline.?);
                                const cvb = sdl.SDL_GPUBufferBinding{
                                    .buffer = chunk.vertex_buffer,
                                    .offset = 0,
                                };
                                sdl.SDL_BindGPUVertexBuffers(pass, 0, &cvb, 1);
                                const cib = sdl.SDL_GPUBufferBinding{
                                    .buffer = chunk.index_buffer,
                                    .offset = 0,
                                };
                                sdl.SDL_BindGPUIndexBuffer(pass, &cib, sdl.SDL_GPU_INDEXELEMENTSIZE_32BIT);
                                const ctex = sdl.SDL_GPUTextureSamplerBinding{
                                    .texture = chunk.texture,
                                    .sampler = rr.ui_sampler,
                                };
                                sdl.SDL_BindGPUFragmentSamplers(pass, 0, &ctex, 1);
                                sdl.SDL_DrawGPUIndexedPrimitives(pass, chunk.index_count, 1, 0, 0, 0);
                            }
                        }
                    }
                }
            }
        }

        sdl.SDL_EndGPURenderPass(pass);
        _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
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
            .format = depth_format,
            .usage = sdl.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
            .width = width,
            .height = height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
            .props = 0,
        };
        depth_texture = sdl.SDL_CreateGPUTexture(device, &depth_info);
        cached_width = width;
        cached_height = height;
    }

    fn ensureSSBOs(device: *sdl.SDL_GPUDevice) void {
        if (point_ssbo != null and ambient_ssbo != null) return;

        const ssbo_info = sdl.SDL_GPUBufferCreateInfo{
            .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
            .size = 1024,
            .props = 0,
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

    fn uploadUIVertices(device: *sdl.SDL_GPUDevice, vertices: []const UIVertex) !*sdl.SDL_GPUBuffer {
        const buffer_size: u32 = @intCast(@sizeOf(UIVertex) * vertices.len);

        const transfer_info = sdl.SDL_GPUTransferBufferCreateInfo{
            .size = buffer_size,
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .props = 0,
        };

        const transfer_buf = sdl.SDL_CreateGPUTransferBuffer(device, &transfer_info) orelse return error.TransferBufferFailed;
        defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);

        const data = sdl.SDL_MapGPUTransferBuffer(device, transfer_buf, false) orelse return error.MapFailed;

        const vertices_bytes: []const u8 = std.mem.sliceAsBytes(vertices);
        @memcpy(@as([*]u8, @ptrCast(data))[0..buffer_size], vertices_bytes);
        sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buf);

        const buffer_info = sdl.SDL_GPUBufferCreateInfo{
            .size = buffer_size,
            .usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .props = 0,
        };

        const buffer = sdl.SDL_CreateGPUBuffer(device, &buffer_info) orelse return error.BufferCreateFailed;

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
            sdl.SDL_ReleaseGPUBuffer(device, buffer);
            return error.CommandBufferFailed;
        };

        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
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
        _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);

        return buffer;
    }

    fn countComponents(world: anytype, comptime name: []const u8) u32 {
        var iter = world.iter(name);
        var count: u32 = 0;
        while (iter.next()) |_| {
            count += 1;
        }
        return count;
    }

    fn resolveTexture(
        cmd: draw2d.DrawCommand,
        rr: *Draw2DRenderer,
        tex_reg: *const registry.TextureRegistry,
        font_reg: *const registry.FontRegistry,
    ) *sdl.SDL_GPUTexture {
        switch (cmd) {
            .rect => |r| {
                if (r.texture_id) |tid| {
                    if (tex_reg.get(tid)) |tex| return tex;
                }
            },
            .sprite => |s| {
                if (tex_reg.get(s.texture_id)) |tex| return tex;
            },
            .text => |t| {
                if (font_reg.get(t.font_id)) |font| {
                    const entry = rr.text_cache.get(font, t.text, t.color, t.scale) orelse return rr.white_texture;
                    return entry.texture;
                }
            },
        }
        return rr.white_texture;
    }
};
