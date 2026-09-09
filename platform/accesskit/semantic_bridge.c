#include "semantic_bridge.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define CHUI_AK_MAX_NODES 4096u
#define CHUI_AK_MAX_DEPTH 64u
#define CHUI_AK_MAX_TEXT (1024u * 1024u)
#define CHUI_AK_SLOTS 8192u

struct entry {
    uint64_t id, parent;
    struct accesskit_node *node;
    struct accesskit_node *text_run;
};
struct chui_ak_tree {
    struct entry nodes[CHUI_AK_MAX_NODES + 1];
    unsigned slots[CHUI_AK_SLOTS]; /* index + 1; zero means empty */
    unsigned count;
    size_t text_bytes;
    uint64_t focus;
    bool failed;
};

static unsigned slot(uint64_t id) {
    return (unsigned)((id ^ (id >> 32)) * UINT64_C(11400714819323198485)) & (CHUI_AK_SLOTS - 1);
}
static struct entry *lookup(struct chui_ak_tree *tree, uint64_t id) {
    unsigned at = slot(id);
    while (tree->slots[at]) {
        struct entry *entry = &tree->nodes[tree->slots[at] - 1];
        if (entry->id == id) return entry;
        at = (at + 1) & (CHUI_AK_SLOTS - 1);
    }
    return NULL;
}
static void index_entry(struct chui_ak_tree *tree, unsigned index) {
    unsigned at = slot(tree->nodes[index].id);
    while (tree->slots[at]) at = (at + 1) & (CHUI_AK_SLOTS - 1);
    tree->slots[at] = index + 1;
}

/* Validate UTF-8 before calling a Rust-backed C ABI. No lossy replacement of
 * invalid bytes; bounded scanning also prevents unbounded label/value copies. */
static bool accept_text(struct chui_ak_tree *tree, const char *text) {
    if (!text) return false;
    const unsigned char *s = (const unsigned char *)text;
    size_t count = 0;
    while (*s) {
        unsigned c = *s++, remaining = 0, low = 0x80, high = 0xbf;
        if (c < 0x80) { remaining = 0; }
        else if (c >= 0xc2 && c <= 0xdf) { remaining = 1; }
        else if (c >= 0xe0 && c <= 0xef) {
            remaining = 2;
            if (c == 0xe0) low = 0xa0;
            if (c == 0xed) high = 0x9f;
        } else if (c >= 0xf0 && c <= 0xf4) {
            remaining = 3;
            if (c == 0xf0) low = 0x90;
            if (c == 0xf4) high = 0x8f;
        } else return false;
        if (++count > CHUI_AK_MAX_TEXT - tree->text_bytes) return false;
        for (unsigned i = 0; i < remaining; ++i) {
            unsigned next = *s++;
            if (next < low || next > high) return false;
            low = 0x80; high = 0xbf;
            if (++count > CHUI_AK_MAX_TEXT - tree->text_bytes) return false;
        }
    }
    tree->text_bytes += count;
    return true;
}

static accesskit_role map_role(const char *role) {
    static const struct { const char *name; accesskit_role value; } roles[] = {
        {"button", ACCESSKIT_ROLE_BUTTON}, {"checkbox", ACCESSKIT_ROLE_CHECK_BOX},
        {"radio", ACCESSKIT_ROLE_RADIO_BUTTON}, {"switch", ACCESSKIT_ROLE_SWITCH},
        {"textfield", ACCESSKIT_ROLE_TEXT_INPUT}, {"textarea", ACCESSKIT_ROLE_MULTILINE_TEXT_INPUT},
        {"password", ACCESSKIT_ROLE_PASSWORD_INPUT}, {"slider", ACCESSKIT_ROLE_SLIDER},
        {"spinbutton", ACCESSKIT_ROLE_SPIN_BUTTON}, {"combobox", ACCESSKIT_ROLE_COMBO_BOX},
        {"group", ACCESSKIT_ROLE_GROUP}, {"label", ACCESSKIT_ROLE_LABEL},
        {"image", ACCESSKIT_ROLE_IMAGE}, {"link", ACCESSKIT_ROLE_LINK},
        {"list", ACCESSKIT_ROLE_LIST}, {"listitem", ACCESSKIT_ROLE_LIST_ITEM},
        {"table", ACCESSKIT_ROLE_TABLE}, {"row", ACCESSKIT_ROLE_ROW},
        {"cell", ACCESSKIT_ROLE_CELL}, {"tree", ACCESSKIT_ROLE_TREE},
        {"treeitem", ACCESSKIT_ROLE_TREE_ITEM}, {"tab", ACCESSKIT_ROLE_TAB},
        {"tablist", ACCESSKIT_ROLE_TAB_LIST}, {"tabpanel", ACCESSKIT_ROLE_TAB_PANEL},
        {"date", ACCESSKIT_ROLE_DATE_INPUT}, {"time", ACCESSKIT_ROLE_TIME_INPUT},
        {"progressbar", ACCESSKIT_ROLE_PROGRESS_INDICATOR}, {"heading", ACCESSKIT_ROLE_HEADING},
        {"breadcrumb", ACCESSKIT_ROLE_NAVIGATION}, {"pagination", ACCESSKIT_ROLE_NAVIGATION}
    };
    for (size_t i = 0; i < sizeof(roles) / sizeof(roles[0]); ++i)
        if (!strcmp(role, roles[i].name)) return roles[i].value;
    /* Unknown custom roles remain a visible group, never an invented button. */
    return ACCESSKIT_ROLE_GROUP;
}

