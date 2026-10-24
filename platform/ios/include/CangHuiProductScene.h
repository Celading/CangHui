#ifndef CANGHUI_PRODUCT_SCENE_H
#define CANGHUI_PRODUCT_SCENE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * C ABI for the reference iOS product consumer. The application owns the
 * counter, text and action labels; chui.native_scene builds the Draw IR.
 */
int32_t canghui_ios_product_render(
    int64_t width_milli,
    int64_t height_milli,
    int64_t event_kind,
    int64_t x_milli,
    int64_t y_milli,
    uint8_t * _Nullable output,
    int64_t output_capacity,
    int64_t * _Nonnull output_length);

int32_t canghui_ios_product_set_text(const uint8_t * _Nullable text, int64_t length);
int32_t canghui_ios_product_key(int64_t phase, int64_t key_code);

int64_t canghui_ios_product_counter(void);
int64_t canghui_ios_product_render_count(void);
int64_t canghui_ios_product_input_count(void);
int64_t canghui_ios_product_key_count(void);
int64_t canghui_ios_product_ime_count(void);
int64_t canghui_ios_product_last_key_code(void);

int32_t canghui_ios_product_input_text(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);

int32_t canghui_ios_product_last_action(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);

int32_t canghui_ios_product_state(
    uint8_t * _Nullable output, int64_t capacity, int64_t * _Nonnull length);

#ifdef __cplusplus
}
#endif

#endif
