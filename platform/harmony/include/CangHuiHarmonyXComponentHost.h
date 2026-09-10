#ifndef CANGHUI_HARMONY_XCOMPONENT_HOST_H
#define CANGHUI_HARMONY_XCOMPONENT_HOST_H

#include <stdint.h>

#define CANGHUI_HARMONY_XCOMPONENT_HOST_ABI_VERSION 1
#define CANGHUI_HARMONY_POINTER_ABI_VERSION 2

#ifdef __cplusplus
extern "C" {
#endif

int64_t canghui_harmony_xcomponent_host_abi_version(void);
int64_t canghui_harmony_surface_attach(
    int64_t native_window,
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_harmony_surface_resize(
    int64_t pixel_width,
    int64_t pixel_height,
    int64_t scale_milli,
    int64_t generation);
int64_t canghui_harmony_surface_detach(int64_t generation);
int64_t canghui_harmony_surface_frame(
    int64_t timestamp_nanos,
    int64_t target_timestamp_nanos,
    int64_t generation);
int64_t canghui_harmony_pointer_v2(
    int64_t phase,
    int64_t kind,
    int64_t pointer_id,
    int64_t source_device_id,
    int64_t x_milli,
    int64_t y_milli,
    int64_t coordinate_space,
    int64_t buttons,
    int64_t pressure_milli,
    int64_t contact_width_milli,
    int64_t contact_height_milli,
    int64_t tilt_x_milli,
    int64_t tilt_y_milli,
    int64_t timestamp_nanos,
    int64_t captured_scale_milli,
    int64_t transform_revision,
    int64_t orientation_revision,
    int64_t generation);
int64_t canghui_harmony_orientation_revision(int64_t revision, int64_t generation);

#ifdef __cplusplus
}
#endif

#endif
