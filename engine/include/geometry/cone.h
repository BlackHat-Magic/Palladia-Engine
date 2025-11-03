#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_cone_mesh (
    float radius,
    float height,
    Uint32 radial_segments,
    Uint32 height_segments,
    bool open_ended,
    float theta_start,
    float theta_length,
    SDL_GPUDevice* device
);