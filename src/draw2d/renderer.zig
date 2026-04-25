const std = @import("std");
const sdl = @import("../sdl.zig").c;

const UIVertex = @import("../material/ui.zig").UIVertex;

pub const CachedBuffers = struct {
    command_hash: u64,
    vertex_buffer: *sdl.SDL_GPUBuffer,
    index_buffer: *sdl.SDL_GPUBuffer,
    index_count: u32,
};

pub const TextCacheEntry = struct {
    texture: *sdl.SDL_GPUTexture,
    w: f32,
    h: f32,
};

pub const TextCacheKey = struct {
    hash: u64,
};

pub const TextCache = struct {
    entries: std.ArrayList(TextCacheEntry),
    keys: std.ArrayList(TextCacheKey),
    access_counters: std.ArrayList(u64),
    allocator: std.mem.Allocator,
    counter: u64 = 0,

    const MAX_ENTRIES = 256;

    pub fn init(allocator: std.mem.Allocator) TextCache {
        return .{
            .entries = std.ArrayList(TextCacheEntry).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .keys = std.ArrayList(TextCacheKey).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .access_counters = std.ArrayList(u64).initCapacity(allocator, MAX_ENTRIES) catch @panic("OOM"),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextCache, device: *sdl.SDL_GPUDevice) void {
        for (self.entries.items) |entry| {
            sdl.SDL_ReleaseGPUTexture(device, entry.texture);
        }
        self.entries.deinit(self.allocator);
        self.keys.deinit(self.allocator);
        self.access_counters.deinit(self.allocator);
    }

    pub fn getOrCreate(
        self: *TextCache,
        device: *sdl.SDL_GPUDevice,
        font: *sdl.TTF_Font,
        text: []const u8,
        color: [4]f32,
        scale: f32,
    ) !TextCacheEntry {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&@intFromPtr(font)));
        hasher.update(text);
        hasher.update(std.mem.asBytes(&color));
        hasher.update(std.mem.asBytes(&scale));
        const key = TextCacheKey{ .hash = hasher.final() };

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

        const tex_w: u32 = @intCast(surface.?.*.w);
        const tex_h: u32 = @intCast(surface.?.*.h);

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
            .size = @intCast(surface.?.*.pitch * tex_h),
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .props = 0,
        };
        const transfer = sdl.SDL_CreateGPUTransferBuffer(device, &tinfo) orelse {
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.TransferBufferFailed;
        };
        defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer);

        const data_ptr = sdl.SDL_MapGPUTransferBuffer(device, transfer, false) orelse {
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.MapFailed;
        };
        @memcpy(@as([*]u8, @ptrCast(data_ptr))[0..tinfo.size], @as([*]const u8, @ptrCast(surface.?.*.pixels))[0..tinfo.size]);
        sdl.SDL_UnmapGPUTransferBuffer(device, transfer);

        const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.CommandBufferFailed;
        };
        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse {
            _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);
            sdl.SDL_ReleaseGPUTexture(device, texture);
            return error.CopyPassFailed;
        };

        const src = sdl.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer,
            .offset = 0,
            .pixels_per_row = tex_w,
            .rows_per_layer = tex_h,
        };
        const dst = sdl.SDL_GPUTextureRegion{
            .texture = texture,
            .w = tex_w,
            .h = tex_h,
            .d = 1,
            .x = 0,
            .y = 0,
            .z = 0,
        };
        sdl.SDL_UploadToGPUTexture(copy_pass, &src, &dst, false);
        sdl.SDL_EndGPUCopyPass(copy_pass);
        _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);

        const entry = TextCacheEntry{ .texture = texture, .w = @floatFromInt(tex_w), .h = @floatFromInt(tex_h) };
        self.keys.append(self.allocator, key) catch return error.OutOfMemory;
        self.entries.append(self.allocator, entry) catch return error.OutOfMemory;
        self.access_counters.append(self.allocator, self.counter) catch return error.OutOfMemory;
        self.counter += 1;

        return entry;
    }
};

pub const Draw2DRenderer = struct {
    white_texture: *sdl.SDL_GPUTexture,
    ui_sampler: *sdl.SDL_GPUSampler,
    vertex_cache: std.AutoHashMap(u32, CachedBuffers),
    text_cache: TextCache,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, device: *sdl.SDL_GPUDevice) !Self {
        const common = @import("../material/common.zig");
        const white = try common.createWhiteTexture(device);
        const sampler = try common.createDefaultSampler(device);
        return .{
            .white_texture = white,
            .ui_sampler = sampler,
            .vertex_cache = std.AutoHashMap(u32, CachedBuffers).init(allocator),
            .text_cache = TextCache.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self, device: *sdl.SDL_GPUDevice) void {
        sdl.SDL_ReleaseGPUTexture(device, self.white_texture);
        sdl.SDL_ReleaseGPUSampler(device, self.ui_sampler);
        var iter = self.vertex_cache.iterator();
        while (iter.next()) |entry| {
            sdl.SDL_ReleaseGPUBuffer(device, entry.value_ptr.vertex_buffer);
            sdl.SDL_ReleaseGPUBuffer(device, entry.value_ptr.index_buffer);
        }
        self.vertex_cache.deinit();
        self.text_cache.deinit(device);
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
        }) catch return;
        indices.appendSlice(allocator, &.{ start, start + 1, start + 2, start + 2, start + 1, start + 3 }) catch return;
    }
};
