#ifndef CHUI_ACCESSKIT_UNIX_ADAPTER_H
#define CHUI_ACCESSKIT_UNIX_ADAPTER_H
#include "semantic_bridge.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Linux/BSD owner-thread API. A handle is a nonrecycled token, never an address.
 * All calls for a handle must be serialized on its UI owner. Native callbacks
 * never call application code. The bridge/library must stay loaded until exit:
 * upstream free asynchronously unregisters and does not join late callbacks.
 */
CHUI_AK_API uint64_t chui_ak_unix_new(void);
/* Consumes update even on rejection/inactive adapter. Supply only a successfully
 * finished full tree from semantic_bridge. Revision must strictly increase.
 */
CHUI_AK_API bool chui_ak_unix_publish(uint64_t handle, uint64_t revision,
                                    struct accesskit_tree_update *update);
CHUI_AK_API bool chui_ak_unix_focus(uint64_t handle, bool focused);
CHUI_AK_API bool chui_ak_unix_bounds(uint64_t handle, double outer_x, double outer_y,
    double outer_w, double outer_h, double inner_x, double inner_y,
    double inner_w, double inner_h);
/* Returns one copied native action using bridge-local action bits. The host
 * must forward via SemanticNativeSession and its existing owner queue/runtime.
 * Native revision means last successfully submitted frame at callback ingress,
 * not an AT-SPI-client-supplied version. During publication it retains the
 * previous revision; the managed continuity gate must validate it on drain.
 */
CHUI_AK_API bool chui_ak_unix_poll(uint64_t handle, uint64_t *target,
                                 uint64_t *revision, uint32_t *action);
CHUI_AK_API uint64_t chui_ak_unix_dropped(uint64_t handle);
/* Idempotent; revokes queued/late callbacks before asynchronous native free. */
CHUI_AK_API void chui_ak_unix_close(uint64_t handle);

#ifdef __cplusplus
}
#endif
#endif
