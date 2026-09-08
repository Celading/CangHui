#include "unix_adapter.h"
#include <assert.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <stdio.h>

/* Deterministic upstream scheduling double. Real platform verification is a
 * separate CUIC/AT-SPI consumer; no claim that this double proves native behavior. */
struct accesskit_unix_adapter { bool active; };
static struct accesskit_unix_adapter *last_native;
static atomic_uint released_requests;
static unsigned updates;
static void (*during_update)(void);
static struct accesskit_unix_adapter *fake_new(accesskit_activation_handler_callback activation,
    void *au, accesskit_action_handler_callback action, void *ac,
    accesskit_deactivation_handler_callback deactivation, void *du) {
    (void)action; (void)ac; (void)deactivation; (void)du;
    assert(!activation(au));
    last_native = calloc(1, sizeof(*last_native)); assert(last_native);
    return last_native;
}
static void fake_free(struct accesskit_unix_adapter *a) { free(a); }
static void fake_update(struct accesskit_unix_adapter *a, accesskit_tree_update_factory f, void *data) {
    if (!a->active) return;
    if (during_update) during_update();
    struct accesskit_tree_update *update = f(data);
    assert(update); ++updates; accesskit_tree_update_free(update);
}
static void fake_focus(struct accesskit_unix_adapter *a, bool focused) { (void)a; (void)focused; }
static void fake_bounds(struct accesskit_unix_adapter *a, accesskit_rect outer, accesskit_rect inner) {
    (void)a; (void)outer; (void)inner;
}
static void fake_request_free(struct accesskit_action_request *r) {
    atomic_fetch_add(&released_requests, 1); free(r);
}
#define accesskit_unix_adapter_new fake_new
#define accesskit_unix_adapter_free fake_free
#define accesskit_unix_adapter_update_if_active fake_update
#define accesskit_unix_adapter_update_window_focus_state fake_focus
#define accesskit_unix_adapter_set_root_window_bounds fake_bounds
#define accesskit_action_request_free fake_request_free
#include "unix_adapter.c"

