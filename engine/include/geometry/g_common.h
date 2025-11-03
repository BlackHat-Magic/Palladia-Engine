#pragma once

#include <SDL3/SDL_gpu.h>

// Returns 0 on success, 1 on failure
SDL_GPUBuffer* PAL_UploadVertices (
    SDL_GPUDevice* device,
    const void* vertices,
    Uint64 vertices_size
);

// Returns 0 on success, 1 on failure
SDL_GPUBuffer* PAL_UploadIndices (
    SDL_GPUDevice* device,
    const void* indices,
    Uint64 indices_size
);

void PAL_ComputeNormals (
    float* vertices,
    Uint32 num_vertices,
    const Uint32* indices,
    Uint32 num_indices,
    Uint32 stride,
    Uint32 pos_offset,
    Uint32 norm_offset
);

typedef struct {
    float radius;
    SDL_GPUDevice* device;
} PAL_PlatonicMeshCreateInfo;