#include <stdlib.h>

#include <SDL3/SDL_gpu.h>

#include <material/m_common.h>
#include <material/phong_material.h>

PAL_MaterialComponent* PAL_CreatePhongMaterial (const PAL_PhongMaterialCreateInfo* info) {
    PAL_MaterialComponent* mat = malloc (sizeof (PAL_MaterialComponent));
    if (mat == NULL) return NULL;

    PAL_ShaderCreateInfo vertex_info = {
        .device = info->renderer->device,
        .filename = "shaders/phong_material.vert.spv",
        .stage = SDL_GPU_SHADERSTAGE_VERTEX,
        .sampler_count = 0,
        .uniform_buffer_count = 2,
        .storage_buffer_count = 0,
        .storage_texture_count = 0
    };
    SDL_GPUShader* vertex_shader = PAL_LoadShader (&vertex_info);
    if (vertex_shader == NULL) {
        free (mat);
        return NULL;
    }

    PAL_ShaderCreateInfo fragment_info = {
        .device = info->renderer->device,
        .filename = "shaders/phong_material.frag.spv",
        .stage = SDL_GPU_SHADERSTAGE_FRAGMENT,
        .sampler_count = 1,
        .uniform_buffer_count = 1,
        .storage_buffer_count = 2,
        .storage_texture_count = 0
    };
    SDL_GPUShader* fragment_shader = PAL_LoadShader (&fragment_info);
    if (fragment_shader == NULL) {
        free (mat);
        SDL_ReleaseGPUShader (info->renderer->device, vertex_shader);
        return NULL;
    }

    SDL_GPUGraphicsPipelineCreateInfo pipe_info = {
        .target_info =
            {.num_color_targets = 1,
             .color_target_descriptions =
                 (SDL_GPUColorTargetDescription[]) {
                     {.format = info->renderer->format}
                 },
             .has_depth_stencil_target = true,
             .depth_stencil_format = SDL_GPU_TEXTUREFORMAT_D24_UNORM},
        .primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state =
            {.vertex_buffer_descriptions =
                 (SDL_GPUVertexBufferDescription[]) {
                     {.slot = 0,
                      .pitch = 8 * sizeof (float),
                      .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX,
                      .instance_step_rate = 0}
                 },
             .num_vertex_buffers = 1,
             .num_vertex_attributes = 3,
             .vertex_attributes =
                 (SDL_GPUVertexAttribute[]) {
                     {.location = 0,
                      .buffer_slot = 0,
                      .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
                      .offset = 0},
                     {.location = 1,
                      .buffer_slot = 0,
                      .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
                      .offset = 3 * sizeof (float)},
                     {.location = 2,
                      .buffer_slot = 0,
                      .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
                      .offset = 6 * sizeof (float)}
                 }},
        .rasterizer_state =
            {.fill_mode = SDL_GPU_FILLMODE_FILL,
             .cull_mode = info->cullmode,
             .front_face = SDL_GPU_FRONTFACE_CLOCKWISE},
        .depth_stencil_state = {
            .enable_depth_test = true,
            .enable_depth_write = true,
            .compare_op = SDL_GPU_COMPAREOP_LESS,
            .enable_stencil_test = false
        }
    };
    SDL_GPUGraphicsPipeline* pipeline = SDL_CreateGPUGraphicsPipeline (info->renderer->device, &pipe_info);
    if (pipeline == NULL) {
        free (mat);
        SDL_ReleaseGPUShader (info->renderer->device, vertex_shader);
        SDL_ReleaseGPUShader (info->renderer->device, fragment_shader);
        return NULL;
    }

    SDL_GPUCommandBuffer* cmd = SDL_AcquireGPUCommandBuffer (info->renderer->device);
    if (cmd == NULL) {
        free (mat);
        SDL_ReleaseGPUShader (info->renderer->device, vertex_shader);
        SDL_ReleaseGPUShader (info->renderer->device, fragment_shader);
        SDL_ReleaseGPUGraphicsPipeline (info->renderer->device, pipeline);
        return NULL;
    }

    // material UBO (descriptor set 1)
    Uint32 ubo_size = 0;
    ubo_size += sizeof (info->color);
    ubo_size += sizeof (info->emissive);
    // PBR params (metallic, roughness, specular, sheen, clearcoat, IOR, etc.)
    // opacity/alpha cutoff for alpha test
    // UV transform/scale/offset (prob not)
    // flags/modes
    // indices/scales for texture channels
    Uint8 fragment_ubo[ubo_size > 0 ? ubo_size : 1];
    memcpy (fragment_ubo, &info->color, sizeof (info->color));
    memcpy (fragment_ubo + sizeof (info->color), &info->emissive, sizeof (info->emissive));
    SDL_PushGPUFragmentUniformData (cmd, 0, fragment_ubo, ubo_size);

    *mat = (PAL_MaterialComponent) {
        .color = info->color,
        .emissive = info->emissive,
        .texture = info->texture,
        .sampler = info->sampler,
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .pipeline = pipeline
    };

    return mat;
}