#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent* PAL_CreateSphereMesh (static PAL_SphereMeshCreateInfo* info);

typedef struct {
    float radius;
    Uint32 width_segments;
    Uint32 height_segments;
    float phi_start;
    float phi_length;
    float theta_start;
    float theta_length;
    SDL_GPUDevice* device;
} PAL_SphereMeshCreateInfo;