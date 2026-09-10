#include "unix_adapter.h"
#include <pthread.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define CHUI_AK_WINDOWS 64u
#define CHUI_AK_INGRESS 128u
struct ingress { uint64_t target, revision; uint32_t action; };
struct unix_session {
    uint64_t token, revision, dropped, activation_generation;
    struct accesskit_unix_adapter *native;
    struct ingress queue[CHUI_AK_INGRESS];
    unsigned head, count;
    bool updating, refresh_requested;
};
static pthread_mutex_t registry_mutex = PTHREAD_MUTEX_INITIALIZER;
static struct unix_session *registry[CHUI_AK_WINDOWS];
static uint64_t next_token;

/* The registry lock protects callback ingress only. Never hold it while entering
 * AccessKit: its own state mutex may be held by a foreign callback thread. */
static struct unix_session *find_session(uint64_t token) {
    for (unsigned i = 0; i < CHUI_AK_WINDOWS; ++i)
        if (registry[i] && registry[i]->token == token) return registry[i];
    return NULL;
}
static void dropped(struct unix_session *s) {
    if (s->dropped != UINT64_MAX) ++s->dropped;
}
static struct accesskit_tree_update *activate(void *userdata) {
    uint64_t token = (uint64_t)(uintptr_t)userdata;
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(token);
    if (s && s->activation_generation != UINT64_MAX) {
        ++s->activation_generation;
        s->refresh_requested = true;
    }
    pthread_mutex_unlock(&registry_mutex);
    /* NULL is explicitly allowed for activation (not for update factories).
     * AccessKit enters Pending; the UI owner publishes or replays its cached tree. */
    return NULL;
}
static void deactivate(void *userdata) {
    uint64_t token = (uint64_t)(uintptr_t)userdata;
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(token);
    if (s) {
        s->head = 0; s->count = 0;
        if (s->activation_generation != UINT64_MAX) ++s->activation_generation;
        s->refresh_requested = false;
    }
    pthread_mutex_unlock(&registry_mutex);
}
static void receive_action(struct accesskit_action_request *request, void *userdata) {
    if (!request) return;
    uint32_t action = 0;
    switch (request->action) {
        case ACCESSKIT_ACTION_FOCUS: action = CHUI_AK_FOCUS; break;
        case ACCESSKIT_ACTION_CLICK: action = CHUI_AK_ACTIVATE; break;
        case ACCESSKIT_ACTION_INCREMENT: action = CHUI_AK_INCREMENT; break;
        case ACCESSKIT_ACTION_DECREMENT: action = CHUI_AK_DECREMENT; break;
        default: break;
    }
    uint64_t token = (uint64_t)(uintptr_t)userdata;
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(token);
    if (s) {
        if (!action || request->target_node <= 1 ||
            memcmp(request->target_tree.bytes, ACCESSKIT_TREE_ID_ROOT.bytes, sizeof(request->target_tree.bytes)) ||
            !s->revision || s->count == CHUI_AK_INGRESS) {
            dropped(s);
        } else {
            unsigned tail = (s->head + s->count++) % CHUI_AK_INGRESS;
            /* During publication keep the previous revision. Only the managed
             * continuity gate can prove this action crosses unchanged frames. */
            s->queue[tail] = (struct ingress){request->target_node, s->revision, action};
        }
    }
    pthread_mutex_unlock(&registry_mutex);
    accesskit_action_request_free(request);
}

uint64_t chui_ak_unix_new(void) {
    struct unix_session *s = calloc(1, sizeof(*s));
    if (!s) return 0;
    pthread_mutex_lock(&registry_mutex);
    unsigned index = 0;
    while (index < CHUI_AK_WINDOWS && registry[index]) ++index;
    if (index == CHUI_AK_WINDOWS || next_token == UINTPTR_MAX) {
        pthread_mutex_unlock(&registry_mutex); free(s); return 0;
    }
    s->token = ++next_token;
    registry[index] = s;
    pthread_mutex_unlock(&registry_mutex);
    void *token = (void *)(uintptr_t)s->token; /* opaque, never dereferenced */
    s->native = accesskit_unix_adapter_new(activate, token, receive_action, token, deactivate, token);
    if (!s->native) { chui_ak_unix_close(s->token); return 0; }
    return s->token;
}

