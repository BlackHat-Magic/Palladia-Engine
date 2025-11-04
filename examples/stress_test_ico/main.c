#define SDL_MAIN_USE_CALLBACKS 1

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL3/SDL_main.h>

#include <microui.h>

#include <math/matrix.h>
#include <ecs/ecs.h>
#include <ui/ui.h>
#include <geometry/icosahedron.h>
#include <material/m_common.h>
#include <material/phong_material.h>

#define STARTING_WIDTH 1280
#define STARTING_HEIGHT 720
#define STARTING_FOV 70.0
#define MOUSE_SENSE 1.0f / 100.0f
#define MOVEMENT_SPEED 3.0f

Entity icosahedrons[8000];

Uint64 frame_start;
Uint64 rot_time;
Uint64 render_time;
double rot_time_ms;
double render_time_ms;
Uint64 frame_count;

typedef struct {
    bool quit;
    PAL_GPURenderer* renderer;
    Entity player;
    Uint64 last_time;
    Uint64 prerender;
    Uint64 preui;
    Uint64 postrender;
    float frame_rate;
    Uint64 frame_count;
    bool debug;
    SDL_GPUTexture* white_texture;
} AppState;

SDL_AppResult SDL_AppEvent (void* appstate, SDL_Event* event) {
    AppState* state = (AppState*) appstate;

    Entity cam = state->player;
    if (cam == (Entity) -1 || !has_transform (cam)) return SDL_APP_CONTINUE;
    TransformComponent* cam_trans = get_transform (cam);

    switch (event->type) {
    case SDL_EVENT_QUIT:
        state->quit = true;
        break;
    case SDL_EVENT_KEY_DOWN:
        if (event->key.key == SDLK_ESCAPE) state->quit = true;
        if (event->key.key == SDLK_F3) state->debug = !state->debug;
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
    if (state == NULL) {
        SDL_Log ("Failed to allocate app state.");
        return SDL_APP_FAILURE;
    }
    state->player = (Entity) -1;

    // initialize SDL
    if (!SDL_Init (SDL_INIT_VIDEO)) {
        SDL_Log ("Couldn't initialize SDL: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // Create window
    SDL_Window* window = SDL_CreateWindow (
        "Icosahedron Stress Test", STARTING_WIDTH, STARTING_HEIGHT,
        SDL_WINDOW_VULKAN
    );
    if (window == NULL) {
        SDL_Log ("Couldn't create window/renderer: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // Initialize SDL_ttf
    if (!TTF_Init ()) {
        SDL_Log ("Couldn't initialize SDL_ttf: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // create GPU device
    SDL_GPUDevice* device = SDL_CreateGPUDevice (SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
    if (device == NULL) {
        SDL_Log ("Couldn't create SDL_GPUDevice");
        return SDL_APP_FAILURE;
    }
    if (!SDL_ClaimWindowForGPUDevice (device, window)) {
        SDL_Log ("Couldn't claim window for GPU device: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    state->renderer = renderer_init (device, window, STARTING_WIDTH, STARTING_HEIGHT);
    if (state->renderer == NULL) {
        SDL_Log ("Failed to initialize GPU renderer: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    state->white_texture = create_white_texture (state->renderer->device);
    if (state->white_texture == NULL) {
        SDL_Log ("Failed to create white texture: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // player
    state->player = create_entity ();
    add_transform (
        state->player,
        (vec3) {0.0f, 0.0f, -2.0f},
        (vec3) {0.0f, 0.0f, 0.0f},
        (vec3) {1.0f, 1.0f, 1.0f}
    );
    add_camera (state->player, STARTING_FOV, 0.01f, 1000.0f);
    add_fps_controller (state->player, MOUSE_SENSE, MOVEMENT_SPEED);
    UIComponent* ui = create_ui_component (
        state->renderer,
        255, 255,
        "./assets/NotoSans-Regular.ttf",
        12.0f
    );
    if (ui == NULL) {
        SDL_Log ("Failed to create UI Component: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }
    add_ui (state->player, ui);

    // spawn 8k icosahedrons
    // we want to be able to handle way more (e.g., ~1000000)
    // but I'll let my poor laptop rest now
    // I suspect there's some inefficiency in the way the entity pool gets
    // reallocated
    // TODO: fix that
    // also it'd be nice to be able to initialize the entity pool to some
    // starting number if we know ahead of time that we need a lot.
    PAL_IcosahedronMeshCreateInfo ico_info = {
        .radius = 0.5f,
        .device = state->renderer->device,
    };
    PAL_MeshComponent* mesh = PAL_CreateIcosahedronMesh (&ico_info);
    if (mesh == NULL) {
        SDL_Log ("Failed to create ico mesh: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

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
    SDL_GPUSampler* sampler = SDL_CreateGPUSampler (state->renderer->device, &sampler_info);
    if (sampler == NULL) {
        SDL_Log ("Failed to create sampler: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }
    PAL_PhongMaterialCreateInfo phong_info = {
        .renderer = state->renderer,
        .color = (SDL_FColor) {random_float(), random_float(), random_float(), 1.0f},
        .emissive = (SDL_FColor) {0.0f, 0.0f, 0.0f, 0.0f},
        .cullmode = SDL_GPU_CULLMODE_BACK,
        .texture = state->white_texture,
        .sampler = sampler
    };
    PAL_MaterialComponent* ico_mat = PAL_CreatePhongMaterial (&phong_info);
    if (ico_mat == NULL) {
        SDL_Log ("Failed to create icosahedron material: %s", SDL_GetError());
        SDL_ReleaseGPUSampler (state->renderer->device, sampler);
        return SDL_APP_FAILURE;
    }
    
    for (int i = -10; i < 10; i++) {
        for (int j = -10; j < 10; j++) {
            for (int k = -10; k < 10; k++) {
                Entity ico = create_entity ();
                icosahedrons[(i + 10) * 400 + (j + 10) * 20 + (k + 10)] = ico;
                PAL_AddMeshComponent (ico, mesh);
                PAL_AddMaterialComponent (ico, ico_mat);
                vec3 position = {
                    2.0f * (float) i, 2.0f * (float) j, 2.0f * (float) k
                };
                vec3 rotation = {
                    random_float_range (0.0f, 2.0f * (float) M_PI),
                    random_float_range (0.0f, 2.0f * (float) M_PI),
                    random_float_range (0.0f, 2.0f * (float) M_PI),
                };
                add_transform (
                    ico, position, rotation, (vec3) {1.0f, 1.0f, 1.0f}
                );
            }
        }
    }

    // ambient light
    Entity ambient_light = create_entity ();
    add_ambient_light (ambient_light, (SDL_FColor) {1.0f, 1.0f, 1.0f, 0.1f}, state->renderer);

    // four point lights for now
    for (Uint32 i = 0; i < 4; i++) {
        Entity point_light = create_entity ();
        add_point_light (point_light, (SDL_FColor) {1.0f, 1.0f, 1.0f, 1.0f}, state->renderer);
        vec3 position = {
            (float) (random_int (-50, 50) * 2 + 1),
            (float) (random_int (-50, 50) * 2 + 1),
            (float) (random_int (-50, 50) * 2 + 1),
        };
        add_transform (
            point_light, position, (vec3) {0.0f, 0.0f, 0.0f},
            (vec3) {1.0f, 1.0f, 1.0f}
        );
    }

    // camera
    Entity camera = create_entity ();
    add_transform (
        camera, (vec3) {0.0f, 0.0f, -2.0f}, (vec3) {0.0f, 0.0f, 0.0f},
        (vec3) {1.0f, 1.0f, 1.0f}
    );
    add_camera (camera, STARTING_FOV, 0.01f, 1000.0f);
    add_fps_controller (camera, MOUSE_SENSE, MOVEMENT_SPEED);

    state->last_time = SDL_GetPerformanceCounter ();

    *appstate = state;
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate (void* appstate) {
    AppState* state = (AppState*) appstate;
    if (state->quit) return SDL_APP_SUCCESS;

    // TODO: handle no camera
    Entity cam = state->player;
    if (cam == (Entity) -1) return SDL_APP_CONTINUE;
    TransformComponent* cam_trans = get_transform (cam);

    // dt
    const Uint64 now = SDL_GetPerformanceCounter ();
    float dt = (float) (now - state->last_time) /
               (float) (SDL_GetPerformanceFrequency ());
    state->last_time = now;

    float render_time_ms = (float) (state->postrender - state->prerender) / 1e6;
    float mesh_time_ms = (float) (state->preui - state->prerender) / 1e6;
    float ui_time_ms = (float) (state->postrender - state->preui) / 1e6;
    state->frame_count++;

    UIComponent* ui = get_ui (cam);
    if (state->debug) {
        char buffer[64];
        sprintf (buffer, "Mesh render: %.1f", mesh_time_ms);
        draw_text (ui, state->renderer->device, buffer, 5.0f, 5.0f, 1.0f, 1.0f, 1.0f, 1.0f);
        sprintf (buffer, "UI render: %.1f", ui_time_ms);
        draw_text (ui, state->renderer->device, buffer, 5.0f, 17.0f, 1.0f, 1.0f, 1.0f, 1.0f);
        sprintf (buffer, "Total render: %.1f", render_time_ms);
        draw_text (ui, state->renderer->device, buffer, 5.0f, 29.0f, 1.0f, 1.0f, 1.0f, 1.0f);
        if (state->frame_count % 60 == 0) {
            state->frame_rate = 1000.0f / render_time_ms;
        }
        sprintf (buffer, "Framerate: %.3f", state->frame_rate);
        draw_text (ui, state->renderer->device, buffer, 5.0f, 41.0f, 1.0f, 1.0f, 1.0f, 1.0f);
    } else {
        draw_text (ui, state->renderer->device, "f3: Debug Menu", 5.0f, 5.0f, 1.0f, 1.0f, 1.0f, 1.0f);
    }

    for (Uint32 i = 0; i < 8000; i++) {
        Entity icosahedron = icosahedrons[i];

        TransformComponent transform = *get_transform (icosahedron);
        vec3 rotation = euler_from_quat (transform.rotation);
        rotation.x += 0.005f;
        rotation.z += 0.01f;
        transform.rotation = quat_from_euler (rotation);
        add_transform (
            icosahedron, transform.position, rotation, transform.scale
        );
    }

    fps_controller_update_system (dt);

    render_system (state->renderer, cam, &state->prerender, &state->preui, &state->postrender);

    return SDL_APP_CONTINUE;
}

void SDL_AppQuit (void* appstate, SDL_AppResult result) {
    AppState* state = (AppState*) appstate;

    UIComponent ui = *(get_ui (state->player));

    if (ui.rects) free (ui.rects);
    if (ui.pipeline)
        SDL_ReleaseGPUGraphicsPipeline (state->renderer->device, ui.pipeline);
    if (ui.fragment) SDL_ReleaseGPUShader (state->renderer->device, ui.fragment);
    if (ui.vertex) SDL_ReleaseGPUShader (state->renderer->device, ui.vertex);

    free_pools (state->renderer->device);
    if (state->white_texture) {
        SDL_ReleaseGPUTexture (state->renderer->device, state->white_texture);
    }
    // TODO: update free pools lol
    // if (state->renderer->sampler) {
    //     SDL_ReleaseGPUSampler (state->renderer->device, state->renderer->sampler);
    // }
    if (state->renderer->depth_texture) {
        SDL_ReleaseGPUTexture (state->renderer->device, state->renderer->depth_texture);
    }
    free (state->renderer);

}