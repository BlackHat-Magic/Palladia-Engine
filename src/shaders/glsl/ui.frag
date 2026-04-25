#version 450

layout(location = 0) in vec4 vColor;
layout(location = 1) in vec2 vUV;
layout(location = 2) in vec2 vLocalPos;
layout(location = 3) in vec2 vHalfSize;
layout(location = 4) in float vCornerRadius;

// TODO: figure out why this needs to be 2.
layout(set = 2, binding = 0) uniform sampler2D uTex;

layout(location = 0) out vec4 outColor;

void main() {
    if (vCornerRadius > 0.0) {
        vec2 d = abs(vLocalPos) - vHalfSize + vCornerRadius;
        float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - vCornerRadius;
        if (dist > 0.0) discard;
    }
    vec4 texel = texture(uTex, vUV);
    outColor = vColor * texel;
}
