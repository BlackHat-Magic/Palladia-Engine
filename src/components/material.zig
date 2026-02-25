const sdl = @import("../sdl.zig").c;

pub const MaterialComponent = struct {
    color: sdl.SDL_FColor,
    emissive: sdl.SDL_FColor,
    texture: *sdl.SDL_GPUTexture,
    sampler: ?*sdl.SDL_GPUSampler,
    vertex_shader: *sdl.SDL_GPUShader,
    fragment_shader: *sdl.SDL_GPUShader,
    pipeline: *sdl.SDL_GPUGraphicsPipeline,
};
