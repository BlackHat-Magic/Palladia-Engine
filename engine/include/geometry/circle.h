#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent PAL_CreateCircleMesh (static PAL_CircleMeshCreateInfo* info);

typedef struct {
    float radians;
    Uint32 segments;
    SDL_GPUDevice* device;
} PAL_CircleMeshCreateInfo;