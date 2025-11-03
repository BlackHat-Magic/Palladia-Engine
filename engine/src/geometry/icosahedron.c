#include <math.h>
#include <stdlib.h>

#include <geometry/icosahedron.h>
#include <math/matrix.h>

PAL_MeshComponent*
PAL_CreateIcosahedronMesh (static PAL_IcosahedronMeshCreateInfo* info) {
    const Uint32 num_vertices = 12;
    float* vertices = (float*) malloc (num_vertices * 8 * sizeof (float));
    if (vertices == NULL) return NULL;

    float t = (1.0f + sqrtf (5.0f)) / 2.0f;
    vec3 pos[12] = {
        {-1.0f, t, 0.0f},  // 0
        {1.0f, t, 0.0f},   // 1
        {-1.0f, -t, 0.0f}, // 2
        {1.0f, -t, 0.0f},  // 3
        {0.0f, -1.0f, t},  // 4
        {0.0f, 1.0f, t},   // 5
        {0.0f, -1.0f, -t}, // 6
        {0.0f, 1.0f, -t},  // 7
        {t, 0.0f, -1.0f},  // 8
        {t, 0.0f, 1.0f},   // 9
        {-t, 0.0f, -1.0f}, // 10
        {-t, 0.0f, 1.0f}   // 11
    };

    Uint32 vertex_idx = 0;
    for (Uint32 i = 0; i < 12; i++) {
        pos[i] = vec3_normalize (pos[i]);
        pos[i] = vec3_scale (pos[i], info->radius);
        vertices[vertex_idx++] = pos[i].x;
        vertices[vertex_idx++] = pos[i].y;
        vertices[vertex_idx++] = pos[i].z;
        vertices[vertex_idx++] = 0.0f; // nx (placeholder)
        vertices[vertex_idx++] = 0.0f; // ny
        vertices[vertex_idx++] = 0.0f; // nz

        // Spherical UV mapping
        float u = 0.5f + atan2f (pos[i].z, pos[i].x) / (2.0f * (float) M_PI);
        float v = acosf (pos[i].y) / (float) M_PI;
        vertices[vertex_idx++] = u;
        vertices[vertex_idx++] = v;
    }

    Uint32 indices[] = {11, 5,  0, 5,  1, 0,  1, 7, 0,  7, 10, 0,  10,
                        11, 0,  5, 9,  1, 11, 4, 5, 10, 2, 11, 10, 2,
                        7,  10, 6, 7,  1, 8,  7, 9, 4,  3, 4,  2,  3,
                        2,  6,  3, 6,  8, 3,  8, 9, 3,  9, 5,  4,  4,
                        11, 2,  2, 10, 6, 6,  7, 8, 8,  1, 9};

    // Note: The indices in the original code seem incomplete or erroneous (only
    // 60 indices but listed less); assuming standard icosahedron indices
    // Standard icosahedron has 20 faces, 60 indices. Here using a corrected
    // list:
    Uint32 standard_indices[60] = {0,  5,  1,  0, 1, 7,  0, 7,  10, 0,  10, 11,
                                   0,  11, 5,  1, 5, 9,  5, 11, 4,  11, 10, 2,
                                   10, 7,  6,  7, 1, 8,  3, 9,  4,  3,  4,  2,
                                   3,  2,  6,  3, 6, 8,  3, 8,  9,  4,  9,  5,
                                   2,  4,  11, 6, 2, 10, 8, 6,  7,  9,  8,  1};

    // Compute normals using standard_indices
    PAL_ComputeNormals (vertices, num_vertices, standard_indices, 60, 8, 0, 3);

    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size, &vbo);
    free (vertices);
    if (vbo == NULL) return NULL;

    Uint64 indices_size = 60 * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, standard_indices, indices_size, &ibo);
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
    *mesh = (PAL_MeshComponent) {.vertex_buffer = vbo,
                                 .num_vertices = num_vertices,
                                 .index_buffer = ibo,
                                 .num_indices = 60,
                                 .index_size = SDL_GPU_INDEXELEMENTSIZE_32BIT};

    return mesh;
}