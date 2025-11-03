#include <math.h>
#include <stdlib.h>

#include <ecs/ecs.h>
#include <geometry/lathe.h>
#include <geometry/capsule.h>

PAL_MeshComponent*
PAL_CreateCapsuleMesh (const PAL_CapsuleMeshCreateInfo* info) {
    Uint32 cap_segments = info->cap_segments;
    if (cap_segments < 1) cap_segments = 1;

    Uint32 num_points = (cap_segments + 1) * 2;
    if (info->height <= 0.0f) num_points -= 1;

    vec2* points = (vec2*) malloc (num_points * sizeof (vec2));
    if (points == NULL) return NULL;

    float half_height = info->height * 0.5f;
    Uint32 idx = 0;

    for (Uint32 i = 0; i <= cap_segments; i++) {
        float theta = (float) i / (float) cap_segments * (float) M_PI * 0.5f;
        points[idx].x = info->radius * sinf (theta);
        points[idx].y = -half_height - info->radius * cosf (theta);
        idx++;
    }

    Uint32 top_start = (info->height <= 0.0f) ? cap_segments - 1 : cap_segments;
    for (int i = (int) top_start; i >= 0; i--) {
        float theta =
            (float) i / (float) cap_segments * (float) M_PI * 0.5f;
        points[idx].x = info->radius * sinf (theta);
        points[idx].y = half_height + info->radius * cosf (theta);
        if (i < top_start || info->height > 0.0f) {
            idx++;
        }
    }

    PAL_LatheMeshCreateInfo lathe_info = {
        .path = points,
        .path_length = num_points,
        .segments = info->radial_segments,
        .phi_start = 0.0f,
        .phi_length = (float) M_PI * 2.0f,
        .device = info->device
    };
    PAL_MeshComponent* mesh = PAL_CreateLatheMesh (&lathe_info);
    free (points);
    if (mesh == NULL) return NULL;
    return mesh;
}