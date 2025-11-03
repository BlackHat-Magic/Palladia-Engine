#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent* PAL_CreateCapsuleMesh (static PAL_CapsuleMeshCreateInfo* info);

typedef struct {
    float radius,
    float height,
    Uint32 cap_segments,
    Uint32 radial_segments,
    SDL_GPUDevice* device
} PAL_CapsuleMeshCreateInfo;