struct chui_ak_tree *chui_ak_tree_new(const char *window_label) {
    struct chui_ak_tree *tree = calloc(1, sizeof(*tree));
    if (!tree) return NULL;
    if (!accept_text(tree, window_label)) { free(tree); return NULL; }
    struct accesskit_node *root = accesskit_node_new(ACCESSKIT_ROLE_WINDOW);
    if (!root) { free(tree); return NULL; }
    accesskit_node_set_label(root, window_label);
    tree->nodes[0] = (struct entry){1, 0, root, NULL};
    tree->count = 1;
    tree->focus = 1;
    index_entry(tree, 0);
    return tree;
}

bool chui_ak_tree_add(struct chui_ak_tree *tree,
    uint64_t id, uint64_t parent_id, const char *role, const char *label,
    const char *value, const char *placeholder,
    double x, double y, double width, double height,
    uint32_t states, uint32_t actions) {
    if (!tree || tree->failed) return false;
    if (tree->count > CHUI_AK_MAX_NODES || id <= 1 || parent_id == 0 || id == parent_id ||
        lookup(tree, id) || !isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height) ||
        width < 0 || height < 0 || !isfinite(x + width) || !isfinite(y + height) ||
        (states & ~127u) || (actions & ~31u) ||
        ((states & CHUI_AK_SELECTED) && !(states & CHUI_AK_SELECTED_KNOWN)) ||
        ((states & CHUI_AK_EXPANDED) && !(states & CHUI_AK_EXPANDED_KNOWN)) ||
        !accept_text(tree, role) || !accept_text(tree, label) ||
        !accept_text(tree, value) || !accept_text(tree, placeholder)) {
        tree->failed = true; return false;
    }
    if ((states & CHUI_AK_FOCUSED) && tree->focus != 1) { tree->failed = true; return false; }
    accesskit_role native_role = map_role(role);
    struct accesskit_node *node = accesskit_node_new(native_role);
    if (!node) { tree->failed = true; return false; }
    accesskit_node_set_label(node, label);
    accesskit_node_set_value(node, !strcmp(role, "password") ? "" : value);
    accesskit_node_set_placeholder(node, placeholder);
    accesskit_node_set_bounds(node, (accesskit_rect){x, y, x + width, y + height});
    if (states & CHUI_AK_DISABLED) accesskit_node_set_disabled(node);
    if (states & CHUI_AK_READONLY) accesskit_node_set_read_only(node);
    if (states & CHUI_AK_SELECTED_KNOWN) {
        bool selected = (states & CHUI_AK_SELECTED) != 0;
        if (native_role == ACCESSKIT_ROLE_CHECK_BOX || native_role == ACCESSKIT_ROLE_RADIO_BUTTON ||
            native_role == ACCESSKIT_ROLE_SWITCH)
            accesskit_node_set_toggled(node, selected ? ACCESSKIT_TOGGLED_TRUE : ACCESSKIT_TOGGLED_FALSE);
        else accesskit_node_set_selected(node, selected);
    }
    if (states & CHUI_AK_EXPANDED_KNOWN)
        accesskit_node_set_expanded(node, (states & CHUI_AK_EXPANDED) != 0);
    if (!(states & CHUI_AK_DISABLED)) {
        if (actions & CHUI_AK_FOCUS) accesskit_node_add_action(node, ACCESSKIT_ACTION_FOCUS);
        if (!(states & CHUI_AK_READONLY)) {
            if (actions & CHUI_AK_ACTIVATE) accesskit_node_add_action(node, ACCESSKIT_ACTION_CLICK);
            if (actions & CHUI_AK_INCREMENT) accesskit_node_add_action(node, ACCESSKIT_ACTION_INCREMENT);
            if (actions & CHUI_AK_DECREMENT) accesskit_node_add_action(node, ACCESSKIT_ACTION_DECREMENT);
            /* AccessKit 0.23 has no generic Dismiss. Do not mislabel it as
             * Collapse or HideTooltip; host-specific dismissal remains separate. */
        }
    }
    if (states & CHUI_AK_FOCUSED) tree->focus = id;
    unsigned index = tree->count++;
    tree->nodes[index] = (struct entry){id, parent_id, node, NULL};
    index_entry(tree, index);
    return true;
}

