const std = @import("std");

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);
pub const Mat4 = [16]f32;

pub const pi: f32 = std.math.pi;

pub fn vec2Add(a: Vec2, b: Vec2) Vec2 {
    return a + b;
}

pub fn vec2Sub(a: Vec2, b: Vec2) Vec2 {
    return a - b;
}

pub fn vec2Scale(v: Vec2, s: f32) Vec2 {
    return v * @as(Vec2, @splat(s));
}

pub fn vec2Normalize(v: Vec2) Vec2 {
    const len = @sqrt(vec2Dot(v, v));
    if (len == 0) return .{ 0, 0 };
    return v / @as(Vec2, @splat(len));
}

pub fn vec2Dot(a: Vec2, b: Vec2) f32 {
    return @reduce(.Add, a * b);
}

pub fn vec2Cross(a: Vec2, b: Vec2) f32 {
    return a[0] * b[1] - a[1] * b[0];
}

pub fn vec3Add(a: Vec3, b: Vec3) Vec3 {
    return a + b;
}

pub fn vec3Sub(a: Vec3, b: Vec3) Vec3 {
    return a - b;
}

pub fn vec3Scale(v: Vec3, s: f32) Vec3 {
    return v * @as(Vec3, @splat(s));
}

pub fn vec3Normalize(v: Vec3) Vec3 {
    const len = @sqrt(vec3Dot(v, v));
    if (len == 0) return .{ 0, 0, 0 };
    return v / @as(Vec3, @splat(len));
}

pub fn vec3Dot(a: Vec3, b: Vec3) f32 {
    return @reduce(.Add, a * b);
}

pub fn vec3Cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn vec4Add(a: Vec4, b: Vec4) Vec4 {
    return a + b;
}

pub fn vec4Sub(a: Vec4, b: Vec4) Vec4 {
    return a - b;
}

pub fn vec4Scale(v: Vec4, s: f32) Vec4 {
    return v * @as(Vec4, @splat(s));
}

pub fn vec4Normalize(v: Vec4) Vec4 {
    const len = @sqrt(vec4Dot(v, v));
    if (len == 0) return .{ 0, 0, 0, 1 };
    return v / @as(Vec4, @splat(len));
}

pub fn vec4Dot(a: Vec4, b: Vec4) f32 {
    return @reduce(.Add, a * b);
}

pub fn quatFromEuler(euler: Vec3) Vec4 {
    const cy = @cos(euler[1] * 0.5);
    const sy = @sin(euler[1] * 0.5);
    const cp = @cos(euler[0] * 0.5);
    const sp = @sin(euler[0] * 0.5);
    const cr = @cos(euler[2] * 0.5);
    const sr = @sin(euler[2] * 0.5);

    return .{
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy,
    };
}

pub fn eulerFromQuat(q: Vec4) Vec3 {
    const sinr_cosp = 2 * (q[3] * q[0] + q[1] * q[2]);
    const cosr_cosp = 1 - 2 * (q[0] * q[0] + q[1] * q[1]);
    const roll = std.math.atan2(sinr_cosp, cosr_cosp);

    const sinp = 2 * (q[3] * q[1] - q[2] * q[0]);
    var pitch: f32 = undefined;
    if (@abs(sinp) >= 1) {
        pitch = std.math.copysign(pi / 2, sinp);
    } else {
        pitch = std.math.asin(sinp);
    }

    const siny_cosp = 2 * (q[3] * q[2] + q[0] * q[1]);
    const cosy_cosp = 1 - 2 * (q[1] * q[1] + q[2] * q[2]);
    const yaw = std.math.atan2(siny_cosp, cosy_cosp);

    return .{ pitch, yaw, roll };
}

pub fn quatMultiply(a: Vec4, b: Vec4) Vec4 {
    return .{
        a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
        a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
        a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
        a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
    };
}

pub fn quatConjugate(q: Vec4) Vec4 {
    return .{ -q[0], -q[1], -q[2], q[3] };
}

pub fn quatNormalize(q: Vec4) Vec4 {
    return vec4Normalize(q);
}

