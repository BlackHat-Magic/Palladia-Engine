#include <math.h>
#include <stdlib.h>

#include <geometry/g_common.h>
#include <geometry/ring.h>

PAL_MeshComponent* PAL_CreateRingMesh (static PAL_RingMeshCreateInfo* info) {
    if (info->theta_segments < 3) return NULL;
    if (info->phi_segments < 1) return NULL;
    if (info->inner_radius >= info->outer_radius) return NULL;

    Uint32 num_theta = info->theta_segments + 1;
    Uint32 num_phi = info->phi_segments + 1;
    Uint32 num_vertices = num_theta * num_phi;

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos.x,y,z + uv.u,v
    if (vertices == NULL) return NULL;

    Uint32 vertex_idx = 0;
    for (Uint32 i = 0; i < num_theta; i++) {
        float theta_frac = (float) i / (float) info->theta_segments;
        float theta = info->theta_start + theta_frac * info->theta_length;
        float cos_theta = cosf (theta);
        float sin_theta = sinf (theta);

        for (Uint32 j = 0; j < num_phi; j++) {
            float phi_frac = (float) j / (float) info->phi_segments;
            float radius = info->inner_radius +
                           phi_frac * (info->outer_radius - info->inner_radius);

            float x = radius * cos_theta;
            float y = radius * sin_theta;
            float z = 0.0f;

            float uv_x =
                (cos_theta * (radius / info->outer_radius) + 1.0f) * 0.5f;
            float uv_y =
                (sin_theta * (radius / info->outer_radius) + 1.0f) * 0.5f;

            vertices[vertex_idx++] = x;
            vertices[vertex_idx++] = y;
            vertices[vertex_idx++] = z;
            vertices[vertex_idx++] = 0.0f; // nx
            vertices[vertex_idx++] = 0.0f; // ny
            vertices[vertex_idx++] = 1.0f; // nz
            vertices[vertex_idx++] = uv_x;
            vertices[vertex_idx++] = uv_y;
        }
    }

    Uint32 num_indices = info->theta_segments * info->phi_segments * 6;
    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (indices == NULL) {
        free (vertices);
        return NULL;
    }

    Uint32 index_idx = 0;
    for (Uint32 i = 0; i < info->theta_segments; i++) {
        for (Uint32 j = 0; j < info->phi_segments; j++) {
            Uint32 a = i * num_phi + j;
            Uint32 b = i * num_phi + j + 1;
            Uint32 c = (i + 1) * num_phi + j + 1;
            Uint32 d = (i + 1) * num_phi + j;

            // Clockwise winding to match circle geometry
            indices[index_idx++] = a;
            indices[index_idx++] = b;
            indices[index_idx++] = c;

            indices[index_idx++] = a;
            indices[index_idx++] = c;
            indices[index_idx++] = d;
        }
    }

    // Upload to GPU
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