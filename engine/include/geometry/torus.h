#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_torus_mesh (
    float radius,
    float tube_radius,
    Uint32 radial_segments,
    Uint32 tubular_segments,
    float arc,
    SDL_GPUDevice* device
);