#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent* PAL_CreateTorusMesh (static PAL_TorusMeshCreateInfo* info);

typedef struct {
    float radius;
    float tube_radius;
    Uint32 radial_segments;
    Uint32 tubular_segments;
    float arc;
    SDL_GPUDevice* device;
} PAL_TorusMeshCreateInfo;