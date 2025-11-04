#pragma once

#include <ecs/ecs.h>

typedef struct {
    PAL_GPURenderer* renderer;
    SDL_FColor color;
    SDL_FColor emissive;
    SDL_GPUCullMode cullmode;
    SDL_GPUTexture* texture;
    SDL_GPUSampler* sampler;
} PAL_PhongMaterialCreateInfo;

PAL_MaterialComponent* PAL_CreatePhongMaterial (const PAL_PhongMaterialCreateInfo* info);