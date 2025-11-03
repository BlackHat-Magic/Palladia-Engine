#include <math.h>
#include <stdlib.h>

#include <ecs/ecs.h>
#include <geometry/dodecahedron.h>
#include <geometry/g_common.h>
#include <math/matrix.h>

PAL_MeshComponent*
PAL_CreateDodecahedronMesh (static PAL_DodecahedronMeshCreateInfo* info) {
    float phi = (1.0f + sqrtf (5.0f)) / 2.0f;
    float phi_inv = 1.0f / phi;

    float raw_verts[20 * 3] = {
        1.0f,    1.0f,  1.0f,     1.0f,     1.0f,  -1.0f,    1.0f,
        -1.0f,   1.0f,  1.0f,     -1.0f,    -1.0f, -1.0f,    1.0f,
        1.0f,    -1.0f, 1.0f,     -1.0f,    -1.0f, -1.0f,    1.0f,
        -1.0f,   -1.0f, -1.0f,    phi_inv,  phi,   0.0f,     -phi_inv,
        phi,     0.0f,  phi_inv,  -phi,     0.0f,  -phi_inv, -phi,
        0.0f,    phi,   0.0f,     phi_inv,  phi,   0.0f,     -phi_inv,
        -phi,    0.0f,  phi_inv,  -phi,     0.0f,  -phi_inv, 0.0f,
        phi_inv, phi,   0.0f,     -phi_inv, phi,   0.0f,     phi_inv,
        -phi,    0.0f,  -phi_inv, -phi
    };

    Uint32 num_vertices = 20;
    float* vertices = (float*) malloc (num_vertices * 8 * sizeof (float));
    if (vertices == NULL) return NULL;

    Uint32 vertex_idx = 0;
    for (Uint32 i = 0; i < num_vertices; i++) {
        vec3 pos = {
            raw_verts[i * 3], raw_verts[i * 3 + 1], raw_verts[i * 3 + 2]
        };
        float len = sqrtf (pos.x * pos.x + pos.y * pos.y + pos.z * pos.z);
        pos = vec3_scale (pos, info->radius / len);

        vertices[vertex_idx++] = pos.x;
        vertices[vertex_idx++] = pos.y;
        vertices[vertex_idx++] = pos.z;
        vertices[vertex_idx++] = 0.0f; // nx (placeholder)
        vertices[vertex_idx++] = 0.0f; // ny
        vertices[vertex_idx++] = 0.0f; // nz

        // Spherical UV mapping using normalized position
        vec3 norm_pos = vec3_scale (pos, 1.0f / info->radius);
        float u =
            0.5f + atan2f (norm_pos.z, norm_pos.x) / (2.0f * (float) M_PI);
        float v = acosf (norm_pos.y) / (float) M_PI;
        vertices[vertex_idx++] = u;
        vertices[vertex_idx++] = v;
    }

    Uint32 num_indices = 108;
    Uint32 indices[108] = {
        1, 8,  0, 0, 12, 13, 13, 1, 0, 4, 9,  5, 5, 15, 14, 14, 4, 5,
        2, 10, 3, 3, 13, 12, 12, 2, 3, 7, 11, 6, 6, 14, 15, 15, 7, 6,
        2, 12, 0, 0, 16, 17, 17, 2, 0, 1, 13, 3, 3, 19, 18, 18, 1, 3,
        4, 14, 6, 6, 17, 16, 16, 4, 6, 7, 15, 5, 5, 18, 19, 19, 7, 5,
        4, 16, 0, 0, 8,  9,  9,  4, 0, 2, 17, 6, 6, 11, 10, 10, 2, 6,
        1, 18, 5, 5, 9,  8,  8,  1, 5, 7, 19, 3, 3, 10, 11, 11, 7, 3
    };

    // Compute normals
    PAL_ComputeNormals (vertices, num_vertices, indices, num_indices, 8, 0, 3);

    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size, &vbo);
    free (vertices);
    if (vbo == NULL) return NULL;

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size, &ibo);
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
                                 .num_vertices = (Uint32) num_vertices,
                                 .index_buffer = ibo,
                                 .num_indices = (Uint32) num_indices,
                                 .index_size = SDL_GPU_INDEXELEMENTSIZE_32BIT};

    return mesh;
}