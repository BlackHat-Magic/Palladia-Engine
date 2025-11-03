#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent PAL_CreatePlaneMesh (static PAL_PlaneMeshCreateInfo* info);

typedef struct {
    float width;
    float height;
    Uint32 width_segments;
    Uint32 height_segments;
    SDL_GPUDevice* device;
} PAL_PlaneMeshCreateInfo;