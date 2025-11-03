#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent PAL_CreateConeMesh (static PAL_ConeMeshCreateInfo* info);

typedef struct {
    float radius;
    float height;
    Uint32 radial_segments;
    Uint32 height_segments;
    bool open_ended;
    float theta_start;
    float theta_length;
    SDL_GPUDevice* device;
} PAL_ConeMeshCreateInfo;