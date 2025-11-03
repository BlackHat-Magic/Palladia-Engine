#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_cone_mesh (
    float radius,
    float height,
    int radial_segments,
    int height_segments,
    bool open_ended,
    float theta_start,
    float theta_length,
    SDL_GPUDevice* device
);