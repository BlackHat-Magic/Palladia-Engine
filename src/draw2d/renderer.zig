const std = @import("std");
const sdl = @import("../sdl.zig").c;
const draw2d = @import("../components/draw2d.zig");

const UIVertex = @import("../material/ui.zig").UIVertex;

pub const TextCacheEntry = struct {
    texture: *sdl.SDL_GPUTexture,
    w: f32,
    h: f32,
};

pub const TextCacheKey = struct {
    hash: u64,
};

pub const PendingUpload = struct {
    texture: *sdl.SDL_GPUTexture,
    transfer: *sdl.SDL_GPUTransferBuffer,
    w: u32,
    h: u32,
};

pub const TextCache = struct {
    entries: std.ArrayList(TextCacheEntry),
    keys: std.ArrayList(TextCacheKey),
    access_counters: std.ArrayList(u64),
    pending: std.ArrayList(PendingUpload),
    allocator: std.mem.Allocator,
    counter: u64 = 0,

    const MAX_ENTRIES = 256;

    pub fn init(allocator: std.mem.Allocator) TextCache {
        return .{
            .entries = std.ArrayList(TextCacheEntry).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .keys = std.ArrayList(TextCacheKey).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .access_counters = std.ArrayList(u64).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .pending = std.ArrayList(PendingUpload).initCapacity(allocator, 64) catch @panic("OOM"),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextCache, device: *sdl.SDL_GPUDevice) void {
        for (self.pending.items) |pu| {
            sdl.SDL_ReleaseGPUTransferBuffer(device, pu.transfer);
        }
        self.pending.deinit(self.allocator);
        for (self.entries.items) |entry| {
            sdl.SDL_ReleaseGPUTexture(device, entry.texture);
        }
        self.entries.deinit(self.allocator);
        self.keys.deinit(self.allocator);
        self.access_counters.deinit(self.allocator);
    }

    fn computeKey(font: *sdl.TTF_Font, text: []const u8, color: [4]f32, scale: f32) TextCacheKey {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&@intFromPtr(font)));
        hasher.update(text);
        hasher.update(std.mem.asBytes(&color));
        hasher.update(std.mem.asBytes(&scale));
        return TextCacheKey{ .hash = hasher.final() };
    }

    pub fn get(
        self: *TextCache,
        font: *sdl.TTF_Font,
        text: []const u8,
        color: [4]f32,
        scale: f32,
    ) ?TextCacheEntry {
        const key = computeKey(font, text, color, scale);
        for (self.keys.items, 0..) |k, i| {
            if (k.hash == key.hash) {
                self.access_counters.items[i] = self.counter;
                self.counter += 1;
                return self.entries.items[i];
            }
        }
        return null;
    }

    pub fn getOrCreate(
        self: *TextCache,
        device: *sdl.SDL_GPUDevice,
        font: *sdl.TTF_Font,
        text: []const u8,
        color: [4]f32,
        scale: f32,
    ) !TextCacheEntry {
        const key = computeKey(font, text, color, scale);

        for (self.keys.items, 0..) |k, i| {
            if (k.hash == key.hash) {
                self.access_counters.items[i] = self.counter;
                self.counter += 1;
                return self.entries.items[i];
            }
        }

        if (self.keys.items.len >= MAX_ENTRIES) {
            var min_idx: usize = 0;
            var min_counter: u64 = std.math.maxInt(u64);
            for (self.access_counters.items, 0..) |c, i| {
                if (c < min_counter) {
                    min_counter = c;
                    min_idx = i;
                }
            }
            sdl.SDL_ReleaseGPUTexture(device, self.entries.items[min_idx].texture);
            _ = self.keys.swapRemove(min_idx);
            _ = self.entries.swapRemove(min_idx);
            _ = self.access_counters.swapRemove(min_idx);
        }

        const sdl_color: sdl.SDL_Color = .{
            .r = @intFromFloat(@min(color[0], 1.0) * 255),
            .g = @intFromFloat(@min(color[1], 1.0) * 255),
            .b = @intFromFloat(@min(color[2], 1.0) * 255),
            .a = @intFromFloat(@min(color[3], 1.0) * 255),
        };

        _ = sdl.TTF_SetFontSize(font, scale);

        const surface = sdl.TTF_RenderText_Blended(font, text.ptr, text.len, sdl_color);
        if (surface == null) return error.TextRenderFailed;
        defer sdl.SDL_DestroySurface(surface);

        const converted = sdl.SDL_ConvertSurface(surface, sdl.SDL_PIXELFORMAT_ABGR8888);
        if (converted == null) return error.TextRenderFailed;
        defer sdl.SDL_DestroySurface(converted);

        const tex_w: u32 = @intCast(converted.?.*.w);
        const tex_h: u32 = @intCast(converted.?.*.h);

        const tex_info = sdl.SDL_GPUTextureCreateInfo{
            .type = sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .width = tex_w,
            .height = tex_h,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .props = 0,
        };

        const texture = sdl.SDL_CreateGPUTexture(device, &tex_info) orelse return error.TextureCreateFailed;

        const tinfo = sdl.SDL_GPUTransferBufferCreateInfo{
            .size = @as(u32, @intCast(converted.?.*.pitch)) * tex_h,
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .props = 0,
        };
        const transfer = sdl.SDL_CreateGPUTransferBuffer(device, &tinfo) orelse {
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.TransferBufferFailed;
        };

        const data_ptr = sdl.SDL_MapGPUTransferBuffer(device, transfer, false) orelse {
            sdl.SDL_ReleaseGPUTransferBuffer(device, transfer);
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.MapFailed;
        };
        @memcpy(@as([*]u8, @ptrCast(data_ptr))[0..tinfo.size], @as([*]const u8, @ptrCast(converted.?.*.pixels))[0..tinfo.size]);
        sdl.SDL_UnmapGPUTransferBuffer(device, transfer);

        const entry = TextCacheEntry{ .texture = texture, .w = @floatFromInt(tex_w), .h = @floatFromInt(tex_h) };
        self.keys.append(self.allocator, key) catch return error.OutOfMemory;
        self.entries.append(self.allocator, entry) catch return error.OutOfMemory;
        self.access_counters.append(self.allocator, self.counter) catch return error.OutOfMemory;
        self.counter += 1;

        self.pending.append(self.allocator, .{
            .texture = texture,
            .transfer = transfer,
            .w = tex_w,
            .h = tex_h,
        }) catch {
            sdl.SDL_ReleaseGPUTransferBuffer(device, transfer);
            return error.OutOfMemory;
        };

        return entry;
    }

    pub fn flushPendingUploads(self: *TextCache, device: *sdl.SDL_GPUDevice) !void {
        if (self.pending.items.len == 0) return;

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse return error.CommandBufferFailed;
        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
            return error.CopyPassFailed;
        };

        for (self.pending.items) |pu| {
            const src = sdl.SDL_GPUTextureTransferInfo{
                .transfer_buffer = pu.transfer,
                .offset = 0,
                .pixels_per_row = pu.w,
                .rows_per_layer = pu.h,
            };
            const dst = sdl.SDL_GPUTextureRegion{
                .texture = pu.texture,
                .w = pu.w,
                .h = pu.h,
                .d = 1,
                .x = 0,
                .y = 0,
                .z = 0,
            };
            sdl.SDL_UploadToGPUTexture(copy_pass, &src, &dst, false);
        }

        sdl.SDL_EndGPUCopyPass(copy_pass);
        _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);

        for (self.pending.items) |pu| {
            sdl.SDL_ReleaseGPUTransferBuffer(device, pu.transfer);
        }
        self.pending.clearRetainingCapacity();
    }
};

