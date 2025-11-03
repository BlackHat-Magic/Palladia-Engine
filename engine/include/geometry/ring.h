#pragma once

#include <ecs/ecs.h>

typedef struct {
    float inner_radius;
    float outer_radius;
    Uint32 theta_segments;
    Uint32 phi_segments;
    float theta_start;
    float theta_length;
    SDL_GPUDevice* device;
} PAL_RingMeshCreateInfo;

PAL_MeshComponent* PAL_CreateRingMesh (const PAL_RingMeshCreateInfo* info);