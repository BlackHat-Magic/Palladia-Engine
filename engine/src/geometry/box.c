#include <ecs/ecs.h>
#include <geometry/box.h>
#include <geometry/g_common.h>

PAL_MeshComponent* PAL_CreateBoxMesh (PAL_BoxMeshCreateInfo* info) {
    PAL_MeshComponent out_mesh = malloc (sizeof (PAL_MeshComponent));
    if (PAL_MeshComponent == NULL) {
        return NULL;
    }

    float wx = info->w / 2.0f;
    float hy = info->h / 2.0f;
    float lz = info->l / 2.0f;

    float vertices[24 * 8] = {
        // front (-z)
        -wx, -hy, -lz, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, wx, -hy, -lz, 0.0f, 0.0f,
        0.0f, 1.0f, 1.0f, wx, hy, -lz, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, -wx, hy,
        -lz, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,

        // back
        -wx, -hy, lz, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, wx, -hy, lz, 0.0f, 0.0f,
        0.0f, 1.0f, 1.0f, wx, hy, lz, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, -wx, hy, lz,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,

        // Left (x = -wx)
        -wx, hy, -lz, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, -wx, hy, lz, 0.0f, 0.0f,
        0.0f, 1.0f, 1.0f, -wx, -hy, lz, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, -wx, -hy,
        -lz, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,

        // Right (x = wx)
        wx, hy, -lz, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, wx, -hy, -lz, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, wx, -hy, lz, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, wx, hy, lz,
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f,

        // Top (y = hy)
        -wx, hy, -lz, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, wx, hy, -lz, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, wx, hy, lz, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, -wx, hy, lz,
        0.0f, 0.0f, 0.0f, 0.0f, 1.0f,

        // Bottom (y = -hy)
        -wx, -hy, -lz, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, -wx, -hy, lz, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, wx, -hy, lz, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, wx, -hy,
        -lz, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f
    };

    // 36 indices: 6 per face (2 triangles each), clockwise winding
    Uint16 indices[] = {
        // Front
        0, 2, 1, 2, 0, 3,
        // Back (unchanged)
        4, 5, 6, 6, 7, 4,
        // Left
        9, 8, 11, 11, 10, 9,
        // Right
        15, 13, 12, 13, 15, 14,
        // Top
        16, 18, 17, 18, 16, 19,
        // Bottom (unchanged)
        20, 23, 22, 22, 21, 20
    };

    compute_vertex_normals (vertices, 24, indices, 36, 8, 0, 3);

    Uint64 vertices_size = sizeof (vertices);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size);
    if (vbo == NULL) return NULL; // caller handles logging

    Uint64 indices_size = sizeof (indices);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size, &ibo);
    if (ibo == NULL) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        return NULL; // caller handles logging
    }

    out_mesh->vertex_buffer = vbo;
    out_mesh->num_vertices = 24;
    out_mesh->index_buffer = ibo;
    out_mesh->num_indices = 36;
    out_mesh->index_size = SDL_GPU_INDEXELEMENTSIZE_16BIT;

    return out_mesh;
}