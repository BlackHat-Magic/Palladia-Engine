#include <stdlib.h>
#include <math.h>

#include <ecs/ecs.h>
#include <geometry/octahedron.h>
#include <math/matrix.h>

PAL_MeshComponent*
PAL_CreateOctahedronMesh (const PAL_OctahedronMeshCreateInfo* info) {
    const Uint32 num_vertices = 6;
    float vertices[6 * 8] = {0};
    vec3 pos[6] = {
        {0.0f, 1.0f, 0.0f},  // 0: north pole
        {1.0f, 0.0f, 0.0f},  // 1
        {0.0f, 0.0f, 1.0f},  // 2
        {-1.0f, 0.0f, 0.0f}, // 3
        {0.0f, 0.0f, -1.0f}, // 4
        {0.0f, -1.0f, 0.0f}  // 5: south pole
    };

    for (Uint32 i = 0; i < 6; i++) {
        pos[i] = vec3_normalize (pos[i]);
        pos[i] = vec3_scale (pos[i], info->radius);
        vertices[i * 8 + 0] = pos[i].x;
        vertices[i * 8 + 1] = pos[i].y;
        vertices[i * 8 + 2] = pos[i].z;
        vertices[i * 8 + 3] = 0.0f; // nx (placeholder)
        vertices[i * 8 + 4] = 0.0f; // ny
        vertices[i * 8 + 5] = 0.0f; // nz

        // Spherical UV mapping
        float u = 0.5f + atan2f (pos[i].z, pos[i].x) / (2.0f * (float) M_PI);
        float v = acosf (pos[i].y) / (float) M_PI;
        vertices[i * 8 + 6] = u;
        vertices[i * 8 + 7] = v;
    }

    Uint32 indices[] = {0, 2, 1, // Clockwise for outwards normal
                        0, 3, 2, 0, 4, 3, 0, 1, 4, 5, 1,
                        2, 5, 2, 3, 5, 3, 4, 5, 4, 1};

    // Compute normals
    PAL_ComputeNormals (
        vertices, num_vertices, indices, sizeof (indices) / sizeof (Uint32), 8,
        0, 3
    );

    Uint64 vertices_size = sizeof (vertices);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size);
    if (vbo == NULL) return NULL;

    Uint64 indices_size = sizeof (indices);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size);
    if (ibo == NULL) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        return NULL;
    }

    PAL_MeshComponent* mesh = malloc (sizeof (PAL_MeshComponent));
    if (mesh == NULL) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        SDL_ReleaseGPUBuffer (info->device, ibo);
        return NULL;
    }
    *mesh =
        (PAL_MeshComponent) {.vertex_buffer = vbo,
                             .num_vertices = num_vertices,
                             .index_buffer = ibo,
                             .num_indices = sizeof (indices) / sizeof (Uint32),
                             .index_size = SDL_GPU_INDEXELEMENTSIZE_32BIT};

    return mesh;
}