#include <math.h>
#include <stdlib.h>

#include <ecs/ecs.h>
#include <geometry/lathe.h>

PAL_MeshComponent*
PAL_CreateCapsuleMesh (static PAL_CapsuleMeshCreateInfo* info) {
    if (info->cap_segments < 1) info->cap_segments = 1;

    int num_points = (info->cap_segments + 1) * 2;
    if (info->height <= 0.0f) num_points -= 1;

    vec2* points = (vec2*) malloc (num_points * sizeof (vec2));
    if (points == NULL) return NULL;

    float half_height = info->height * 0.5f;
    int idx = 0;

    for (int i = 0; i <= info->cap_segments; i++) {
        float theta = (float) i / (float) cap_segments * (float) M_PI * 0.5f;
        points[idx].x = info->radius * sinf (theta);
        points[idx].y = -half_height - info->radius * cosf (theta);
        idx++;
    }

    int top_start =
        (info->height <= 0.0f) ? info->cap_segments - 1 : info->cap_segments;
    for (int i = top_start; i >= 0; i--) {
        float theta =
            (float) i / (float) info->cap_segments * (float) M_PI * 0.5f;
        points[idx].x = info->radius * sinf (theta);
        points[idx].y = half_height + info->radius * cosf (theta);
        if (i < top_start || info->height > 0.0f) {
            idx++;
        }
    }

    PAL_LatheMeshCreateInfo = {
        .path = points,
        .path_length = num_points,
        .segmenst = info->radial_segments,
        .phi_start = 0.0f,
        .phi_length = (float) M_PI * 2.0f,
        .device = info->device
    };
    PAL_MeshComponent* mesh = PAL_CreateLatheMesh (&PAL_LatheMeshCreateInfo);
    free (points);
    if (mesh == NULL) return NULL;
    return mesh;
}