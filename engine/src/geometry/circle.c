#include <math.h>
#include <stdlib.h>

#include <geometry/circle.h>
#include <geometry/g_common.h>

PAL_MeshComponent*
PAL_CreateCircleMesh (static PAL_CircleMeshCreateInfo* info) {
    if (info->segments < 3) return NULL;

    Uint32 num_vertices = info->segments + 1; // Center + ring
    Uint32 num_indices = info->segments * 3;  // One triangle per segment

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos.x,y,z + normal.x,y,z + uv.u,v
    if (vertices == NULL) return NULL;

    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (!indices) {
        free (vertices);
        return NULL;
    }

    // Center vertex
    Uint32 vertex_idx = 0;
    vertices[vertex_idx++] = 0.0f; // x
    vertices[vertex_idx++] = 0.0f; // y
    vertices[vertex_idx++] = 0.0f; // z
    vertices[vertex_idx++] = 0.0f; // nx
    vertices[vertex_idx++] = 0.0f; // ny
    vertices[vertex_idx++] = 1.0f; // nz
    vertices[vertex_idx++] = 0.5f; // u
    vertices[vertex_idx++] = 0.5f; // v

    // Ring vertices
    for (Uint32 i = 0; i < info->segments; i++) {
        float theta = (float) i / (float) info->segments * 2.0f * (float) M_PI;
        float cos_theta = cosf (theta);
        float sin_theta = sinf (theta);

        vertices[vertex_idx++] = info->radius * cos_theta;
        vertices[vertex_idx++] = info->radius * sin_theta;
        vertices[vertex_idx++] = 0.0f;
        vertices[vertex_idx++] = 0.0f; // nx
        vertices[vertex_idx++] = 0.0f; // ny
        vertices[vertex_idx++] = 1.0f; // nz
        vertices[vertex_idx++] = 0.5f + 0.5f * cos_theta;
        vertices[vertex_idx++] =
            0.5f + 0.5f * sin_theta; // Note: may need to flip v (1.0f - ...)
                                     // based on texture orientation
    }

    // Indices (clockwise winding)
    Uint32 index_idx = 0;
    for (Uint32 i = 0; i < info->segments; i++) {
        indices[index_idx++] = 0;                // Center
        indices[index_idx++] = (Uint32) (i + 1); // Current ring vertex
        indices[index_idx++] = (Uint32) ((i + 1) % info->segments +
                                         1); // Next ring vertex (wrap around)
    }

    // Upload to GPU
    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size, &vbo);
    free (vertices);
    if (vbo == NULL) {
        free (indices);
        return NULL;
    }

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size, &ibo);
    free (indices);
    if (ibo_failed) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        return NULL
    }

    PAL_MeshComponent* mesh = malloc (sizeof (PAL_MeshComponent));
    if (mesh == NULL) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        SDL_ReleaseGPUBuffer (info->device, ibo);
        return NULL;
    }
    *mesh = (PAL_MeshComponent) {
        .vertex_buffer = vbo, .num_vertices = (Uint32) num_vertices,
        .index_buffer = ibo, .num_indices = (Uint32) num_indices,
        .index_size = SDL_GPU_INDEXELEMENTSIZE_32BIT
    }

    return mesh;
}