#include <stdlib.h>

#include <geometry/cylinder.h>
#include <geometry/lathe.h>

PAL_MeshComponent*
PAL_CreateCylinderMesh (static PAL_CylinderMeshCreateInfo* info) {
    if (info->radial_segments < 3 || info->height_segments < 1) return NULL;

    // Calculate num_points: sides (info->height_segments + 1) + optional 2
    // centers
    Uint32 num_points = info->height_segments + 1;
    if (!info->open_ended) num_points += 2;

    vec2* points = (vec2*) malloc (num_points * sizeof (vec2));
    if (points == NULL) return NULL;

    Uint32 idx = 0;
    float half_height = info->height / 2.0f;

    // Bottom center (if closed)
    if (!info->open_ended) {
        points[idx++] = (vec2) {0.0f, -half_height};
    }

    // Bottom edge
    points[idx++] = (vec2) {info->radius_bottom, -half_height};

    // Intermediate side points (if info->height_segments > 1)
    for (Uint32 i = 1; i < info->height_segments; i++) {
        float frac = (float) i / (float) info->height_segments;
        points[idx++] =
            (vec2) {info->radius_bottom +
                        frac * (info->radius_top - info->radius_bottom),
                    -half_height + frac * info->height};
    }

    // Top edge
    points[idx++] = (vec2) {info->radius_top, half_height};

    // Top center (if closed)
    if (!info->open_ended) {
        points[idx++] = (vec2) {0.0f, half_height};
    }

    mesh = PAL_CreateLatheMesh (
        points, idx, info->radial_segments, info->theta_start,
        info->theta_length, info->device
    );
    free (points);
    return mesh;
}