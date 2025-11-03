#pragma once

#include <ecs/ecs.h>

typedef struct {
    float width;
    float height;
    Uint32 width_segments;
    Uint32 height_segments;
    SDL_GPUDevice* device;
} PAL_PlaneMeshCreateInfo;

PAL_MeshComponent* PAL_CreatePlaneMesh (const PAL_PlaneMeshCreateInfo* info);