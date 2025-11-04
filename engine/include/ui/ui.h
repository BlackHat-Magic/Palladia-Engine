#pragma once

#include <ecs/ecs.h>
#include <material/m_common.h>

void ui_handle_event (SDL_Event* event, UIComponent* ui);

UIComponent* create_ui_component (
    const PAL_GPURenderer* renderer,
    const int max_rects,
    const int max_texts,
    const char* font_path,
    const float ptsize
);

void draw_rectangle (
    UIComponent* ui,
    const float x,
    const float y,
    const float w,
    const float h,
    const float r,
    const float g,
    const float b,
    const float a
);

int draw_text (
    UIComponent* ui,
    SDL_GPUDevice* device,
    const char* utf8,
    float x,
    float y,
    float r,
    float g,
    float b,
    float a
);