#pragma once

#include <ecs/ecs.h>

typedef struct {
    float radius;
    float height;
    Uint32 cap_segments;
    Uint32 radial_segments;
    SDL_GPUDevice* device;
} PAL_CapsuleMeshCreateInfo;

PAL_MeshComponent*
PAL_CreateCapsuleMesh (const PAL_CapsuleMeshCreateInfo* info);