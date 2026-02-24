const sdl = @import("../sdl.zig").c;
const Entity = @import("../pool.zig").Entity;

pub const Renderer = struct {
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    width: u32,
    height: u32,
    dwidth: u32,
    dheight: u32,
    depth_texture: ?*sdl.SDL_GPUTexture,
    format: sdl.SDL_GPUTextureFormat,
    point_ssbo: ?*sdl.SDL_GPUBuffer,
    point_size: u32,
    ambient_ssbo: ?*sdl.SDL_GPUBuffer,
    ambient_size: u32,

    pub const CreateInfo = struct {
        device: *sdl.SDL_GPUDevice,
        window: *sdl.SDL_Window,
        width: u32,
        height: u32,
    };

    pub fn init(info: CreateInfo) !Renderer {
        const format = sdl.SDL_GetGPUSwapchainTextureFormat(info.device, info.window);
        if (format == sdl.SDL_GPU_TEXTUREFORMAT_INVALID) {
            return error.SwapchainFormatError;
        }

        const depth_info = sdl.SDL_GPUTextureCreateInfo{
            .type = sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = sdl.SDL_GPU_TEXTUREFORMAT_D24_UNORM,
            .width = info.width,
            .height = info.height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .usage = sdl.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        };
        const depth_texture = sdl.SDL_CreateGPUTexture(info.device, &depth_info) orelse return error.DepthTextureError;

        const ssbo_info = sdl.SDL_GPUBufferCreateInfo{
            .size = 1024,
            .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        };

        const point_ssbo = sdl.SDL_CreateGPUBuffer(info.device, &ssbo_info) orelse {
            sdl.SDL_ReleaseGPUTexture(info.device, depth_texture);
            return error.SSBOError;
        };

        const ambient_ssbo = sdl.SDL_CreateGPUBuffer(info.device, &ssbo_info) orelse {
            sdl.SDL_ReleaseGPUTexture(info.device, depth_texture);
            sdl.SDL_ReleaseGPUBuffer(info.device, point_ssbo);
            return error.SSBOError;
        };

        return .{
            .device = info.device,
            .window = info.window,
            .width = info.width,
            .height = info.height,
            .dwidth = info.width,
            .dheight = info.height,
            .depth_texture = depth_texture,
            .format = format,
            .point_ssbo = point_ssbo,
            .point_size = 1024,
            .ambient_ssbo = ambient_ssbo,
            .ambient_size = 1024,
        };
    }

    pub fn deinit(self: *Renderer) void {
        if (self.depth_texture) |tex| sdl.SDL_ReleaseGPUTexture(self.device, tex);
        if (self.point_ssbo) |buf| sdl.SDL_ReleaseGPUBuffer(self.device, buf);
        if (self.ambient_ssbo) |buf| sdl.SDL_ReleaseGPUBuffer(self.device, buf);
    }
};

pub const SystemContext = struct {
    dt: f32,
    renderer: *Renderer,
    active_camera: ?Entity,
    event: ?*const sdl.SDL_Event,

    pub fn getKeyboardState(ctx: *const SystemContext) []const bool {
        _ = ctx;
        var numkeys: c_int = 0;
        const state = sdl.SDL_GetKeyboardState(&numkeys);
        return state[0..@intCast(numkeys)];
    }
};

pub const SystemStage = enum {
    event,
    update,
    render,
};
