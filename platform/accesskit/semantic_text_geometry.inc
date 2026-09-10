/* Same tree transaction and text-run owner as semantic_bridge.c. No synthetic
 * width fallback: geometry is optional until supplied by a real layout owner. */
bool chui_ak_tree_run_geometry(struct chui_ak_tree *tree, uint64_t id,
    size_t run, double x, double y, double width, double height,
    uint32_t direction, size_t count, const float *positions, const float *widths) {
    if (!tree || tree->failed) return false;
    struct entry *entry = lookup(tree, id);
    struct accesskit_node *node = NULL;
    if (entry && entry->text_run) {
        if (entry->lines && run < entry->line_count) node = entry->lines[run].node;
        else if (!entry->lines && run == 0) node = entry->text_run;
    }
    if (!node || direction > 3 || count > CHUI_AK_MAX_TEXT ||
        accesskit_node_character_lengths(node).length != count ||
        accesskit_node_bounds(node).has_value || (count && (!positions || !widths)) ||
        !isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height) ||
        width < 0 || height < 0 || !isfinite(x + width) || !isfinite(y + height)) {
        tree->failed = true; return false;
    }
    const double extent = direction < 2 ? width : height;
    for (size_t i = 0; i < count; ++i) {
        /* Cast before adding to avoid an intermediate float overflow. Overlap
         * is permitted for real shaping; the ordered origin must remain valid. */
        if (!isfinite(positions[i]) || !isfinite(widths[i]) ||
            positions[i] < 0 || widths[i] < 0 ||
            (i && positions[i] < positions[i - 1]) ||
            (double)positions[i] + (double)widths[i] > extent) {
            tree->failed = true; return false;
        }
    }
    static const accesskit_text_direction directions[] = {
        ACCESSKIT_TEXT_DIRECTION_LEFT_TO_RIGHT, ACCESSKIT_TEXT_DIRECTION_RIGHT_TO_LEFT,
        ACCESSKIT_TEXT_DIRECTION_TOP_TO_BOTTOM, ACCESSKIT_TEXT_DIRECTION_BOTTOM_TO_TOP
    };
    const float empty = 0;
    accesskit_node_set_bounds(node, (accesskit_rect){x, y, x + width, y + height});
    accesskit_node_set_text_direction(node, directions[direction]);
    accesskit_node_set_character_positions(node, count, count ? positions : &empty);
    accesskit_node_set_character_widths(node, count, count ? widths : &empty);
    return true;
}
