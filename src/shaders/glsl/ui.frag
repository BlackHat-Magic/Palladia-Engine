#version 450

layout(location = 0) in vec4 vColor;
layout(location = 1) in vec2 vUV;
layout(location = 2) in vec2 vLocalPos;
layout(location = 3) in vec2 vHalfSize;
layout(location = 4) in float vCornerRadius;
layout(location = 5) in float vBorderThickness;
layout(location = 6) in float vFilled;

// TODO: figure out why this needs to be 2.
layout(set = 2, binding = 0) uniform sampler2D uTex;

layout(location = 0) out vec4 outColor;

void main() {
    if (vCornerRadius > 0.0 || vBorderThickness > 0.0) {
        vec2 d = abs(vLocalPos) - vHalfSize + vCornerRadius;
        float outer_dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - vCornerRadius;

        if (vFilled < 0.5) {
            float inner_bt = min(vBorderThickness, min(vHalfSize.x, vHalfSize.y));
            float inner_cr = max(vCornerRadius - inner_bt, 0.0);
            vec2 inner_d = abs(vLocalPos) - vHalfSize + inner_bt;
            float inner_dist = length(max(inner_d, 0.0)) + min(max(inner_d.x, inner_d.y), 0.0) - inner_cr;
            if (outer_dist > 0.0 || inner_dist < 0.0) discard;
        } else {
            if (outer_dist > 0.0) discard;
        }
    }
    vec4 texel = texture(uTex, vUV);
    outColor = vColor * texel;
}
