const std = @import("std");
const sdl = @import("../sdl.zig").c;
const Entity = @import("../pool.zig").Entity;

pub const GPUAmbientLight = sdl.SDL_FColor;

pub const Context = struct {
    device: *sdl.SDL_GPUDevice,
    ssbo: *?*sdl.SDL_GPUBuffer,
    ssbo_size: *u32,
    dirty: *bool,
};

pub const AmbientLightComponent = struct {
    color: sdl.SDL_FColor,

    pub fn onAdd(entity: Entity, component: *const @This(), world: *anyopaque, ctx: ?*anyopaque) void {
        _ = entity;
        _ = component;
        _ = world;
        if (ctx) |c| {
            const light_ctx: *Context = @ptrCast(@alignCast(c));
            light_ctx.dirty.* = true;
        }
    }

    pub fn onRemove(entity: Entity, world: *anyopaque, ctx: ?*anyopaque) void {
        _ = entity;
        _ = world;
        if (ctx) |c| {
            const light_ctx: *Context = @ptrCast(@alignCast(c));
            light_ctx.dirty.* = true;
        }
    }

    pub fn rebuildSSBO(world: anytype, ctx: *Context) void {
        var lights = std.ArrayList(GPUAmbientLight).init(std.heap.page_allocator);
        defer lights.deinit();

        var iter = world.iter("ambient_light");
        while (iter.next()) |entry| {
            const entity = entry.entity;
            const light = world.getConst("ambient_light", entity) orelse continue;
            lights.append(light.*) catch return;
        }

        const needed_size: u32 = if (lights.items.len > 0)
            @intCast(lights.items.len * @sizeOf(GPUAmbientLight))
        else
            1024;
        const final_size: u32 = @max(needed_size, 1024);

        if (ctx.ssbo.* == null or ctx.ssbo_size.* < final_size) {
            if (ctx.ssbo.*) |buf| {
                sdl.SDL_ReleaseGPUBuffer(ctx.device, buf);
            }

            const ssbo_info = sdl.SDL_GPUBufferCreateInfo{
                .size = final_size,
                .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
            };
            ctx.ssbo.* = sdl.SDL_CreateGPUBuffer(ctx.device, &ssbo_info);
            ctx.ssbo_size.* = final_size;
        }

        if (lights.items.len == 0) {
            ctx.dirty.* = false;
            return;
        }

        const tbuf_info = sdl.SDL_GPUTransferBufferCreateInfo{
            .size = @intCast(lights.items.len * @sizeOf(GPUAmbientLight)),
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        };
        const tbuf = sdl.SDL_CreateGPUTransferBuffer(ctx.device, &tbuf_info) orelse return;
        defer sdl.SDL_ReleaseGPUTransferBuffer(ctx.device, tbuf);

        const map = sdl.SDL_MapGPUTransferBuffer(ctx.device, tbuf, false) orelse return;
        const typed_map: [*]GPUAmbientLight = @ptrCast(@alignCast(map));
        @memcpy(typed_map[0..lights.items.len], lights.items);
        sdl.SDL_UnmapGPUTransferBuffer(ctx.device, tbuf);

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(ctx.device);
        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd);
        const src_loc = sdl.SDL_GPUTransferBufferLocation{
            .transfer_buffer = tbuf,
            .offset = 0,
        };
        const dst_region = sdl.SDL_GPUBufferRegion{
            .buffer = ctx.ssbo.*.?,
            .offset = 0,
            .size = @intCast(lights.items.len * @sizeOf(GPUAmbientLight)),
        };
        sdl.SDL_UploadToGPUBuffer(copy_pass, &src_loc, &dst_region, false);
        sdl.SDL_EndGPUCopyPass(copy_pass);
        sdl.SDL_SubmitGPUCommandBuffer(cmd);

        ctx.dirty.* = false;
    }
};