uint32_t chui_ak_unix_abi_version(void) { return 1; }
bool chui_ak_unix_needs_refresh(uint64_t handle) {
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    bool result = s && s->revision && s->refresh_requested && !s->updating;
    pthread_mutex_unlock(&registry_mutex);
    return result;
}

static struct accesskit_tree_update *take_update(void *userdata) {
    struct accesskit_tree_update **pending = userdata;
    struct accesskit_tree_update *result = *pending;
    *pending = NULL;
    return result;
}
static bool submit(uint64_t handle, uint64_t revision, struct accesskit_tree_update *update, bool replay) {
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    bool valid = s && update && revision && !s->updating && (replay ?
        (revision == s->revision && s->refresh_requested) : revision > s->revision);
    uint64_t generation = s ? s->activation_generation : 0;
    if (valid) s->updating = true;
    pthread_mutex_unlock(&registry_mutex);
    if (!valid) { if (update) accesskit_tree_update_free(update); return false; }
    /* The pinned adapter calls FnOnce synchronously and only when active/pending.
     * A finished, non-null update exists before entering this non-null factory. */
    accesskit_unix_adapter_update_if_active(s->native, take_update, &update);
    bool consumed = !update;
    if (update) accesskit_tree_update_free(update); /* inactive: factory not called */
    pthread_mutex_lock(&registry_mutex);
    s->revision = revision;
    s->updating = false;
    if (consumed && generation == s->activation_generation) s->refresh_requested = false;
    pthread_mutex_unlock(&registry_mutex);
    return true;
}
bool chui_ak_unix_publish(uint64_t handle, uint64_t revision, struct accesskit_tree_update *update) {
    return submit(handle, revision, update, false);
}
bool chui_ak_unix_refresh(uint64_t handle, uint64_t revision, struct accesskit_tree_update *update) {
    return submit(handle, revision, update, true);
}
bool chui_ak_unix_focus(uint64_t handle, bool focused) {
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    pthread_mutex_unlock(&registry_mutex);
    if (!s) return false;
    accesskit_unix_adapter_update_window_focus_state(s->native, focused);
    return true;
}
static bool rect_valid(double x, double y, double w, double h) {
    return isfinite(x) && isfinite(y) && isfinite(w) && isfinite(h) &&
        w >= 0 && h >= 0 && isfinite(x + w) && isfinite(y + h);
}
bool chui_ak_unix_bounds(uint64_t handle, double ox, double oy, double ow, double oh,
                        double ix, double iy, double iw, double ih) {
    if (!rect_valid(ox, oy, ow, oh) || !rect_valid(ix, iy, iw, ih)) return false;
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    pthread_mutex_unlock(&registry_mutex);
    if (!s) return false;
    accesskit_unix_adapter_set_root_window_bounds(s->native,
        (accesskit_rect){ox, oy, ox + ow, oy + oh}, (accesskit_rect){ix, iy, ix + iw, iy + ih});
    return true;
}
bool chui_ak_unix_poll(uint64_t handle, uint64_t *target, uint64_t *revision, uint32_t *action) {
    if (!target || !revision || !action) return false;
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    bool available = s && s->count;
    if (available) {
        struct ingress value = s->queue[s->head];
        s->head = (s->head + 1) % CHUI_AK_INGRESS; --s->count;
        *target = value.target; *revision = value.revision; *action = value.action;
    }
    pthread_mutex_unlock(&registry_mutex);
    return available;
}
uint64_t chui_ak_unix_dropped(uint64_t handle) {
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = find_session(handle);
    uint64_t result = s ? s->dropped : 0;
    pthread_mutex_unlock(&registry_mutex);
    return result;
}
void chui_ak_unix_close(uint64_t handle) {
    pthread_mutex_lock(&registry_mutex);
    struct unix_session *s = NULL;
    for (unsigned i = 0; i < CHUI_AK_WINDOWS; ++i) {
        if (registry[i] && registry[i]->token == handle) {
            s = registry[i]; registry[i] = NULL; break;
        }
    }
    pthread_mutex_unlock(&registry_mutex);
    if (!s) return;
    if (s->native) accesskit_unix_adapter_free(s->native);
    free(s); /* late callbacks have only a revoked token, never this address */
}
