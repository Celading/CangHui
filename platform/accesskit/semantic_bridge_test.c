/* White-box ownership tests: no test-only ABI is exported by the bridge. */
#include "semantic_bridge.c"
#include <assert.h>
#include <stdio.h>

static bool add(struct chui_ak_tree *t, uint64_t id, uint64_t parent, const char *role,
                uint32_t states, uint32_t actions) {
    return chui_ak_tree_add(t, id, parent, role, "控件", "value", "hint", 1, 2, 30, 40, states, actions);
}

static void tree_order_and_ownership(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("Window");
    assert(t);
    /* Parent may arrive after child. IDs include full UInt64 values. */
    assert(add(t, UINT64_MAX, 7, "button", 0, CHUI_AK_ACTIVATE));
    assert(add(t, 3, 7, "label", 0, 0));
    assert(add(t, 7, 1, "group", 0, 0));
    struct accesskit_tree_update *u = chui_ak_tree_finish(t);
    assert(u);
    char *dump = accesskit_tree_update_debug(u);
    assert(dump && strstr(dump, "18446744073709551615") && strstr(dump, "Group"));
    accesskit_string_free(dump);
    accesskit_tree_update_free(u);
}

static void roles_states_and_actions(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("Window");
    assert(add(t, 2, 1, "checkbox", CHUI_AK_SELECTED_KNOWN | CHUI_AK_SELECTED,
               CHUI_AK_FOCUS | CHUI_AK_ACTIVATE));
    struct accesskit_node *n = lookup(t, 2)->node;
    assert(accesskit_node_role(n) == ACCESSKIT_ROLE_CHECK_BOX);
    assert(accesskit_node_toggled(n).has_value && accesskit_node_toggled(n).value == ACCESSKIT_TOGGLED_TRUE);
    assert(accesskit_node_supports_action(n, ACCESSKIT_ACTION_CLICK));
    assert(add(t, 3, 1, "combobox", CHUI_AK_EXPANDED_KNOWN, CHUI_AK_FOCUS));
    assert(accesskit_node_is_expanded(lookup(t, 3)->node).has_value);
    assert(!accesskit_node_is_expanded(lookup(t, 3)->node).value);
    assert(add(t, 4, 1, "custom-widget", 0, 0));
    assert(accesskit_node_role(lookup(t, 4)->node) == ACCESSKIT_ROLE_GROUP);
    assert(!accesskit_node_supports_action(lookup(t, 4)->node, ACCESSKIT_ACTION_CLICK));
    assert(add(t, 5, 1, "slider", 0, CHUI_AK_INCREMENT | CHUI_AK_DECREMENT));
    assert(accesskit_node_supports_action(lookup(t, 5)->node, ACCESSKIT_ACTION_INCREMENT));
    assert(accesskit_node_supports_action(lookup(t, 5)->node, ACCESSKIT_ACTION_DECREMENT));
    assert(add(t, 6, 1, "button", 0, CHUI_AK_DISMISS));
    assert(!accesskit_node_supports_action(lookup(t, 6)->node, ACCESSKIT_ACTION_COLLAPSE));
    assert(!accesskit_node_supports_action(lookup(t, 6)->node, ACCESSKIT_ACTION_HIDE_TOOLTIP));
    chui_ak_tree_free(t);
}

static void readonly_disabled_password(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("Window");
    assert(add(t, 2, 1, "textfield", CHUI_AK_READONLY | CHUI_AK_FOCUSED, 31));
    struct accesskit_node *n = lookup(t, 2)->node;
    assert(accesskit_node_is_read_only(n));
    assert(accesskit_node_supports_action(n, ACCESSKIT_ACTION_FOCUS));
    assert(!accesskit_node_supports_action(n, ACCESSKIT_ACTION_CLICK));
    assert(!accesskit_node_supports_action(n, ACCESSKIT_ACTION_INCREMENT));
    assert(add(t, 3, 1, "button", CHUI_AK_DISABLED, 31));
    assert(accesskit_node_is_disabled(lookup(t, 3)->node));
    assert(!accesskit_node_supports_action(lookup(t, 3)->node, ACCESSKIT_ACTION_FOCUS));
    assert(add(t, 4, 1, "password", 0, CHUI_AK_FOCUS));
    char *value = accesskit_node_value(lookup(t, 4)->node);
    assert(value && !strcmp(value, ""));
    accesskit_string_free(value);
    struct accesskit_tree_update *u = chui_ak_tree_finish(t);
    assert(u); accesskit_tree_update_free(u);
}

