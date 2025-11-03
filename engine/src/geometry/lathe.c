#include <math.h>
#include <stdlib.h>

#include <geometry/g_common.h>
#include <geometry/lathe.h>
#include <math/matrix.h>

PAL_MeshComponent PAL_CreateLatheMesh (static PAL_LatheMeshCreateInfo* info) {
    PAL_MeshComponent null_mesh = (PAL_MeshComponent) {0};
    if (info->num_points < 2) return NULL;
    if (phi_segments < 3) return NULL;

    Uint32 num_phi = phi_segments + 1; // Rings closed
    Uint32 num_vertices = num_points * num_phi;

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos.x,y,z + normal.x,y,z + uv.u,v
    if (vertices == NULL)
        return NULL

                   // Generate vertices
                   Uint32 vertex_idx = 0;
    for (Uint32 i = 0; i < num_points; i++) {
        float u = (float) i / (float) (num_points - 1); // Axial UV

        for (Uint32 j = 0; j < num_phi; j++) {
            float phi_frac = (float) j / (float) phi_segments;
            float phi = phi_start + phi_frac * phi_length;
            float cos_phi = cosf (phi);
            float sin_phi = sinf (phi);

            // Position: rotate point around Y (points.x is radius, points.y is
            // height)
            float x = points[i].x * cos_phi;
            float y = points[i].y;
            float z = points[i].x * sin_phi;

            // UV: u along path, v around phi (0-1)
            float v = phi_frac;

            vertices[vertex_idx++] = x;
            vertices[vertex_idx++] = y;
            vertices[vertex_idx++] = z;
            vertices[vertex_idx++] = 0.0f; // nx (placeholder)
            vertices[vertex_idx++] = 0.0f; // ny
            vertices[vertex_idx++] = 0.0f; // nz
            vertices[vertex_idx++] =
                v; // Note: may need to flip u/v based on convention
            vertices[vertex_idx++] = u;
        }
    }

    // Generate indices (quads between rings, flipped winding for outward faces)
    Uint32 num_indices = (num_points - 1) * phi_segments * 6;
    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (indices == NULL) {
        free (vertices);
        return NULL;
    }

    Uint32 index_idx = 0;
    for (Uint32 i = 0; i < num_points - 1; i++) {
        for (Uint32 j = 0; j < phi_segments; j++) {
            Uint32 a = (Uint32) (i * num_phi + j);
            Uint32 b =
                (Uint32) (i * num_phi + (j + 1) % phi_segments); // Wrap phi
            Uint32 c = (Uint32) ((i + 1) * num_phi + (j + 1) % phi_segments);
            Uint32 d = (Uint32) ((i + 1) * num_phi + j);

            // Flipped winding: a -> c -> b and a -> d -> c (counterclockwise if
            // original was clockwise)
            indices[index_idx++] = a;
            indices[index_idx++] = c;
            indices[index_idx++] = b;

            indices[index_idx++] = a;
            indices[index_idx++] = d;
            indices[index_idx++] = c;
        }
    }

    // Compute normals
    PAL_ComputeNormals (vertices, num_vertices, indices, num_indices, 8, 0, 3);

    // Upload to GPU
    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (device, vertices, vertices_size, &vbo);
    free (vertices);
    if (vbo == NULL) {
        free (indices);
        return NULL;
    }

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (device, indices, indices_size, &ibo);
    free (indices);
    if (ibo == NULL) {
        SDL_ReleaseGPUBuffer (device, vbo);
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
                                 .index_size = SDL_GPU_INDEXELEMENTSIZE_32BIT};

    return out_mesh;
}