const sdl = @import("../sdl.zig").c;

const Vec4 = @Vector(4, f32);

pub const PointLightComponent = sdl.SDL_FColor;
pub const PointLight = struct {
    position: Vec4,
    color: sdl.SDL_FColor,
};