pub fn quatFromAxisAngle(axis: Vec3, angle: f32) Vec4 {
    const half_angle = angle * 0.5;
    const s = @sin(half_angle);
    const norm_axis = vec3Normalize(axis);
    return .{ norm_axis[0] * s, norm_axis[1] * s, norm_axis[2] * s, @cos(half_angle) };
}

pub fn vec3Rotate(q: Vec4, v: Vec3) Vec3 {
    const qv: Vec3 = .{ q[0], q[1], q[2] };
    const uv = vec3Cross(qv, v);
    const uuv = vec3Cross(qv, uv);
    const w = q[3];
    return v + vec3Scale(uv, 2 * w) + vec3Scale(uuv, 2);
}

pub fn mat4Identity(m: *Mat4) void {
    @memset(m, 0);
    m[0] = 1;
    m[5] = 1;
    m[10] = 1;
    m[15] = 1;
}

pub fn mat4Translate(m: *Mat4, v: Vec3) void {
    const t: Mat4 = .{
        1,    0,    0,    0,
        0,    1,    0,    0,
        0,    0,    1,    0,
        v[0], v[1], v[2], 1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &t);
    m.* = result;
}

pub fn mat4RotateX(m: *Mat4, angle: f32) void {
    const c = @cos(angle);
    const s = @sin(angle);
    const r: Mat4 = .{
        1, 0,  0, 0,
        0, c,  s, 0,
        0, -s, c, 0,
        0, 0,  0, 1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &r);
    m.* = result;
}

pub fn mat4RotateY(m: *Mat4, angle: f32) void {
    const c = @cos(angle);
    const s = @sin(angle);
    const r: Mat4 = .{
        c, 0, -s, 0,
        0, 1, 0,  0,
        s, 0, c,  0,
        0, 0, 0,  1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &r);
    m.* = result;
}

pub fn mat4RotateZ(m: *Mat4, angle: f32) void {
    const c = @cos(angle);
    const s = @sin(angle);
    const r: Mat4 = .{
        c,  s, 0, 0,
        -s, c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &r);
    m.* = result;
}

pub fn mat4RotateQuat(m: *Mat4, q: Vec4) void {
    const qn = quatNormalize(q);
    const xx = qn[0] * qn[0];
    const yy = qn[1] * qn[1];
    const zz = qn[2] * qn[2];
    const xy = qn[0] * qn[1];
    const xz = qn[0] * qn[2];
    const yz = qn[1] * qn[2];
    const wx = qn[3] * qn[0];
    const wy = qn[3] * qn[1];
    const wz = qn[3] * qn[2];

    const r: Mat4 = .{
        1 - 2 * (yy + zz), 2 * (xy + wz),     2 * (xz - wy),     0,
        2 * (xy - wz),     1 - 2 * (xx + zz), 2 * (yz + wx),     0,
        2 * (xz + wy),     2 * (yz - wx),     1 - 2 * (xx + yy), 0,
        0,                 0,                 0,                 1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &r);
    m.* = result;
}

pub fn mat4Scale(m: *Mat4, v: Vec3) void {
    const s: Mat4 = .{
        v[0], 0,    0,    0,
        0,    v[1], 0,    0,
        0,    0,    v[2], 0,
        0,    0,    0,    1,
    };
    var result: Mat4 = undefined;
    mat4Multiply(&result, m, &s);
    m.* = result;
}

pub fn mat4Multiply(out: *Mat4, a: *const Mat4, b: *const Mat4) void {
    var result: Mat4 = undefined;
    for (0..4) |col| {
        for (0..4) |row| {
            var sum: f32 = 0;
            for (0..4) |k| {
                sum += a[k * 4 + row] * b[col * 4 + k];
            }
            result[col * 4 + row] = sum;
        }
    }
    out.* = result;
}

pub fn mat4Perspective(m: *Mat4, fov_rad: f32, aspect: f32, near: f32, far: f32) void {
    @memset(m, 0);
    const tan_half_fov = @tan(fov_rad * 0.5);
    m[0] = 1 / (aspect * tan_half_fov);
    m[5] = 1 / tan_half_fov;
    m[10] = -(far + near) / (far - near);
    m[11] = -1;
    m[14] = -(2 * far * near) / (far - near);
}
