const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const ecs = @import("ecs");

const BoxMeshCreateInfo = struct {
    l: f32,
    w: f32,
    h: f32,
    device: SDL_GPUDevice,
};