pub const Draw2DRenderer = struct {
    white_texture: *sdl.SDL_GPUTexture,
    ui_sampler: *sdl.SDL_GPUSampler,
    canvas_cache: std.AutoHashMap(u32, CanvasCache),
    text_cache: TextCache,
    allocator: std.mem.Allocator,

    const Self = @This();
    pub const CHUNK_SIZE = 256;

    pub const CommandChunk = struct {
        start: u32,
        count: u32,
        vertex_buffer: *sdl.SDL_GPUBuffer,
        index_buffer: *sdl.SDL_GPUBuffer,
        index_count: u32,
        texture: *sdl.SDL_GPUTexture,
    };

    pub const CanvasCache = struct {
        chunks: std.ArrayList(CommandChunk),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) CanvasCache {
            return .{
                .chunks = std.ArrayList(CommandChunk).initCapacity(allocator, 16) catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *CanvasCache, device: *sdl.SDL_GPUDevice) void {
            for (self.chunks.items) |chunk| {
                sdl.SDL_ReleaseGPUBuffer(device, chunk.vertex_buffer);
                sdl.SDL_ReleaseGPUBuffer(device, chunk.index_buffer);
            }
            self.chunks.deinit(self.allocator);
        }

        pub fn clear(self: *CanvasCache, device: *sdl.SDL_GPUDevice) void {
            for (self.chunks.items) |chunk| {
                sdl.SDL_ReleaseGPUBuffer(device, chunk.vertex_buffer);
                sdl.SDL_ReleaseGPUBuffer(device, chunk.index_buffer);
            }
            self.chunks.clearRetainingCapacity();
        }
    };

    pub fn init(allocator: std.mem.Allocator, device: *sdl.SDL_GPUDevice) !Self {
        const common = @import("../material/common.zig");
        const white = try common.createWhiteTexture(device);
        const sampler = try common.createDefaultSampler(device);
        return .{
            .white_texture = white,
            .ui_sampler = sampler,
            .canvas_cache = std.AutoHashMap(u32, CanvasCache).init(allocator),
            .text_cache = TextCache.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, device: *sdl.SDL_GPUDevice) void {
        sdl.SDL_ReleaseGPUTexture(device, self.white_texture);
        sdl.SDL_ReleaseGPUSampler(device, self.ui_sampler);
        var iter = self.canvas_cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(device);
        }
        self.canvas_cache.deinit();
        self.text_cache.deinit(device);
    }

    pub fn buildChunks(
        self: *Self,
        device: *sdl.SDL_GPUDevice,
        canvas: *const draw2d.DrawCanvas,
        tex_reg: *const @import("registry.zig").TextureRegistry,
        font_reg: *const @import("registry.zig").FontRegistry,
        offset_x: f32,
        offset_y: f32,
        res_w: f32,
        res_h: f32,
    ) !void {
        // Find or create cache entry for this entity
        // (The caller must ensure the cache entry exists and is cleared if dirty)
        _ = self;
        _ = device;
        _ = canvas;
        _ = tex_reg;
        _ = font_reg;
        _ = offset_x;
        _ = offset_y;
        _ = res_w;
        _ = res_h;
        @panic("buildChunks should be inlined in RenderSystem, not called directly");
    }

    pub fn emitQuad(
        vertices: *std.ArrayList(UIVertex),
        indices: *std.ArrayList(u32),
        allocator: std.mem.Allocator,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        cx: f32,
        cy: f32,
        cr: f32,
        sr: f32,
        half_w: f32,
        half_h: f32,
        corner_radius: f32,
        border_thickness: f32,
        filled: f32,
        color: [4]f32,
        res_w: f32,
        res_h: f32,
        uv_min: f32,
        uv_min_v: f32,
        uv_max: f32,
        uv_max_v: f32,
    ) void {
        const res_arr = [2]f32{ res_w, res_h };
        const start: u32 = @intCast(vertices.items.len);
        vertices.append(allocator, .{
            .position = .{ x, y },
            .res = res_arr,
            .color = color,
            .uv = .{ uv_min, uv_min_v },
            .center = .{ cx, cy },
            .rot_cos = cr,
            .rot_sin = sr,
            .half_size = .{ half_w, half_h },
            .corner_radius = corner_radius,
            .border_thickness = border_thickness,
            .filled = filled,
        }) catch return;
        vertices.append(allocator, .{
            .position = .{ x + w, y },
            .res = res_arr,
            .color = color,
            .uv = .{ uv_max, uv_min_v },
            .center = .{ cx, cy },
            .rot_cos = cr,
            .rot_sin = sr,
            .half_size = .{ half_w, half_h },
            .corner_radius = corner_radius,
            .border_thickness = border_thickness,
            .filled = filled,
        }) catch return;
        vertices.append(allocator, .{
            .position = .{ x, y + h },
            .res = res_arr,
            .color = color,
            .uv = .{ uv_min, uv_max_v },
            .center = .{ cx, cy },
            .rot_cos = cr,
            .rot_sin = sr,
            .half_size = .{ half_w, half_h },
            .corner_radius = corner_radius,
            .border_thickness = border_thickness,
            .filled = filled,
        }) catch return;
        vertices.append(allocator, .{
            .position = .{ x + w, y + h },
            .res = res_arr,
            .color = color,
            .uv = .{ uv_max, uv_max_v },
            .center = .{ cx, cy },
            .rot_cos = cr,
            .rot_sin = sr,
            .half_size = .{ half_w, half_h },
            .corner_radius = corner_radius,
            .border_thickness = border_thickness,
            .filled = filled,
        }) catch return;
        indices.appendSlice(allocator, &.{ start, start + 1, start + 2, start + 2, start + 1, start + 3 }) catch return;
    }
};