static uint64_t text_run_id(uint64_t parent) { return parent ^ (UINT64_C(1) << 63); }

bool chui_ak_tree_text(struct chui_ak_tree *tree, uint64_t id,
    size_t count, const uint8_t *lengths) {
    if (!tree || tree->failed) return false;
    struct entry *entry = lookup(tree, id);
    if (!entry || entry->text_run || accesskit_node_role(entry->node) != ACCESSKIT_ROLE_TEXT_INPUT ||
        text_run_id(id) <= 1 || count > CHUI_AK_MAX_TEXT || (count && !lengths)) {
        tree->failed = true; return false;
    }
    char *value = accesskit_node_value(entry->node);
    if (!value) { tree->failed = true; return false; }
    size_t bytes = strlen(value), offset = 0;
    bool valid = !strchr(value, '\n') && !strchr(value, '\r');
    for (size_t i = 0; valid && i < count; ++i) {
        size_t length = lengths[i];
        if (!length || length > bytes - offset) { valid = false; break; }
        offset += length;
        if (offset < bytes && ((unsigned char)value[offset] & 0xc0) == 0x80) valid = false;
    }
    if (offset != bytes) valid = false;
    if (valid) {
        entry->text_run = accesskit_node_new(ACCESSKIT_ROLE_TEXT_RUN);
        valid = entry->text_run != NULL;
        if (valid) {
            accesskit_node_set_value(entry->text_run, value);
            /* The upstream setter copies; NULL is not a Rust slice pointer even
             * for length0, so supply a readable nonnull sentinel for empty text. */
            const uint8_t empty = 0;
            accesskit_node_set_character_lengths(entry->text_run, count, count ? lengths : &empty);
        }
    }
    accesskit_string_free(value);
    if (!valid) tree->failed = true;
    return valid;
}

void chui_ak_tree_free(struct chui_ak_tree *tree) {
    if (!tree) return;
    for (unsigned i = 0; i < tree->count; ++i) {
        if (tree->nodes[i].node) accesskit_node_free(tree->nodes[i].node);
        if (tree->nodes[i].text_run) accesskit_node_free(tree->nodes[i].text_run);
    }
    free(tree);
}

struct accesskit_tree_update *chui_ak_tree_finish(struct chui_ak_tree *tree) {
    if (!tree) return NULL;
    if (tree->failed) { chui_ak_tree_free(tree); return NULL; }
    /* Validate all parents/cycles/depth BEFORE transferring any node ownership. */
    for (unsigned i = 1; i < tree->count; ++i) {
        if (tree->nodes[i].text_run && lookup(tree, text_run_id(tree->nodes[i].id))) {
            chui_ak_tree_free(tree); return NULL;
        }
        struct entry *direct_parent = lookup(tree, tree->nodes[i].parent);
        if (direct_parent && direct_parent->text_run) { chui_ak_tree_free(tree); return NULL; }
        uint64_t parent = tree->nodes[i].parent;
        unsigned depth = 0;
        while (parent != 1) {
            struct entry *ancestor = lookup(tree, parent);
            if (!ancestor || parent == tree->nodes[i].id || ++depth > CHUI_AK_MAX_DEPTH) {
                chui_ak_tree_free(tree); return NULL;
            }
            parent = ancestor->parent;
        }
    }
    /* At most one generated leaf per semantic node; semantic count/depth/text
     * budgets are unchanged. Generated leaves never participate in actions. */
    struct accesskit_tree_update *update = accesskit_tree_update_with_capacity_and_focus(tree->count * 2, tree->focus);
    if (!update) { chui_ak_tree_free(tree); return NULL; }
    struct accesskit_tree_info *info = accesskit_tree_info_new(1);
    if (!info) { accesskit_tree_update_free(update); chui_ak_tree_free(tree); return NULL; }
    accesskit_tree_info_set_toolkit_name(info, "CangHui");
    accesskit_tree_update_set_tree_info(update, info);
    for (unsigned i = 1; i < tree->count; ++i)
        accesskit_node_push_child(lookup(tree, tree->nodes[i].parent)->node, tree->nodes[i].id);
    for (unsigned i = 0; i < tree->count; ++i) {
        if (tree->nodes[i].text_run) {
            uint64_t run = text_run_id(tree->nodes[i].id);
            accesskit_node_push_child(tree->nodes[i].node, run);
            accesskit_tree_update_push_node(update, run, tree->nodes[i].text_run);
            tree->nodes[i].text_run = NULL;
        }
        accesskit_tree_update_push_node(update, tree->nodes[i].id, tree->nodes[i].node);
        tree->nodes[i].node = NULL;
    }
    chui_ak_tree_free(tree);
    return update;
}