static void malformed_tree_is_atomic(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("Window");
    assert(add(t, 2, 99, "button", 0, 0));
    assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("Window");
    assert(add(t, 2, 3, "group", 0, 0)); assert(add(t, 3, 2, "group", 0, 0));
    assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("Window");
    assert(add(t, 2, 1, "button", 0, 0));
    assert(!add(t, 2, 1, "button", 0, 0));
    assert(!add(t, 3, 1, "label", 0, 0)); /* failure sticky */
    assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("Window");
    assert(add(t, 2, 1, "button", CHUI_AK_FOCUSED, CHUI_AK_FOCUS));
    assert(!add(t, 3, 1, "button", CHUI_AK_FOCUSED, CHUI_AK_FOCUS));
    assert(!chui_ak_tree_finish(t));
}

static void invalid_input_rejected(void) {
    const char *bad[] = {"\xc0\xaf", "\xed\xa0\x80", "\xf4\x90\x80\x80", "\xe2"};
    for (unsigned i = 0; i < sizeof(bad) / sizeof(bad[0]); ++i) {
        assert(!chui_ak_tree_new(bad[i]));
    }
    struct chui_ak_tree *t = chui_ak_tree_new("Window");
    assert(!chui_ak_tree_add(t, 2, 1, "button", "", "", "", NAN, 0, 1, 1, 0, 0));
    assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("Window");
    assert(!add(t, 1, 1, "button", 0, 0)); assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("Window");
    assert(!add(t, 2, 1, "button", CHUI_AK_SELECTED, 0)); assert(!chui_ak_tree_finish(t));
    chui_ak_tree_free(NULL); assert(!chui_ak_tree_finish(NULL));
}

static void hard_limits(void) {
    struct chui_ak_tree *valid = chui_ak_tree_new("\xf0\x9f\x8c\xb2");
    assert(valid);
    for (uint64_t i = 2; i <= CHUI_AK_MAX_NODES + 1; ++i) assert(add(valid, i, 1, "label", 0, 0));
    struct accesskit_tree_update *u = chui_ak_tree_finish(valid);
    assert(u); accesskit_tree_update_free(u);
    struct chui_ak_tree *t = chui_ak_tree_new("");
    for (uint64_t i = 2; i <= CHUI_AK_MAX_NODES + 1; ++i) assert(add(t, i, 1, "label", 0, 0));
    assert(!add(t, CHUI_AK_MAX_NODES + 2, 1, "label", 0, 0));
    assert(!chui_ak_tree_finish(t));
    t = chui_ak_tree_new("");
    for (uint64_t i = 2; i <= CHUI_AK_MAX_DEPTH + 3; ++i) assert(add(t, i, i - 1, "group", 0, 0));
    assert(!chui_ak_tree_finish(t));
    char *huge = malloc(CHUI_AK_MAX_TEXT + 2);
    assert(huge); memset(huge, 'a', CHUI_AK_MAX_TEXT + 1); huge[CHUI_AK_MAX_TEXT + 1] = 0;
    assert(!chui_ak_tree_new(huge)); free(huge);
}

int main(void) {
    tree_order_and_ownership(); roles_states_and_actions(); readonly_disabled_password();
    malformed_tree_is_atomic(); invalid_input_rejected(); hard_limits();
    puts("CANGHUI_ACCESSKIT_TREE_TESTS_PASSED 6/6");
    return 0;
}
