#include <stdlib.h>

#include <SDL3/SDL.h>
#include <SDL3/SDL_gpu.h>

#include <geometry/g_common.h>
#include <math/matrix.h>

SDL_GPUBuffer* PAL_UploadVertices (
    SDL_GPUDevice* device,
    const void* vertices,
    Uint64 vertices_size,
) {
    SDL_GPUBufferCreateInfo vbo_info = {
        .size = (Uint32) vertices_size,
        .usage = SDL_GPU_BUFFERUSAGE_VERTEX
    };
    SDL_GPUBuffer* vbo = SDL_CreateGPUBuffer (device, &vbo_info);
    if (vbo == NULL) return NULL;

    SDL_GPUTransferBufferCreateInfo tinfo = {
        .size = (Uint32) vertices_size,
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD
    };
    SDL_GPUTransferBuffer* tbuf = SDL_CreateGPUTransferBuffer (device, &tinfo);
    if (tbuf == NULL) {
        SDL_ReleaseGPUBuffer (device, vbo);
        return NULL;
    }

    void* data = SDL_MapGPUTransferBuffer (device, tbuf, false);
    if (data == NULL) {
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, vbo);
        return NULL;
    }
    memcpy (data, vertices, vertices_size);
    SDL_UnmapGPUTransferBuffer (device, tbuf);

    SDL_GPUCommandBuffer* cmd = SDL_AcquireGPUCommandBuffer (device);
    if (cmd == NULL) {
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, vbo);
        return NULL;
    }

    SDL_GPUCopyPass* copy_pass = SDL_BeginGPUCopyPass (cmd);
    if (copy_pass == NULL) {
        SDL_SubmitGPUCommandBuffer (cmd);
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, vbo);
        return NULL;
    }

    SDL_GPUTransferBufferLocation src_loc = {
        .transfer_buffer = tbuf,
        .offset = 0
    };
    SDL_GPUBufferRegion dst_reg =
        {.buffer = vbo, .offset = 0, .size = (Uint32) vertices_size};
    SDL_UploadToGPUBuffer (copy_pass, &src_loc, &dst_reg, false);
    SDL_EndGPUCopyPass (copy_pass);
    SDL_SubmitGPUCommandBuffer (cmd);

    SDL_ReleaseGPUTransferBuffer (device, tbuf);
    return vbo;
}

// Returns 0 on success, 1 on failure
SDL_GPUBuffer* PAL_UploadIndices (
    SDL_GPUDevice* device,
    const void* indices,
    Uint64 indices_size,
) {
    SDL_GPUBufferCreateInfo ibo_info = {
        .size = (Uint32) indices_size,
        .usage = SDL_GPU_BUFFERUSAGE_INDEX
    };
    SDL_GPUBuffer* ibo = SDL_CreateGPUBuffer (device, &ibo_info);
    if (ibo == NULL) return NULL;

    SDL_GPUTransferBufferCreateInfo tinfo = {
        .size = (Uint32) indices_size,
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD
    };
    SDL_GPUTransferBuffer* tbuf = SDL_CreateGPUTransferBuffer (device, &tinfo);
    if (tbuf == NULL) {
        SDL_ReleaseGPUBuffer (device, ibo);
        return NULL;
    }

    void* data = SDL_MapGPUTransferBuffer (device, tbuf, false);
    if (data == NULL) {
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, ibo);
        return NULL;
    }
    memcpy (data, indices, indices_size);
    SDL_UnmapGPUTransferBuffer (device, tbuf);

    SDL_GPUCommandBuffer* cmd = SDL_AcquireGPUCommandBuffer (device);
    if (cmd == NULL) {
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, ibo);
        return NULL;
    }

    SDL_GPUCopyPass* copy_pass = SDL_BeginGPUCopyPass (cmd);
    if (copy_pass == NULL) {
        SDL_SubmitGPUCommandBuffer (cmd);
        SDL_ReleaseGPUTransferBuffer (device, tbuf);
        SDL_ReleaseGPUBuffer (device, ibo);
        return NULL;
    }

    SDL_GPUTransferBufferLocation src_loc = {
        .transfer_buffer = tbuf,
        .offset = 0
    };
    SDL_GPUBufferRegion dst_reg =
        {.buffer = ibo, .offset = 0, .size = (Uint32) indices_size};
    SDL_UploadToGPUBuffer (copy_pass, &src_loc, &dst_reg, false);
    SDL_EndGPUCopyPass (copy_pass);
    SDL_SubmitGPUCommandBuffer (cmd);

    SDL_ReleaseGPUTransferBuffer (device, tbuf);
    return ibo;
}

void PAL_ComputeNormals (
    float* vertices,
    int num_vertices,
    const Uint32* indices,
    int num_indices,
    int stride,
    int pos_offset,
    int norm_offset
) {
    // Accumulate normals per vertex
    vec3* accum_norms = (vec3*) calloc (num_vertices, sizeof (vec3));
    if (!accum_norms) {
        SDL_Log ("Failed to allocate accum_norms for normals computation");
        return;
    }

    for (int i = 0; i < num_indices; i += 3) {
        int ia = indices[i];
        int ib = indices[i + 1];
        int ic = indices[i + 2];

        vec3 a = {
            vertices[ia * stride + pos_offset],
            vertices[ia * stride + pos_offset + 1],
            vertices[ia * stride + pos_offset + 2]
        };
        vec3 b = {
            vertices[ib * stride + pos_offset],
            vertices[ib * stride + pos_offset + 1],
            vertices[ib * stride + pos_offset + 2]
        };
        vec3 c = {
            vertices[ic * stride + pos_offset],
            vertices[ic * stride + pos_offset + 1],
            vertices[ic * stride + pos_offset + 2]
        };

        vec3 ab = vec3_sub (b, a);
        vec3 ac = vec3_sub (c, a);
        vec3 face_norm = vec3_normalize (vec3_cross (ab, ac));

        accum_norms[ia] = vec3_add (accum_norms[ia], face_norm);
        accum_norms[ib] = vec3_add (accum_norms[ib], face_norm);
        accum_norms[ic] = vec3_add (accum_norms[ic], face_norm);
    }

    // Normalize and assign
    for (int i = 0; i < num_vertices; i++) {
        vec3 norm = vec3_normalize (accum_norms[i]);
        vertices[i * stride + norm_offset] = norm.x;
        vertices[i * stride + norm_offset + 1] = norm.y;
        vertices[i * stride + norm_offset + 2] = norm.z;
    }

    free (accum_norms);
}