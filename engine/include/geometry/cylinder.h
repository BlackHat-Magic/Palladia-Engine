#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent
PAL_CreateCylinderMesh (static PAL_CylinderMeshCreateInfo* info);

typedef struct {
    float radius_top;
    float radius_bottom;
    float height;
    Uint32 radial_segments;
    Uint32 height_segments;
    bool open_ended;
    float theta_start;
    float theta_length;
    SDL_GPUDevice* device;
} PAL_CylinderMeshCreateInfo;