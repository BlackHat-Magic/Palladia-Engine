#pragma once

#include <ecs/ecs.h>

typedef struct {
    float l;
    float w;
    float h;
    SDL_GPUDevice* device;
} PAL_BoxMeshCreateInfo;

PAL_MeshComponent* PAL_CreateBoxMesh (const PAL_BoxMeshCreateInfo* info);