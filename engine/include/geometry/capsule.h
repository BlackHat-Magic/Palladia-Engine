#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_capsule_mesh (
    float radius,
    float height,
    int cap_segments,
    int radial_segments,
    SDL_GPUDevice* device
);