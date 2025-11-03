#pragma once

#include <ecs/ecs.h>

typedef struct {
    float radius;
    Uint32 segments;
    SDL_GPUDevice* device;
} PAL_CircleMeshCreateInfo;

PAL_MeshComponent* PAL_CreateCircleMesh (const PAL_CircleMeshCreateInfo* info);