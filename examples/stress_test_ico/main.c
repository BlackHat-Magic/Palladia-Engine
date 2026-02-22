#include <math/matrix.h>
#define SDL_MAIN_USE_CALLBACKS 1

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL3/SDL_main.h>

#include <ecs/ecs.h>
#include <geometry/icosahedron.h>
#include <material/m_common.h>
#include <material/phong_material.h>

#define STARTING_WIDTH 640
#define STARTING_HEIGHT 480
#define STARTING_FOV 70.0
#define MOUSE_SENSE 1.0f / 100.0f
#define MOVEMENT_SPEED 3.0f

typedef struct {
    bool quit;
    PAL_GPURenderer* renderer;
    Entity camera_entity;
    SDL_GPUTexture* white_texture;
    Uint64 last_time;
} AppState;

Entity icosahedrons[8000];

Uint64 frame_start;
Uint64 rot_time;
Uint64 render_time;
double rot_time_ms;
double render_time_ms;
Uint64 frame_count;

SDL_AppResult SDL_AppEvent (void* appstate, SDL_Event* event) {
    AppState* state = (AppState*) appstate;

    Entity cam = state->camera_entity;
    if (cam == (Entity) -1 || !has_transform (cam)) return SDL_APP_CONTINUE;
    TransformComponent* cam_trans = get_transform (cam);

    switch (event->type) {
    case SDL_EVENT_QUIT:
        state->quit = true;
        break;
    case SDL_EVENT_KEY_DOWN:
        if (event->key.key == SDLK_ESCAPE) state->quit = true;
        break;
    }

    fps_controller_event_system (event);

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppInit (void** appstate, int argc, char** argv) {
    SDL_SetAppMetadata (
        "Asmadi Engine Stress Test", "0.1.0", "xyz.lukeh.Asmadi-Engine"
    );

    // create appstate
    AppState* state = (AppState*) calloc (1, sizeof (AppState));
    state->camera_entity = (Entity) -1;

    // initialize SDL
    if (!SDL_Init (SDL_INIT_VIDEO)) {
        SDL_Log ("Couldn't initialize SDL: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // Create window
    SDL_Window* window = SDL_CreateWindow (
        "Stress Test - Icosahedrons", STARTING_WIDTH, STARTING_HEIGHT,
        SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN
    );
    if (!window) {
        SDL_Log ("Couldn't create window/renderer: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // create GPU device
    SDL_GPUDevice* device =
        SDL_CreateGPUDevice (SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
    if (!device) {
        SDL_Log ("Couldn't create SDL_GPU_DEVICE");
        return SDL_APP_FAILURE;
    }
    if (!SDL_ClaimWindowForGPUDevice (device, window)) {
        SDL_Log ("Couldn't claim window for GPU device: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    PAL_RendererCreateInfo renderer_info = {
        .device = device,
        .window = window,
        .width = STARTING_WIDTH,
        .height = STARTING_HEIGHT
    };
    state->renderer = renderer_init (&renderer_info);
    if (state->renderer == NULL) {
        return SDL_APP_FAILURE;
    }

    // load texture
    state->white_texture = create_white_texture (state->renderer->device);
    if (!state->white_texture) return SDL_APP_FAILURE;

    // create sampler
    SDL_GPUSamplerCreateInfo sampler_info = {
        .min_filter = SDL_GPU_FILTER_LINEAR,
        .mag_filter = SDL_GPU_FILTER_LINEAR,
        .mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
        .address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .max_anisotropy = 1.0f,
        .enable_anisotropy = false
    };
    SDL_GPUSampler* sampler =
        SDL_CreateGPUSampler (state->renderer->device, &sampler_info);
    if (!sampler) {
        SDL_Log ("Failed to create sampler: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // spawn 8k icosahedrons
    for (int i = -10; i < 10; i++) {
        for (int j = -10; j < 10; j++) {
            for (int k = -10; k < 10; k++) {
                Entity ico = create_entity ();
                icosahedrons[(i + 10) * 400 + (j + 10) * 20 + (k + 10)] = ico;

                PAL_IcosahedronMeshCreateInfo mesh_info = {
                    .radius = 0.5f,
                    .device = state->renderer->device
                };
                PAL_MeshComponent* icosahedron_mesh =
                    PAL_CreateIcosahedronMesh (&mesh_info);
                if (icosahedron_mesh == NULL) return SDL_APP_FAILURE;
                PAL_AddMeshComponent (ico, icosahedron_mesh);

                float r = (float) rand () / (float) RAND_MAX;
                float g = (float) rand () / (float) RAND_MAX;
                float b = (float) rand () / (float) RAND_MAX;

                PAL_PhongMaterialCreateInfo mat_info = {
                    .renderer = state->renderer,
                    .color = (SDL_FColor) {r, g, b, 1.0f},
                    .emissive = (SDL_FColor) {0.0f, 0.0f, 0.0f, 0.0f},
                    .cullmode = SDL_GPU_CULLMODE_BACK,
                    .texture = state->white_texture,
                    .sampler = sampler
                };
                PAL_MaterialComponent* icosahedron_material =
                    PAL_CreatePhongMaterial (&mat_info);
                if (icosahedron_material == NULL) return SDL_APP_FAILURE;
                PAL_AddMaterialComponent (ico, icosahedron_material);

                PAL_TransformCreateInfo transform_info = {
                    .position = (vec3) {2.0f * (float) i, 2.0f * (float) j,
                                        2.0f * (float) k},
                    .rotation = (vec3) {(float) rand () / (float) RAND_MAX *
                                            2.0f * (float) M_PI,
                                        (float) rand () / (float) RAND_MAX *
                                            2.0f * (float) M_PI,
                                        (float) rand () / (float) RAND_MAX *
                                            2.0f * (float) M_PI},
                    .scale = (vec3) {1.0f, 1.0f, 1.0f}
                };
                add_transform (ico, &transform_info);
            }
        }
        printf ("spawned %d icos\n", (i + 11) * 400);
    }

    // ambient light
    Entity ambient_light = create_entity ();
    PAL_AmbientLightCreateInfo ambient_info = {
        .color = (SDL_FColor) {1.0f, 1.0f, 1.0f, 0.1f},
        .renderer = state->renderer
    };
    add_ambient_light (ambient_light, &ambient_info);

    // four point lights for now
    for (Uint32 i = 0; i < 4; i++) {
        Entity point_light = create_entity ();
        PAL_PointLightCreateInfo point_light_info = {
            .color = (SDL_FColor) {1.0f, 1.0f, 1.0f, 1.0f},
            .renderer = state->renderer
        };
        add_point_light (point_light, &point_light_info);

        int px = (rand () % 101) - 50;
        int py = (rand () % 101) - 50;
        int pz = (rand () % 101) - 50;
        PAL_TransformCreateInfo light_transform_info = {
            .position = (vec3) {(float) (px * 2 + 1), (float) (py * 2 + 1),
                                (float) (pz * 2 + 1)},
            .rotation = (vec3) {0.0f, 0.0f, 0.0f},
            .scale = (vec3) {1.0f, 1.0f, 1.0f}
        };
        add_transform (point_light, &light_transform_info);
    }

    // camera
    Entity camera = create_entity ();
    PAL_TransformCreateInfo camera_transform_info = {
        .position = (vec3) {0.0f, 0.0f, -2.0f},
        .rotation = (vec3) {0.0f, 0.0f, 0.0f},
        .scale = (vec3) {1.0f, 1.0f, 1.0f}
    };
    add_transform (camera, &camera_transform_info);

    PAL_CameraCreateInfo camera_info =
        {.fov = STARTING_FOV, .near_clip = 0.01f, .far_clip = 1000.0f};
    add_camera (camera, &camera_info);

    PAL_FpsControllerCreateInfo fps_info = {
        .mouse_sense = MOUSE_SENSE,
        .move_speed = MOVEMENT_SPEED
    };
    add_fps_controller (camera, &fps_info);

    state->camera_entity = camera;
    SDL_SetWindowRelativeMouseMode (window, true);

    state->last_time = SDL_GetPerformanceCounter ();

    *appstate = state;
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate (void* appstate) {
    AppState* state = (AppState*) appstate;
    if (state->quit) return SDL_APP_SUCCESS;

    // TODO: handle no camera
    Entity cam = state->camera_entity;
    if (cam == (Entity) -1) return SDL_APP_CONTINUE;
    TransformComponent* cam_trans = get_transform (cam);

    // dt
    const Uint64 now = SDL_GetPerformanceCounter ();
    float dt = (float) (now - state->last_time) /
               (float) (SDL_GetPerformanceFrequency ());
    state->last_time = now;

    frame_start = SDL_GetTicksNS ();

    for (Uint32 i = 0; i < 8000; i++) {
        Entity icosahedron = icosahedrons[i];

        TransformComponent transform = *get_transform (icosahedron);
        vec3 rotation = euler_from_quat (transform.rotation);
        rotation.x += 0.005f;
        rotation.z += 0.01f;
        transform.rotation = quat_from_euler (rotation);
        PAL_TransformCreateInfo transform_info = {
            .position = transform.position,
            .rotation = rotation,
            .scale = transform.scale
        };
        add_transform (icosahedron, &transform_info);
    }

    rot_time = SDL_GetTicksNS () - frame_start;
    rot_time_ms = rot_time / 1e6;

    // camera forward vector
    fps_controller_update_system (dt);

    Uint64 prerender, preui, postrender;
    render_system (state->renderer, cam, &prerender, &preui, &postrender);

    render_time = SDL_GetTicksNS () - rot_time - frame_start;
    render_time_ms = render_time / 1e6;

    if (frame_count++ % 10 == 0) {
        printf ("rot: %.3f\trender: %.3f\n", rot_time_ms, render_time_ms);
    }

    return SDL_APP_CONTINUE;
}

void SDL_AppQuit (void* appstate, SDL_AppResult result) {
    AppState* state = (AppState*) appstate;

    free_pools (state->renderer->device);
    if (state->white_texture) {
        SDL_ReleaseGPUTexture (state->renderer->device, state->white_texture);
    }
    if (state->renderer->depth_texture) {
        SDL_ReleaseGPUTexture (
            state->renderer->device, state->renderer->depth_texture
        );
    }
    free (state->renderer);
}
