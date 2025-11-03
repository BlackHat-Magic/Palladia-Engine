#pragma once

#include <ecs/ecs.h>

PAL_MeshComponent
create_circle_mesh (float radius, int segments, SDL_GPUDevice* device);