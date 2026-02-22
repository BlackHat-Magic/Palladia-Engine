#define SDL_MAIN_USE_CALLBACKS 1

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <SDL3/SDL_main.h>

#include <microui.h>

#include <geometry/circle.h>
#include <geometry/plane.h>
#include <geometry/ring.h>

#include <geometry/box.h>
#include <geometry/dodecahedron.h>
#include <geometry/icosahedron.h>
#include <geometry/octahedron.h>
#include <geometry/tetrahedron.h>

#include <geometry/capsule.h>
#include <geometry/cone.h>
#include <geometry/cylinder.h>
#include <geometry/sphere.h>
#include <geometry/torus.h>

#include <material/phong_material.h>
#include <ui/ui.h>

#define STARTING_WIDTH 1280
#define STARTING_HEIGHT 720
#define STARTING_FOV 70.0
#define MOUSE_SENSE 1.0f / 100.0f
#define MOVEMENT_SPEED 3.0f

typedef enum {
    GEO_CIRCLE = 0,
    GEO_PLANE,
    GEO_RING,

    GEO_TETRAHEDRON,
    GEO_BOX,
    GEO_OCTAHEDRON,
    GEO_DODECAHEDRON,
    GEO_ICOSAHEDRON,

    GEO_CAPSULE,
    GEO_CONE,
    GEO_CYLINDER,
    GEO_SPHERE,
    GEO_TORUS,
} geometry;

typedef struct {
    bool quit;
    PAL_GPURenderer* renderer;
    Entity player;
    Entity entity;
    PAL_MeshComponent* meshes[13];
    geometry current_mesh;
    Uint8 test;
    Uint64 last_time;
    Uint64 prerender;
    Uint64 preui;
    Uint64 postrender;
    float frame_rate;
    Uint64 frame_count;
    bool debug;
    bool settings;
    SDL_GPUTexture* white_texture;
} AppState;

