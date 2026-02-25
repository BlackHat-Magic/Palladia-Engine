const sdl = @import("../sdl.zig").c;

pub const Stage = enum {
    vertex,
    fragment,
};

pub const CreateError = error{
    InvalidSPIRV,
    CreationFailed,
};

pub fn Shader(comptime stage: Stage) type {
    return struct {
        handle: *sdl.SDL_GPUShader,

        const Self = @This();

        pub fn fromBytes(device: *sdl.SDL_GPUDevice, bytes: []const u8, entrypoint: [:0]const u8) CreateError!Self {
            const stage_flag: c_uint = switch (stage) {
                .vertex => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
                .fragment => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            };

            const info = sdl.SDL_GPUShaderCreateInfo{
                .code = bytes.ptr,
                .code_size = bytes.len,
                .entrypoint = entrypoint,
                .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
                .stage = stage_flag,
                .num_samplers = 0,
                .num_storage_textures = 0,
                .num_storage_buffers = 0,
                .num_uniform_buffers = 0,
            };

            const handle = sdl.SDL_CreateGPUShader(device, &info) orelse return CreateError.CreationFailed;
            return .{ .handle = handle };
        }

        pub fn fromBytesWithSamplers(device: *sdl.SDL_GPUDevice, bytes: []const u8, entrypoint: [:0]const u8, num_samplers: u32) CreateError!Self {
            const stage_flag: c_uint = switch (stage) {
                .vertex => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
                .fragment => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            };

            const info = sdl.SDL_GPUShaderCreateInfo{
                .code = bytes.ptr,
                .code_size = bytes.len,
                .entrypoint = entrypoint,
                .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
                .stage = stage_flag,
                .num_samplers = @intCast(num_samplers),
                .num_storage_textures = 0,
                .num_storage_buffers = 0,
                .num_uniform_buffers = 0,
            };

            const handle = sdl.SDL_CreateGPUShader(device, &info) orelse return CreateError.CreationFailed;
            return .{ .handle = handle };
        }

        pub fn fromBytesWithUniforms(device: *sdl.SDL_GPUDevice, bytes: []const u8, entrypoint: [:0]const u8, num_uniform_buffers: u32) CreateError!Self {
            const stage_flag: c_uint = switch (stage) {
                .vertex => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
                .fragment => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            };

            const info = sdl.SDL_GPUShaderCreateInfo{
                .code = bytes.ptr,
                .code_size = bytes.len,
                .entrypoint = entrypoint,
                .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
                .stage = stage_flag,
                .num_samplers = 0,
                .num_storage_textures = 0,
                .num_storage_buffers = 0,
                .num_uniform_buffers = @intCast(num_uniform_buffers),
            };

            const handle = sdl.SDL_CreateGPUShader(device, &info) orelse return CreateError.CreationFailed;
            return .{ .handle = handle };
        }

        pub fn fromBytesFull(device: *sdl.SDL_GPUDevice, bytes: []const u8, entrypoint: [:0]const u8, num_samplers: u32, num_storage_buffers: u32, num_uniform_buffers: u32) CreateError!Self {
            const stage_flag: c_uint = switch (stage) {
                .vertex => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
                .fragment => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            };

            const info = sdl.SDL_GPUShaderCreateInfo{
                .code = bytes.ptr,
                .code_size = bytes.len,
                .entrypoint = entrypoint,
                .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
                .stage = stage_flag,
                .num_samplers = @intCast(num_samplers),
                .num_storage_textures = 0,
                .num_storage_buffers = @intCast(num_storage_buffers),
                .num_uniform_buffers = @intCast(num_uniform_buffers),
            };

            const handle = sdl.SDL_CreateGPUShader(device, &info) orelse return CreateError.CreationFailed;
            return .{ .handle = handle };
        }

        pub fn deinit(self: Self, device: *sdl.SDL_GPUDevice) void {
            sdl.SDL_ReleaseGPUShader(device, self.handle);
        }
    };
}

pub const VertexShader = Shader(.vertex);
pub const FragmentShader = Shader(.fragment);
