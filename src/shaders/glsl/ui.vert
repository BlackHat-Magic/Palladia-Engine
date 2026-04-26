#version 450

layout(location = 0) in vec2 offset;   // [-1,1] unit quad corner
layout(location = 1) in vec2 uv_in;

layout(location = 2) in vec2 center;
layout(location = 3) in vec2 half_size;
layout(location = 4) in float rot_cos;
layout(location = 5) in float rot_sin;
layout(location = 6) in vec4 color;
layout(location = 7) in float corner_radius;
layout(location = 8) in float border_thickness;
layout(location = 9) in float filled;

layout(std140, set = 1, binding = 0) uniform UIUniform {
    vec2 res;
};

layout(location = 0) out vec4 vColor;
layout(location = 1) out vec2 vUV;
layout(location = 2) out vec2 vLocalPos;
layout(location = 3) out vec2 vHalfSize;
layout(location = 4) out float vCornerRadius;
layout(location = 5) out float vBorderThickness;
layout(location = 6) out float vFilled;

void main() {
    vec2 rel = offset * half_size;
    vec2 rotated = vec2(rel.x * rot_cos - rel.y * rot_sin,
                        rel.x * rot_sin + rel.y * rot_cos);
    vec2 world_pos = center + rotated;

    float x = (world_pos.x / res.x) * 2.0 - 1.0;
    float y = (world_pos.y / res.y) * 2.0 - 1.0;
    y = -y;
    gl_Position = vec4(x, y, 0.0, 1.0);

    vColor = color;
    vUV = uv_in;
    vLocalPos = rel;
    vHalfSize = half_size;
    vCornerRadius = corner_radius;
    vBorderThickness = border_thickness;
    vFilled = filled;
}
