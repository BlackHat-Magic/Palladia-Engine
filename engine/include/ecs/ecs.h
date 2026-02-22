#pragma once

#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>

#include <microui.h>

#include <math/matrix.h>

typedef enum {
    SIDE_FRONT,
    SIDE_BACK,
    SIDE_DOUBLE,
} MaterialSide;

typedef Uint32 Entity;

typedef struct {
    vec3 position;
    vec4 rotation; // quat
    vec3 scale;
} TransformComponent;

typedef struct {
    SDL_GPUBuffer* vertex_buffer;
    Uint32 num_vertices;
    SDL_GPUBuffer* index_buffer;
    Uint32 num_indices;
    SDL_GPUIndexElementSize index_size;
} PAL_MeshComponent;

typedef struct {
    SDL_FColor color;
    SDL_FColor emissive;
    SDL_GPUTexture* texture;
    SDL_GPUSampler* sampler;
    SDL_GPUShader* vertex_shader;
    SDL_GPUShader* fragment_shader;
    SDL_GPUGraphicsPipeline* pipeline;
} PAL_MaterialComponent;

typedef struct {
    float fov;
    float near_clip;
    float far_clip;
} CameraComponent;

typedef struct {
    float mouse_sense;
    float move_speed;
} FpsCameraControllerComponent;

typedef struct {
    SDL_FRect rect;
    SDL_FColor color;
    SDL_GPUTexture* texture;
} UIRect;

typedef struct {
    // rectangle
    UIRect* rects;
    Uint32 rect_count;
    Uint32 max_rects;
    SDL_GPUTexture* white_texture;
    SDL_GPUSampler* sampler;

    // text
    TTF_Font* font;

    // GPU buffers
    SDL_GPUBuffer* vbo;
    Uint32 vbo_size;
    SDL_GPUBuffer* ibo;
    Uint32 ibo_size;

    // uh
    SDL_GPUShader* vertex;
    SDL_GPUShader* fragment;
    SDL_GPUGraphicsPipeline* pipeline;

    mu_Context context;
} UIComponent;

// Billboard is a flag (no data)

typedef SDL_FColor AmbientLightComponent;
typedef SDL_FColor GPUAmbientLight;

typedef SDL_FColor PointLightComponent; // position is another component
typedef struct {
    vec4 position;
    SDL_FColor color;
} GPUPointLight;

// ECS API
Entity create_entity (void);
void destroy_entity (SDL_GPUDevice* device, Entity e);

// Transforms
typedef struct {
    vec3 position;
    vec3 rotation;
    vec3 scale;
} PAL_TransformCreateInfo;

void add_transform (Entity e, const PAL_TransformCreateInfo* info);
TransformComponent* get_transform (Entity e);
bool has_transform (Entity e);
void remove_transform (Entity e);

// Meshes
void PAL_AddMeshComponent (Entity e, PAL_MeshComponent* mesh);
PAL_MeshComponent* PAL_GetMeshComponent (Entity e);
bool has_mesh (Entity e);
void remove_mesh (SDL_GPUDevice* device, Entity e); // state for device release

// Materials
void PAL_AddMaterialComponent (Entity e, PAL_MaterialComponent* material);
PAL_MaterialComponent* PAL_GetMaterialComponent (Entity e);
bool has_material (Entity e);
void remove_material (
    SDL_GPUDevice* device,
    Entity e
); // state for device release

// Cameras
typedef struct {
    float fov;
    float near_clip;
    float far_clip;
} PAL_CameraCreateInfo;

void add_camera (Entity e, const PAL_CameraCreateInfo* info);
CameraComponent* get_camera (Entity e);
bool has_camera (Entity e);
void remove_camera (Entity e);

// FPS Controllers
typedef struct {
    float mouse_sense;
    float move_speed;
} PAL_FpsControllerCreateInfo;

void add_fps_controller (Entity e, const PAL_FpsControllerCreateInfo* info);
FpsCameraControllerComponent* get_fps_controller (Entity e);
bool has_fps_controller (Entity e);
void remove_fps_controller (Entity e);

// Billboards (flag)
void add_billboard (Entity e);
bool has_billboard (Entity e);
void remove_billboard (Entity e);

// UI
void add_ui (Entity e, UIComponent* ui);
bool has_ui (Entity e);
UIComponent* get_ui (Entity e);
void remove_ui (Entity e);

// renderer
typedef struct {
    SDL_GPUDevice* device;
    SDL_Window* window;
    Uint32 width;
    Uint32 height;
} PAL_RendererCreateInfo;

typedef struct {
    SDL_GPUDevice* device;
    SDL_Window* window;
    Uint32 width;
    Uint32 height;
    Uint32 dwidth;
    Uint32 dheight;
    SDL_GPUTexture* depth_texture;
    SDL_GPUTextureFormat format;
    SDL_GPUBuffer* ambient_ssbo;
    Uint32 ambient_size;
    SDL_GPUBuffer* point_ssbo;
    Uint32 point_size;
} PAL_GPURenderer;

PAL_GPURenderer* renderer_init (const PAL_RendererCreateInfo* info);

// Ambient Lights
typedef struct {
    SDL_FColor color;
    PAL_GPURenderer* renderer;
} PAL_AmbientLightCreateInfo;

void add_ambient_light (Entity e, const PAL_AmbientLightCreateInfo* info);
AmbientLightComponent* get_ambient_light (Entity e);
bool has_ambient_light (Entity e);
void remove_ambient_light (Entity e);

// Point Lights
typedef struct {
    SDL_FColor color;
    PAL_GPURenderer* renderer;
} PAL_PointLightCreateInfo;

void add_point_light (Entity e, const PAL_PointLightCreateInfo* info);
PointLightComponent* get_point_light (Entity e);
bool has_point_light (Entity e);
void remove_point_light (Entity e);

// Systems
void fps_controller_event_system (SDL_Event* event);
void fps_controller_update_system (float dt);
SDL_AppResult render_system (
    PAL_GPURenderer* renderer,
    Entity cam,
    Uint64* prerender,
    Uint64* preui,
    Uint64* postrender
);

void free_pools (SDL_GPUDevice* device);