static struct accesskit_tree_update *tree(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("test"); assert(t);
    assert(chui_ak_tree_add(t, 2, 1, "button", "test", "", "", 0, 0, 20, 20, 0, CHUI_AK_ACTIVATE));
    return chui_ak_tree_finish(t);
}
static void send(uint64_t token, uint64_t node, accesskit_action action) {
    struct accesskit_action_request *r = calloc(1, sizeof(*r)); assert(r);
    r->target_node = node; r->action = action;
    receive_action(r, (void *)(uintptr_t)token);
}
static void publication_and_ingress(void) {
    uint64_t h = chui_ak_unix_new(); assert(h);
    assert(!chui_ak_unix_publish(h, 0, tree()));
    assert(!chui_ak_unix_publish(h, 1, NULL));
    assert(chui_ak_unix_publish(h, 1, tree())); assert(updates == 0);
    last_native->active = true;
    assert(chui_ak_unix_publish(h, 2, tree())); assert(updates == 1);
    assert(!chui_ak_unix_publish(h, 2, tree()));
    send(h, 2, ACCESSKIT_ACTION_CLICK);
    uint64_t target = 0, revision = 0; uint32_t action = 0;
    assert(chui_ak_unix_poll(h, &target, &revision, &action));
    assert(target == 2 && revision == 2 && action == CHUI_AK_ACTIVATE);
    assert(!chui_ak_unix_poll(h, &target, &revision, &action));
    assert(!chui_ak_unix_poll(h, NULL, &revision, &action));
    send(h, 2, ACCESSKIT_ACTION_SET_VALUE); send(h, 1, ACCESSKIT_ACTION_CLICK);
    assert(chui_ak_unix_dropped(h) == 2);
    struct accesskit_action_request *foreign = calloc(1, sizeof(*foreign)); assert(foreign);
    foreign->action = ACCESSKIT_ACTION_CLICK; foreign->target_node = 2; foreign->target_tree.bytes[0] = 1;
    receive_action(foreign, (void *)(uintptr_t)h);
    assert(chui_ak_unix_dropped(h) == 3);
    assert(!chui_ak_unix_poll(h, &target, &revision, &action));
    assert(chui_ak_unix_focus(h, true));
    assert(chui_ak_unix_bounds(h, 0, 0, 30, 30, 1, 1, 28, 28));
    assert(!chui_ak_unix_bounds(h, NAN, 0, 30, 30, 1, 1, 28, 28));
    chui_ak_unix_close(h); chui_ak_unix_close(h);
    assert(!chui_ak_unix_publish(h, 3, tree())); assert(!chui_ak_unix_focus(h, true));
}
static void limits_deactivation_and_revoke(void) {
    uint64_t h = chui_ak_unix_new(); assert(h);
    send(h, 2, ACCESSKIT_ACTION_CLICK); assert(chui_ak_unix_dropped(h) == 1);
    assert(chui_ak_unix_publish(h, 1, tree()));
    find_session(h)->updating = true;
    send(h, 2, ACCESSKIT_ACTION_CLICK);
    find_session(h)->updating = false;
    uint64_t target, revision; uint32_t action;
    assert(chui_ak_unix_poll(h, &target, &revision, &action));
    assert(target == 2 && revision == 1 && action == CHUI_AK_ACTIVATE);
    for (unsigned i = 0; i < CHUI_AK_INGRESS + 1; ++i) send(h, 2, ACCESSKIT_ACTION_FOCUS);
    assert(chui_ak_unix_dropped(h) == 2);
    deactivate((void *)(uintptr_t)h);
    assert(!chui_ak_unix_poll(h, &target, &revision, &action));
    send(h, 2, ACCESSKIT_ACTION_CLICK);
    chui_ak_unix_close(h);
    uint64_t replacement = chui_ak_unix_new(); assert(replacement > h);
    send(h, 2, ACCESSKIT_ACTION_CLICK); deactivate((void *)(uintptr_t)h);
    assert(!chui_ak_unix_poll(replacement, &target, &revision, &action));
    chui_ak_unix_close(replacement);
    uint64_t handles[CHUI_AK_WINDOWS];
    for (unsigned i = 0; i < CHUI_AK_WINDOWS; ++i) { handles[i] = chui_ak_unix_new(); assert(handles[i]); }
    assert(!chui_ak_unix_new());
    for (unsigned i = 0; i < CHUI_AK_WINDOWS; ++i) chui_ak_unix_close(handles[i]);
}
static void *late_callbacks(void *data) {
    uint64_t token = *(uint64_t *)data;
    for (unsigned i = 0; i < 20000; ++i) {
        send(token, 2, ACCESSKIT_ACTION_CLICK);
        if (!(i % 20)) deactivate((void *)(uintptr_t)token);
    }
    return NULL;
}
static void concurrent_close(void) {
    uint64_t h = chui_ak_unix_new(); assert(h);
    assert(chui_ak_unix_publish(h, 1, tree()));
    pthread_t worker; assert(!pthread_create(&worker, NULL, late_callbacks, &h));
    chui_ak_unix_close(h);
    assert(!pthread_join(worker, NULL));
    assert(!find_session(h));
    assert(atomic_load(&released_requests) >= 20000);
}
static uint64_t race_token;
static void replace_activation(void) {
    deactivate((void *)(uintptr_t)race_token);
    assert(!activate((void *)(uintptr_t)race_token));
}
static void idle_activation_replay(void) {
    assert(chui_ak_unix_abi_version() == 1);
    uint64_t h = chui_ak_unix_new(); assert(h);
    assert(!chui_ak_unix_needs_refresh(h));
    assert(!chui_ak_unix_refresh(h, 1, tree()));
    assert(chui_ak_unix_publish(h, 1, tree()));
    assert(chui_ak_unix_needs_refresh(h));
    /* Pending activation can race the native transition; an unused factory
     * must not lose the activation request. No semantic revision inflation. */
    assert(chui_ak_unix_refresh(h, 1, tree()));
    assert(chui_ak_unix_needs_refresh(h));
    last_native->active = true;
    assert(!chui_ak_unix_refresh(h, 2, tree()));
    assert(chui_ak_unix_refresh(h, 1, tree()));
    assert(!chui_ak_unix_needs_refresh(h));
    assert(!chui_ak_unix_refresh(h, 1, tree()));
    assert(!chui_ak_unix_publish(h, 1, tree()));
    assert(find_session(h)->revision == 1);
    assert(!activate((void *)(uintptr_t)h));
    race_token = h; during_update = replace_activation;
    assert(chui_ak_unix_refresh(h, 1, tree()));
    during_update = NULL;
    assert(chui_ak_unix_needs_refresh(h)); /* do not acknowledge a newer activation */
    assert(chui_ak_unix_refresh(h, 1, tree()));
    assert(!chui_ak_unix_needs_refresh(h));
    assert(!activate((void *)(uintptr_t)h));
    deactivate((void *)(uintptr_t)h);
    assert(!chui_ak_unix_needs_refresh(h));
    chui_ak_unix_close(h);
    assert(!activate((void *)(uintptr_t)h));
    assert(!chui_ak_unix_needs_refresh(h));
    assert(!chui_ak_unix_refresh(h, 1, tree()));
}
int main(void) {
    publication_and_ingress(); limits_deactivation_and_revoke(); concurrent_close();
    idle_activation_replay();
    puts("CANGHUI_ACCESSKIT_UNIX_TESTS_PASSED 4/4"); return 0;
}
