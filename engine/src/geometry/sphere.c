#include <math.h>
#include <stdlib.h>

#include <geometry/lathe.h>
#include <geometry/sphere.h>

PAL_MeshComponent*
PAL_CreateSphereMesh (static PAL_SphereMeshCreateInfo* info) {
    if (info->width_segments < 3 || info->height_segments < 2) return NULL;

    Uint32 num_points = info->height_segments + 1;
    vec2* points = (vec2*) malloc (num_points * sizeof (vec2));
    if (points == NULL) return NULL;

    for (Uint32 i = 0; i < num_points; i++) {
        float frac = (float) i / (float) info->height_segments;
        float theta = info->theta_start +
                      (1.0f - frac) *
                          info->theta_length; // Reversed to start from bottom
                                              // (theta max) to top (theta min)
        points[i].x = info->radius * sinf (theta);
        points[i].y = info->radius * cosf (theta);
    }

    // lathe returns normals
    PAL_MeshComponent mesh = PAL_CreateLatheMesh (
        points, num_points, info->width_segments, info->phi_start,
        info->phi_length, info->device
    );
    free (points);
    return mesh;
}