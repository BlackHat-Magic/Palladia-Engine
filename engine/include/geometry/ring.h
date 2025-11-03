#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_ring_mesh (
    float inner_radius,
    float outer_radius,
    Uint32 theta_segments,
    Uint32 phi_segments,
    float theta_start,
    float theta_length,
    SDL_GPUDevice* device
);