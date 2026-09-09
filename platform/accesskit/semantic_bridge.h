#ifndef CHUI_ACCESSKIT_SEMANTIC_BRIDGE_H
#define CHUI_ACCESSKIT_SEMANTIC_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>
#include "accesskit.h"

#if defined(_WIN32)
#define CHUI_AK_API __declspec(dllexport)
#else
#define CHUI_AK_API __attribute__((visibility("default")))
#endif

/* Bridge-local bits, never the upstream AccessKit enum ABI. */
enum {
    CHUI_AK_DISABLED = 1u, CHUI_AK_READONLY = 2u,
    CHUI_AK_SELECTED_KNOWN = 4u, CHUI_AK_SELECTED = 8u,
    CHUI_AK_EXPANDED_KNOWN = 16u, CHUI_AK_EXPANDED = 32u,
    CHUI_AK_FOCUSED = 64u
};
enum {
    CHUI_AK_FOCUS = 1u, CHUI_AK_ACTIVATE = 2u, CHUI_AK_INCREMENT = 4u,
    CHUI_AK_DECREMENT = 8u, CHUI_AK_DISMISS = 16u
};

struct chui_ak_tree;

#ifdef __cplusplus
extern "C" {
#endif

/* Single-thread-owned transaction. Root ID 1 is reserved. All strings must be
 * valid UTF-8, NUL-terminated and readable for the duration of the call.
 * Strings are copied. Node IDs/parent IDs come from SemanticNativeSession;
 * add order is semantic sibling order, not native allocation order.
 */
CHUI_AK_API struct chui_ak_tree *chui_ak_tree_new(const char *window_label);
CHUI_AK_API bool chui_ak_tree_add(struct chui_ak_tree *tree,
    uint64_t id, uint64_t parent_id, const char *role, const char *label,
    const char *value, const char *placeholder,
    double x, double y, double width, double height,
    uint32_t states, uint32_t actions);

/* Optional single-line TextInput read projection. Lengths are editor-selectable
 * UTF-8 spans (not scalar counts), copied during the call. No glyph geometry,
 * selection/caret or editing action is inferred. Zero count permits empty text.
 * Run identity is id XOR 2^63; finish rejects collisions with any semantic ID
 * or semantic children of this leaf field, including those added later.
 * Passwords, other roles, invalid spans and multiline text fail atomically.
 * Additive ABI1 capability: new consumers must resolve this symbol up front.
 */
CHUI_AK_API bool chui_ak_tree_text(struct chui_ak_tree *tree, uint64_t id,
    size_t count, const uint8_t *lengths);

/* No-wrap MultilineTextInput read projection. LF/CRLF each occupies one span,
 * retained at the preceding run's end. A trailing break creates an empty run.
 * Up to 4096 generated runs across the transaction. Parent/line-derived IDs
 * are collision-checked against all semantic and generated IDs at finish.
 * Additive ABI1 capability; resolve before adapter creation. No glyph geometry,
 * soft wrap, editing action or IME-preedit projection is implied. */
CHUI_AK_API bool chui_ak_tree_multiline(struct chui_ak_tree *tree, uint64_t id,
    size_t count, const uint8_t *lengths);

/* Read-only selection facts for an existing text projection. Indices address
 * editor-selectable spans, not bytes/UTF16/scalars. End-of-run is permitted.
 * Does not enable a native editing action. Invalid range fails the transaction.
 */
CHUI_AK_API bool chui_ak_tree_selection(struct chui_ak_tree *tree, uint64_t id,
    size_t anchor, size_t focus);

/* Measured geometry for one existing generated text run (zero-based ordinal;
 * a single-line projection has run0). Coordinate space is the same as tree_add,
 * NOT relative to the semantic parent's origin. Positions are relative to the
 * run's bounding box along direction: 0=LTR,1=RTL,2=top-to-bottom,3=bottom-to-top.
 * These bridge-local codes are mapped to native enums, never cast to them.
 * Count must equal that run's character_lengths, including any hard break.
 * Positions are nonnegative/nondecreasing; advances are nonnegative and fit
 * the run's axis extent. Zero-width breaks/empty runs are allowed.
 * All arrays are copied. Invalid input poisons the transaction, not a partial
 * update. Call once per run after text/multiline, before finish.
 * Mixed bidi lines require actual directional runs; do not invent a direction
 * or infer geometry from parent width. This function does not segment text.
 * Additive ABI1 symbol: resolve before a consumer begins using it. */
CHUI_AK_API bool chui_ak_tree_run_geometry(struct chui_ak_tree *tree, uint64_t id,
    size_t run, double x, double y, double width, double height,
    uint32_t direction, size_t count, const float *positions, const float *widths);

/* Consumes the transaction on success OR failure. NULL means no update may be
 * submitted. The caller owns a successful update until transferred to AccessKit.
 * This is not an update-factory fallback: those callbacks may forbid NULL.
 */
CHUI_AK_API struct accesskit_tree_update *chui_ak_tree_finish(struct chui_ak_tree *tree);
CHUI_AK_API void chui_ak_tree_free(struct chui_ak_tree *tree);

#ifdef __cplusplus
}
#endif
#endif
