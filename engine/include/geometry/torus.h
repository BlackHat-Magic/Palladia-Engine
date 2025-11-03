#pragma once

#include <ecs/ecs.h>

typedef struct {
    float radius;
    float tube_radius;
    Uint32 radial_segments;
    Uint32 tubular_segments;
    float arc;
    SDL_GPUDevice* device;
} PAL_TorusMeshCreateInfo;

PAL_MeshComponent* PAL_CreateTorusMesh (const PAL_TorusMeshCreateInfo* info);