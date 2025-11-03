#include <stdlib.h>

#include <geometry/g_common.h>
#include <geometry/plane.h>

PAL_MeshComponent* PAL_CreatePlaneMesh (const PAL_PlaneMeshCreateInfo* info) {
    Uint32 width_segments = info->width_segments;
    Uint32 height_segments = info->height_segments;
    if (width_segments < 1) width_segments = 1;
    if (height_segments < 1) height_segments = 1;

    Uint32 num_vertices =
        (width_segments + 1) * (height_segments + 1);
    Uint32 num_indices = width_segments * height_segments * 6;

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos.x,y,z + normal.x,y,z + uv.u,v
    if (vertices == NULL) return NULL;

    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (indices == NULL) {
        free (vertices);
        return NULL;
    }

    // Generate vertices (grid in XY, Z=0)
    float half_width = info->width / 2.0f;
    float half_height = info->height / 2.0f;
    Uint32 vertex_idx = 0;
    for (Uint32 iy = 0; iy <= height_segments; iy++) {
        float v = (float) iy / (float) height_segments;
        float y_pos = -half_height + (info->height * v); // Y increases upward
        for (Uint32 ix = 0; ix <= width_segments; ix++) {
            float u = (float) ix / (float) width_segments;
            float x_pos = -half_width + (info->width * u);

            vertices[vertex_idx++] = x_pos;
            vertices[vertex_idx++] = y_pos;
            vertices[vertex_idx++] = 0.0f;
            vertices[vertex_idx++] = 0.0f; // nx
            vertices[vertex_idx++] = 0.0f; // ny
            vertices[vertex_idx++] = 1.0f; // nz
            vertices[vertex_idx++] = u;
            vertices[vertex_idx++] =
                1.0f - v; // Flip V for standard texture coord (0 at bottom)
        }
    }

    // Generate indices (two triangles per grid cell, clockwise)
    Uint32 index_idx = 0;
    for (Uint32 iy = 0; iy < height_segments; iy++) {
        for (Uint32 ix = 0; ix < width_segments; ix++) {
            Uint32 a = iy * (width_segments + 1) + ix;
            Uint32 b = iy * (width_segments + 1) + ix + 1;
            Uint32 c = (iy + 1) * (width_segments + 1) + ix + 1;
            Uint32 d = (iy + 1) * (width_segments + 1) + ix;

            // Triangle 1: a -> b -> c (clockwise)
            indices[index_idx++] = a;
            indices[index_idx++] = b;
            indices[index_idx++] = c;

            // Triangle 2: a -> c -> d (clockwise)
            indices[index_idx++] = a;
            indices[index_idx++] = c;
            indices[index_idx++] = d;
        }
    }

    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size);
    free (vertices);
    if (vbo == NULL) {
        free (indices);
        return NULL;
    }

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size);
    free (indices);
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
                                 .num_indices = num_indices,
                                 .index_size = SDL_GPU_INDEXELEMENTSIZE_16BIT};

    return mesh;
}