#include <math.h>
#include <stdlib.h>

#include <geometry/lathe.h>
#include <geometry/sphere.h>

PAL_MeshComponent create_sphere_mesh (
    float radius,
    Uint32 width_segments,
    Uint32 height_segments,
    float phi_start,
    float phi_length,
    float theta_start,
    float theta_length,
    SDL_GPUDevice* device
) {
    PAL_MeshComponent null_mesh = (PAL_MeshComponent) {0};
    if (width_segments < 3 || height_segments < 2) {
        SDL_Log (
            "Sphere must have at least 3 width segments and 2 height segments"
        );
        return null_mesh;
    }

    Uint32 num_points = height_segments + 1;
    vec2* points = (vec2*) malloc (num_points * sizeof (vec2));
    if (!points) {
        SDL_Log ("Failed to allocate points for sphere path");
        return null_mesh;
    }

    for (Uint32 i = 0; i < num_points; i++) {
        float frac = (float) i / (float) height_segments;
        float theta =
            theta_start +
            (1.0f - frac) * theta_length; // Reversed to start from bottom
                                          // (theta max) to top (theta min)
        points[i].x = radius * sinf (theta);
        points[i].y = radius * cosf (theta);
    }

    // lathe returns normals
    PAL_MeshComponent mesh = PAL_CreateLatheMesh (
        points, num_points, width_segments, phi_start, phi_length, device
    );
    free (points);
    return mesh;
}