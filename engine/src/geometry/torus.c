#include <math.h>
#include <stdlib.h>

#include <geometry/g_common.h>
#include <geometry/torus.h>
#include <math/matrix.h>

PAL_MeshComponent* PAL_CreateTorusMesh (
    float info->radius,
    float info->tube_radius,
    Uint32 info->radial_segments,
    Uint32 info->tubular_segments,
    float info->arc,
    SDL_GPUDevice * info->device
) {
    if (info->radial_segments < 3 || info->tubular_segments < 3) return NULL;
    if (info->tube_radius <= 0.0f || info->radius <= 0.0f) return NULL;
    if (info->arc <= 0.0f || info->arc > 2.0f * (float) M_PI) return NULL;

    bool is_closed = fabsf (info->arc - 2.0f * (float) M_PI) < 1e-6f;
    Uint32 num_tubular = info->tubular_segments + (is_closed ? 0 : 1);
    Uint32 num_radial =
        info->radial_segments; // Always closed in radial direction

    Uint32 num_vertices = num_tubular * num_radial;

    float* vertices = (float*) malloc (
        num_vertices * 8 * sizeof (float)
    ); // pos3 + norm3 + uv2
    if (vertices == NULL) return NULL;

    Uint32 vertex_idx = 0;
    for (Uint32 tu = 0; tu < num_tubular; tu++) {
        float u = ((float) tu / (float) info->tubular_segments) * info->arc;
        float cos_u = cosf (u);
        float sin_u = sinf (u);

        for (Uint32 ra = 0; ra < num_radial; ra++) {
            float v = ((float) ra / (float) info->radial_segments) * 2.0f *
                      (float) M_PI;
            float cos_v = cosf (v);
            float sin_v = sinf (v);

            // Position (hole along Y-axis to match previous orientation)
            float x = (info->radius + info->tube_radius * cos_v) * cos_u;
            float y = info->tube_radius * sin_v;
            float z = (info->radius + info->tube_radius * cos_v) * sin_u;

            // Tube center
            vec3 tube_center = {
                info->radius * cos_u, 0.0f, info->radius * sin_u
            };

            // Normal (direction from tube center to point)
            vec3 pos = {x, y, z};
            vec3 norm = vec3_normalize (vec3_sub (pos, tube_center));

            // UV
            float uv_u = (float) tu / (float) info->tubular_segments;
            float uv_v = (float) ra / (float) info->radial_segments;

            vertices[vertex_idx++] = x;
            vertices[vertex_idx++] = y;
            vertices[vertex_idx++] = z;
            vertices[vertex_idx++] = norm.x;
            vertices[vertex_idx++] = norm.y;
            vertices[vertex_idx++] = norm.z;
            vertices[vertex_idx++] = uv_u;
            vertices[vertex_idx++] = uv_v;
        }
    }

    Uint32 num_u_loops = info->tubular_segments;
    Uint32 num_r_loops = info->radial_segments;
    Uint32 num_indices = num_u_loops * num_r_loops * 6;
    Uint32* indices = (Uint32*) malloc (num_indices * sizeof (Uint32));
    if (indices == NULL) {
        free (vertices);
        return NULL;
    }

    Uint32 index_idx = 0;
    for (Uint32 tu = 0; tu < num_u_loops; tu++) {
        Uint32 tu1 = tu + 1;
        if (is_closed) {
            tu1 %= info->tubular_segments;
        }

        for (Uint32 ra = 0; ra < num_r_loops; ra++) {
            Uint32 ra1 = (ra + 1) % info->radial_segments;

            Uint32 a = tu * num_radial + ra;
            Uint32 b = tu1 * num_radial + ra;
            Uint32 c = tu1 * num_radial + ra1;
            Uint32 d = tu * num_radial + ra1;

            // Clockwise winding for front-face (matches
            // SDL_GPU_FRONTFACE_CLOCKWISE)
            indices[index_idx++] = a;
            indices[index_idx++] = d;
            indices[index_idx++] = b;

            indices[index_idx++] = b;
            indices[index_idx++] = d;
            indices[index_idx++] = c;
        }
    }

    // Upload to GPU
    Uint64 vertices_size = num_vertices * 8 * sizeof (float);
    SDL_GPUBuffer* vbo =
        PAL_UploadVertices (info->device, vertices, vertices_size, &vbo);
    if (vbo == NULL) {
        free (vertices);
        free (indices);
        return NULL;
    }
    free (vertices);

    Uint64 indices_size = num_indices * sizeof (Uint32);
    SDL_GPUBuffer* ibo =
        PAL_UploadIndices (info->device, indices, indices_size, &ibo);
    if (ibo == NULL) {
        SDL_ReleaseGPUBuffer (info->device, vbo);
        free (indices);
        return NULL;
    }
    free (indices);

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