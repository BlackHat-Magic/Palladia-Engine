#pragma once

#include <SDL3/SDL.h>

#include <ecs/ecs.h>

typedef struct {
    SDL_GPUDevice* device;
    char* filename;
    SDL_GPUShaderStage stage;
    Uint32 sampler_count;
    Uint32 uniform_buffer_count;
    Uint32 storage_buffer_count;
    Uint32 storage_texture_count;
} PAL_ShaderCreateInfo;

SDL_GPUShader* PAL_LoadShader (const PAL_ShaderCreateInfo* info);

SDL_GPUTexture* PAL_LoadTexture (SDL_GPUDevice* device, const char* bmp_file_path);

SDL_GPUTexture* create_white_texture (SDL_GPUDevice* device);