#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent
PAL_CreateDodecahedronMesh (static PAL_DodecahedronMeshCreateInfo* info);

typedef struct {
    float radius;
    SDL_GPUDevice* device
} PAL_DodecahedronMeshCreateInfo;