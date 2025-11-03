#include <stdlib.h>

#include <geometry/g_common.h>
#include <geometry/plane.h>

PAL_MeshComponent create_plane_mesh (
    float width,
    float height,
    int width_segments,
    int height_segments,
    SDL_GPUDevice* device
) {
    PAL_MeshComponent null_mesh = (PAL_MeshComponent) {0};
    if (width_segments < 1) width_segments = 1;
    if (height_segments < 1) height_segments = 1;

    int num_vertices = (width_segments + 1) * (height_segments + 1);
    int num_indices = width_segments * height_segments * 6;

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos.x,y,z + normal.x,y,z + uv.u,v
    if (!vertices) {
        SDL_Log ("Failed to allocate vertices for plane mesh");
        return null_mesh;
    }

    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (!indices) {
        SDL_Log ("Failed to allocate indices for plane mesh");
        free (vertices);
        return null_mesh;
    }

    // Generate vertices (grid in XY, Z=0)
    float half_width = width / 2.0f;
    float half_height = height / 2.0f;
    int vertex_idx = 0;
    for (int iy = 0; iy <= height_segments; iy++) {
        float v = (float) iy / (float) height_segments;
        float y_pos = -half_height + (height * v); // Y increases upward
        for (int ix = 0; ix <= width_segments; ix++) {
            float u = (float) ix / (float) width_segments;
            float x_pos = -half_width + (width * u);

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
    int index_idx = 0;
    for (int iy = 0; iy < height_segments; iy++) {
        for (int ix = 0; ix < width_segments; ix++) {
            Uint32 a = (Uint32) (iy * (width_segments + 1) + ix);
            Uint32 b = (Uint32) (iy * (width_segments + 1) + ix + 1);
            Uint32 c = (Uint32) ((iy + 1) * (width_segments + 1) + ix + 1);
            Uint32 d = (Uint32) ((iy + 1) * (width_segments + 1) + ix);

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

    SDL_GPUBuffer* vbo = NULL;
    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    int vbo_failed = PAL_UploadVertices (device, vertices, vertices_size, &vbo);
    free (vertices);
    if (vbo_failed) {
        free (indices);
        return null_mesh; // logging handled in PAL_UploadVertices()
    }

    SDL_GPUBuffer* ibo = NULL;
    Uint64 indices_size = num_indices * sizeof (Uint32);
    int ibo_failed = PAL_UploadIndices (device, indices, indices_size, &ibo);
    free (indices);
    if (ibo_failed) {
        return null_mesh; // logging handled in PAL_UploadIndices()
    }

    PAL_MeshComponent out_mesh =
        (PAL_MeshComponent) {.vertex_buffer = vbo,
                         .num_vertices = (Uint32) num_vertices,
                         .index_buffer = ibo,
                         .num_indices = (Uint32) num_indices,
                         .index_size = SDL_GPU_INDEXELEMENTSIZE_16BIT};

    return out_mesh;
}