#include <SDL3/SDL.h>

#include <ecs/ecs.h>
#include <math/matrix.h>

typedef struct {
    SDL_FColor color;
    SDL_GPUCullMode cullmode;
    PAL_GPURenderer* renderer;
} PAL_BasicMaterialCreateInfo;

PAL_MaterialComponent* PAL_CreateBasicMaterial (const PAL_BasicMaterialCreateInfo* info);