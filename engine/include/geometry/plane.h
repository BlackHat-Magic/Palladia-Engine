#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_plane_mesh (
    float width,
    float height,
    Uint32 width_segments,
    Uint32 height_segments,
    SDL_GPUDevice* device
);