static Uint32
uint8_slider (mu_Context* ctx, Uint8* value, Uint32 low, Uint32 high) {
    static float tmp;
    mu_push_id (ctx, &value, sizeof (value));
    tmp = *value;
    Uint32 res =
        mu_slider_ex (ctx, &tmp, low, high, 0, "%.0f", MU_OPT_ALIGNCENTER);
    *value = tmp;
    mu_pop_id (ctx);
    return res;
}

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
        if (event->key.key == SDLK_ESCAPE) {
            state->settings = !state->settings;
            SDL_SetWindowRelativeMouseMode (
                state->renderer->window, !state->settings
            );
            return SDL_APP_CONTINUE;
            // break;
        }
        if (event->key.key == SDLK_F3) state->debug = !state->debug;
        if (event->key.key == SDLK_UP) {
            if (state->current_mesh < GEO_TORUS) {
                PAL_MeshComponent* current_mesh =
                    PAL_GetMeshComponent (state->entity);
                *current_mesh = *state->meshes[++state->current_mesh];
            }
        }
        if (event->key.key == SDLK_DOWN) {
            if (state->current_mesh > GEO_CIRCLE) {
                PAL_MeshComponent* current_mesh =
                    PAL_GetMeshComponent (state->entity);
                *current_mesh = *state->meshes[--state->current_mesh];
            }
        }
        break;
    }

    if (state->settings) {
        UIComponent* ui = get_ui (state->player);
        ui_handle_event (event, ui);
    } else {
        fps_controller_event_system (event);
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppInit (void** appstate, int argc, char** argv) {
    SDL_SetAppMetadata (
        "Asmadi Engine Box Geometry", "0.1.0", "xyz.lukeh.Asmadi-Engine"
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
        "Guess what I brought... RECTANGLES!!!", STARTING_WIDTH,
        STARTING_HEIGHT, SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN
    );
    if (window == NULL) {
        SDL_Log ("Couldn't create window/renderer: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // Initialize SDL_ttf
    if (!TTF_Init ()) {
        SDL_Log ("Couldn't initialize SDL_ttf: %s", SDL_GetError ());
        return SDL_APP_FAILURE;
    }

    // create GPU device
    SDL_GPUDevice* device =
        SDL_CreateGPUDevice (SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
    if (device == NULL) {
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
    if (state->white_texture == NULL) return SDL_APP_FAILURE;

    // player
    state->player = create_entity ();
    PAL_TransformCreateInfo player_transform_info = {
        .position = (vec3) {0.0f, 0.0f, -2.0f},
        .rotation = (vec3) {0.0f, 0.0f, 0.0f},
        .scale = (vec3) {1.0f, 1.0f, 1.0f}
    };
    add_transform (state->player, &player_transform_info);
    PAL_CameraCreateInfo camera_info =
        {.fov = STARTING_FOV, .near_clip = 0.01f, .far_clip = 1000.0f};
    add_camera (state->player, &camera_info);
    PAL_FpsControllerCreateInfo fps_info = {
        .mouse_sense = MOUSE_SENSE,
        .move_speed = MOVEMENT_SPEED
    };
    add_fps_controller (state->player, &fps_info);
    state->settings = false;
    SDL_SetWindowRelativeMouseMode (state->renderer->window, !state->settings);
    UIComponent* ui = create_ui_component (
        state->renderer, 255, 255, "./assets/NotoSans-Regular.ttf", 12.0f
    );
    if (ui == NULL) {
        // logging handled inside function
        return SDL_APP_FAILURE;
    }
    add_ui (state->player, ui);
    // ui->context.style->title_height = 30;
    // ui->context.style->padding = 6;

    // torus entity
    state->entity = create_entity ();

    // circle mesh
    PAL_CircleMeshCreateInfo circle_info =
        {.radius = 0.5f, .segments = 16, .device = state->renderer->device};
    state->meshes[GEO_CIRCLE] = PAL_CreateCircleMesh (&circle_info);
    if (state->meshes[GEO_CIRCLE] == NULL) return SDL_APP_FAILURE;

    // plane
    PAL_PlaneMeshCreateInfo plane_info = {
        .width = 1.0f,
        .height = 1.0f,
        .width_segments = 1,
        .height_segments = 1,
        .device = state->renderer->device
    };
    state->meshes[GEO_PLANE] = PAL_CreatePlaneMesh (&plane_info);
    if (state->meshes[GEO_PLANE] == NULL) return SDL_APP_FAILURE;

    // ring
    PAL_RingMeshCreateInfo ring_info = {
        .inner_radius = 0.25f,
        .outer_radius = 0.5f,
        .theta_segments = 16,
        .phi_segments = 16,
        .theta_start = 0.0f,
        .theta_length = 2.0 * (float) M_PI,
        .device = state->renderer->device
    };
    state->meshes[GEO_RING] = PAL_CreateRingMesh (&ring_info);
    if (state->meshes[GEO_RING] == NULL) return SDL_APP_FAILURE;

    // tetrahedron
    PAL_TetrahedronMeshCreateInfo tetrahedron_info = {
        .radius = 0.5f,
        .device = state->renderer->device
    };
    state->meshes[GEO_TETRAHEDRON] =
        PAL_CreateTetrahedronMesh (&tetrahedron_info);
    if (state->meshes[GEO_TETRAHEDRON] == NULL) return SDL_APP_FAILURE;

    // box mesh
    PAL_BoxMeshCreateInfo box_info =
        {.l = 1.0f, .w = 1.0f, .h = 1.0f, .device = state->renderer->device};
    state->meshes[GEO_BOX] = PAL_CreateBoxMesh (&box_info);
    if (state->meshes[GEO_BOX] == NULL) return SDL_APP_FAILURE;

    // octahedron
    PAL_OctahedronMeshCreateInfo octahedron_info = {
        .radius = 0.5f,
        .device = state->renderer->device
    };
    state->meshes[GEO_OCTAHEDRON] = PAL_CreateOctahedronMesh (&octahedron_info);
    if (state->meshes[GEO_OCTAHEDRON] == NULL) return SDL_APP_FAILURE;

    // dodecahedron
    PAL_DodecahedronMeshCreateInfo dodecahedron_info = {
        .radius = 0.5f,
        .device = state->renderer->device
    };
    state->meshes[GEO_DODECAHEDRON] =
        PAL_CreateDodecahedronMesh (&dodecahedron_info);
    if (state->meshes[GEO_DODECAHEDRON] == NULL) return SDL_APP_FAILURE;

    // icosahedron
    PAL_IcosahedronMeshCreateInfo icosahedron_info = {
        .radius = 0.5f,
        .device = state->renderer->device
    };
    state->meshes[GEO_ICOSAHEDRON] =
        PAL_CreateIcosahedronMesh (&icosahedron_info);
    if (state->meshes[GEO_ICOSAHEDRON] == NULL) return SDL_APP_FAILURE;

    // capsule
    PAL_CapsuleMeshCreateInfo capsule_info = {
        .radius = 0.5f,
        .height = 1.0f,
        .cap_segments = 8,
        .radial_segments = 16,
        .device = state->renderer->device,
    };
    state->meshes[GEO_CAPSULE] = PAL_CreateCapsuleMesh (&capsule_info);
    if (state->meshes[GEO_CAPSULE] == NULL) return SDL_APP_FAILURE;

    // cone
    PAL_ConeMeshCreateInfo cone_info = {
        .radius = 0.5f,
        .height = 1.0f,
        .radial_segments = 16,
        .height_segments = 1,
        .open_ended = false,
        .theta_start = 0.0f,
        .theta_length = 2.0f * (float) M_PI,
        .device = state->renderer->device
    };
    state->meshes[GEO_CONE] = PAL_CreateConeMesh (&cone_info);
    if (state->meshes[GEO_CONE] == NULL) return SDL_APP_FAILURE;

    // cylinder
    PAL_CylinderMeshCreateInfo cylinder_info = {
        .radius_top = 0.5f,
        .radius_bottom = 0.5f,
        .height = 1.0f,
        .radial_segments = 16,
        .height_segments = 1,
        .open_ended = false,
        .theta_start = 0.0f,
        .theta_length = 2.0f * (float) M_PI,
        .device = state->renderer->device
    };
    state->meshes[GEO_CYLINDER] = PAL_CreateCylinderMesh (&cylinder_info);
    if (state->meshes[GEO_CYLINDER] == NULL) return SDL_APP_FAILURE;

    // sphere
    PAL_SphereMeshCreateInfo sphere_info = {
        .radius = 0.5f,
        .width_segments = 32,
        .height_segments = 16,
        .phi_start = 0.0f,
        .phi_length = (float) M_PI * 2.0f,
        .theta_start = 0.0f,
        .theta_length = (float) M_PI,
        .device = state->renderer->device,
    };
    state->meshes[GEO_SPHERE] = PAL_CreateSphereMesh (&sphere_info);
    if (state->meshes[GEO_SPHERE] == NULL) return SDL_APP_FAILURE;

    // torus
    PAL_TorusMeshCreateInfo torus_info = {
        .radius = 0.5f,
        .tube_radius = 0.2f,
        .radial_segments = 16,
        .tubular_segments = 32,
        .arc = (float) M_PI * 2.0f,
        .device = state->renderer->device
    };
    state->meshes[GEO_TORUS] = PAL_CreateTorusMesh (&torus_info);
    if (state->meshes[GEO_TORUS] == NULL) return SDL_APP_FAILURE;

    // add mesh
    PAL_AddMeshComponent (state->entity, state->meshes[0]);

    // torus material
    SDL_GPUSamplerCreateInfo torus_sampler_info = {
        .min_filter = SDL_GPU_FILTER_LINEAR,
        .mag_filter = SDL_GPU_FILTER_LINEAR,
        .mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
        .address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .max_anisotropy = 1.0f,
        .enable_anisotropy = false
    };
    SDL_GPUSampler* torus_sampler =
        SDL_CreateGPUSampler (state->renderer->device, &torus_sampler_info);
    PAL_PhongMaterialCreateInfo phong_info = {
        .renderer = state->renderer,
        .color = (SDL_FColor) {1.0f, 1.0f, 1.0f, 1.0f},
        .emissive = (SDL_FColor) {0.0f, 0.0f, 0.0f, 0.0f},
        .cullmode = SDL_GPU_CULLMODE_BACK,
        .texture = state->white_texture,
        .sampler = torus_sampler
    };
    PAL_MaterialComponent* torus_material =
        PAL_CreatePhongMaterial (&phong_info);
    PAL_AddMaterialComponent (state->entity, torus_material);

    // torus transform
    PAL_TransformCreateInfo torus_transform_info = {
        .position = (vec3) {0.0f, 0.0f, 0.0f},
        .rotation = (vec3) {0.0f, 0.0f, 0.0f},
        .scale = (vec3) {1.0f, 1.0f, 1.0f}
    };
    add_transform (state->entity, &torus_transform_info);

    // ambient light
    Entity ambient_light = create_entity ();
    PAL_AmbientLightCreateInfo ambient_info = {
        .color = (SDL_FColor) {1.0f, 1.0f, 1.0f, 0.1f},
        .renderer = state->renderer
    };
    add_ambient_light (ambient_light, &ambient_info);

    // point light
    Entity point_light = create_entity ();
    PAL_TransformCreateInfo point_light_transform_info = {
        .position = (vec3) {2.0f, 2.0f, -2.0f},
        .rotation = (vec3) {0.0f, 0.0f, 0.0f},
        .scale = (vec3) {1.0f, 1.0f, 1.0f}
    };
    add_transform (point_light, &point_light_transform_info);
    PAL_PointLightCreateInfo point_light_info = {
        .color = (SDL_FColor) {1.0f, 1.0f, 1.0f, 1.0f},
        .renderer = state->renderer
    };
    add_point_light (point_light, &point_light_info);

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

    // draw ui
    UIComponent* ui = get_ui (state->player);
    mu_begin (&ui->context);
    if (state->settings) {
        if (mu_begin_window (
                &ui->context, "Test Window", mu_rect (250, 250, 300, 240)
            )) {
            mu_layout_row (&ui->context, 1, (Uint32[]) {80}, 0);
            mu_label (&ui->context, "Test label");
            uint8_slider (&ui->context, &state->test, 0, 255);
            mu_end_window (&ui->context);
        }
    }
    mu_end (&ui->context);

    if (state->debug) {
        char buffer[64];
        sprintf (buffer, "Mesh render: %.1f", mesh_time_ms);
        draw_text (
            ui, state->renderer->device, buffer, 5.0f, 5.0f, 1.0f, 1.0f, 1.0f,
            1.0f
        );
        sprintf (buffer, "UI render: %.1f", ui_time_ms);
        draw_text (
            ui, state->renderer->device, buffer, 5.0f, 17.0f, 1.0f, 1.0f, 1.0f,
            1.0f
        );
        sprintf (buffer, "Total render: %.1f", render_time_ms);
        draw_text (
            ui, state->renderer->device, buffer, 5.0f, 29.0f, 1.0f, 1.0f, 1.0f,
            1.0f
        );
        if (state->frame_count % 60 == 0) {
            state->frame_rate = 1000.0f / render_time_ms;
        }
        sprintf (buffer, "Framerate: %.3f", state->frame_rate);
        draw_text (
            ui, state->renderer->device, buffer, 5.0f, 41.0f, 1.0f, 1.0f, 1.0f,
            1.0f
        );
    } else {
        draw_text (
            ui, state->renderer->device, "f3: Debug Menu", 5.0f, 5.0f, 1.0f,
            1.0f, 1.0f, 1.0f
        );
    }

    TransformComponent transform = *get_transform (state->entity);
    vec3 rotation = euler_from_quat (transform.rotation);
    rotation.x += 0.005f;
    rotation.z += 0.01f;
    transform.rotation = quat_from_euler (rotation);
    PAL_TransformCreateInfo entity_transform_info = {
        .position = transform.position,
        .rotation = rotation,
        .scale = transform.scale
    };
    add_transform (state->entity, &entity_transform_info);

    // camera forward vector
    if (!state->settings) fps_controller_update_system (dt);

    render_system (
        state->renderer, cam, &state->prerender, &state->preui,
        &state->postrender
    );

    return SDL_APP_CONTINUE;
}

void SDL_AppQuit (void* appstate, SDL_AppResult result) {
    AppState* state = (AppState*) appstate;

    UIComponent ui = *(get_ui (state->player));

    if (ui.rects) free (ui.rects);
    if (ui.pipeline)
        SDL_ReleaseGPUGraphicsPipeline (state->renderer->device, ui.pipeline);
    if (ui.fragment)
        SDL_ReleaseGPUShader (state->renderer->device, ui.fragment);
    if (ui.vertex) SDL_ReleaseGPUShader (state->renderer->device, ui.vertex);

    free_pools (state->renderer->device);
    if (state->white_texture) {
        SDL_ReleaseGPUTexture (state->renderer->device, state->white_texture);
    }
    // TODO: update free pools lol
    // if (state->renderer->sampler) {
    //     SDL_ReleaseGPUSampler (state->renderer->device,
    //     state->renderer->sampler);
    // }
    if (state->renderer->depth_texture) {
        SDL_ReleaseGPUTexture (
            state->renderer->device, state->renderer->depth_texture
        );
    }
    free (state->renderer);
}