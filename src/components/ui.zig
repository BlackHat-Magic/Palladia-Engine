const sdl = @import("../sdl.zig").c;

const UIRect = struct {
    rect: sdl.SDL_FRect,
    color: sdl.SDL_FColor,
    texture: ?*sdl.SDL_GPUTexture,
};

pub const UIComponent = struct {
    rects: []UIRect,
    rect_count: usize,
    max_rects: usize,
    white_texture: *sdl.SDL_GPUTexture,
    sampler: *sdl.SDL_GPUSampler,

    // TODO: Add SDL_ttf dependency
    // font: *sdl.TTF_Font,

    vbo: *sdl.SDL_GPUBuffer,
    vbo_size: usize,
    ibo: *sdl.SDL_GPUBuffer,
    ibo_size: usize,

    vertex: *sdl.SDL_GPUShader,
    fragment: *sdl.SDL_GPUShader,
    pipeline: *sdl.SDL_GPUGraphicsPipeline,

    // TODO: Add microui dependency
    // mu_Context: sdl.mu_Context,
};
