#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent create_plane_mesh (
    float width,
    float height,
    int width_segments,
    int height_segments,
    SDL_GPUDevice* device
);