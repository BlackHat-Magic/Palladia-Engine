#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent* PAL_CreateBoxMesh (static PAL_BoxMeshCreateInfo* info);

typedef struct {
    float l;
    float w;
    float h;
    SDL_GPUDevice* device;
} PAL_BoxMeshCreateInfo;