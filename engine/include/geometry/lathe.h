#pragma once

#include <ecs/ecs.h>
#include <math/matrix.h>

typedef struct {
    vec2* path;
    Uint32 path_length;
    Uint32 segments;
    float phi_start;
    float phi_length;
    SDL_GPUDevice* device;
} PAL_LatheMeshCreateInfo;

PAL_MeshComponent* PAL_CreateLatheMesh (const PAL_LatheMeshCreateInfo* info);