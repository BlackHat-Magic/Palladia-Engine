#version 450

layout(location = 0) in vec3 fragColor;
layout (location = 1) in vec2 TexCoord;
layout (location = 2) in vec3 Normal;
layout (location = 3) in vec3 FragPos;

struct AmbientLight {
    vec4 color; // rgb, a is intensity
};
struct PointLight {
    vec4 position;  // xyz + padding
    vec4 color;     // rgb + intensity
};

// Set 2: samplers, SSBOs
layout (set = 2, binding = 0) uniform sampler2D texture1;
layout (std430, set = 2, binding = 1) buffer AmbientBuffer {
    AmbientLight ambients[];
};
layout (std430, set = 2, binding = 2) buffer PointBuffer {
    PointLight points[];
};

// Frame UBO(s)
layout (std140, set = 3, binding = 0) uniform FrameUBO {
    vec4 cam_pos;
    vec4 cam_rot;
    Uint32 ambient_count;
    Uint32 point_count;
    Uint32 pad0; Uint32 pad1; // std140 padding
} ubo;

// output color
layout (location = 0) out vec4 outColor;

void main() {
    vec4 texColor = texture(texture1, TexCoord);
    vec3 objectColor = texColor.rgb * fragColor;
    vec3 view_xyz = ubo.cam_pos.xyz;
    vec3 norm = normalize(Normal);

    vec3 ambient_sum = vec3(0.0);

    // ambient lights
    for (Uint32 i = 0; i < ubo.ambient_count; i++) {
        float intensity = ambients[i].color.a;
        vec3 rgb = ambients[i].color.rgb;

        ambient_sum += intensity * rgb * objectColor;
    }

    // point lights
    vec3 diffuse_sum = vec3(0.0);
    vec3 specular_sum = vec3(0.0);
    for (Uint32 i = 0; i < ubo.point_count; i++) {
        float intensity = points[i].color.a;
        vec3 point_xyz = points[i].position.xyz;
        vec3 light_dir = normalize(point_xyz - FragPos);
        float light_dist = length(point_xyz - FragPos); // TODO: distance attenuation
        vec3 point_rgb = points[i].color.rgb;

        // diffuse
        float diff = max(dot(norm, light_dir), 0.0);
        diffuse_sum += intensity * point_rgb * diff * objectColor;

        // specular
        vec3 view_dir = normalize(view_xyz - FragPos);
        vec3 reflection_dir = reflect(-light_dir, norm);
        float spec = pow(max(dot(view_dir, reflection_dir), 0.0), 256);
        specular_sum += 0.5 * spec * point_rgb;
    }

    // Combine
    vec3 result = ambient_sum + diffuse_sum + specular_sum;
    outColor = vec4(result, texColor.a);
}