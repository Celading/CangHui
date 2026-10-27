#ifndef CANGHUI_DESKTOP_SCENE_H
#define CANGHUI_DESKTOP_SCENE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * C ABI for the iPad desktop shell sample. The Cangjie scene owns all layout
 * and state; UIKit owns the surface, pointer, hardware keyboard and IME.
 */
int32_t canghui_ios_desktop_render(
    int64_t width_milli,
    int64_t height_milli,
    int64_t event_kind,
    int64_t x_milli,
    int64_t y_milli,
    uint8_t * _Nullable output,
    int64_t output_capacity,
    int64_t * _Nonnull output_length);

int32_t canghui_ios_desktop_set_text(const uint8_t * _Nullable text, int64_t length);
int32_t canghui_ios_desktop_hover(int64_t phase, int64_t x_milli, int64_t y_milli);
int32_t canghui_ios_desktop_key(int64_t phase, int64_t key_code, int64_t modifiers,
    int32_t repeat);
int32_t canghui_ios_desktop_activate(const uint8_t * _Nullable action, int64_t length);
int32_t canghui_ios_desktop_set_profile(int64_t idiom, int64_t device_class,
    int64_t breakpoint, int32_t uses_sidebar, int64_t scale_milli);

int64_t canghui_ios_desktop_section(void);
int64_t canghui_ios_desktop_track(void);
int32_t canghui_ios_desktop_playing(void);
int64_t canghui_ios_desktop_render_count(void);
int64_t canghui_ios_desktop_input_count(void);
int64_t canghui_ios_desktop_key_count(void);
int64_t canghui_ios_desktop_ime_count(void);

int32_t canghui_ios_desktop_search_text(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);
int32_t canghui_ios_desktop_hover_id(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);
int32_t canghui_ios_desktop_last_action(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);
int32_t canghui_ios_desktop_state(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);

#ifdef __cplusplus
}
#endif

#endif
