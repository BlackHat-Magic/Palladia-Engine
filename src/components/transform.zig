const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);

pub const Transform = struct {
    position: Vec3 = .{ 0, 0, 0 },
    rotation: Vec4 = .{ 0, 0, 0, 1 },
    scale: Vec3 = .{ 1, 1, 1 },
};
