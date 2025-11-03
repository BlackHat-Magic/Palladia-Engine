#include <math.h>

#include <geometry/g_common.h>
#include <geometry/tetrahedron.h>

PAL_MeshComponent*
PAL_CreateTetrahedronMesh (static PAL_TetrahedronMeshCreateInfo* info) {
    const Uint32 num_vertices = 4;
    float vertices[4 * 8] = {
        1.0f,  1.0f,  1.0f,  0.0f, 0.0f, 0.0f, 0.5f, 0.5f, // Vert 0
        1.0f,  -1.0f, -1.0f, 0.0f, 0.0f, 0.0f, 0.5f, 0.0f, // Vert 1
        -1.0f, 1.0f,  -1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.5f, // Vert 2
        -1.0f, -1.0f, 1.0f,  0.0f, 0.0f, 0.0f, 1.0f, 0.5f  // Vert 3
    };

    // Normalize and scale positions (normals placeholder)
    for (Uint32 i = 0; i < num_vertices; i++) {
        vec3 pos = {vertices[i * 8], vertices[i * 8 + 1], vertices[i * 8 + 2]};
        pos = vec3_normalize (pos);
        pos = vec3_scale (pos, radius);
        vertices[i * 8] = pos.x;
        vertices[i * 8 + 1] = pos.y;
        vertices[i * 8 + 2] = pos.z;

        // Spherical UV mapping (using normalized pos before scaling)
        vec3 norm_pos =
            vec3_normalize ((vec3) {vertices[i * 8], vertices[i * 8 + 1],
                                    vertices[i * 8 + 2]});
        float u =
            0.5f + atan2f (norm_pos.z, norm_pos.x) / (2.0f * (float) M_PI);
        float v = acosf (norm_pos.y) / (float) M_PI;
        vertices[i * 8 + 6] = u;
        vertices[i * 8 + 7] = v;
    }

    // 12 indices (4 triangles, clockwise)
    const Uint32 num_indices = 12;
    Uint32 indices[] = {
        0, 1, 2, // Face 0
        0, 3, 1, // Face 1
        0, 2, 3, // Face 2
        1, 3, 2  // Face 3
    };

    // Compute normals
    PAL_ComputeNormals (vertices, num_vertices, indices, num_indices, 8, 0, 3);

    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (device, vertices, vertices_size, &vbo);
    if (vbo == NULL) return NULL;

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (device, indices, indices_size, &ibo);
    if (ibo == NULL) {
        SDL_ReleaseGPUBuffer (device, vbo);
        return NULL;
    }

    PAL_MeshComponent* mesh = malloc (sizeof (PAL_MeshComponent));
    if (mesh == NULL) {
        SDL_ReleaseGPUBuffer (device, vbo);
        SDL_ReleaseGPUBuffer (device, ibo);
        return NULL;
    }
    *mesh = (PAL_MeshComponent) {.vertex_buffer = vbo,
                                 .num_vertices = num_vertices,
                                 .index_buffer = ibo,
                                 .num_indices = num_indices,
                                 .index_size = SDL_GPU_INDEXELEMENTSIZE_16BIT};

    return mesh;
}