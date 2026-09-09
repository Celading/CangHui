/* Private implementation included by semantic_bridge.c: same transaction and
 * ownership, not a second exported tree. Current TextArea layout is NoWrap. */
static uint64_t multiline_run_id(uint64_t parent, size_t line) {
    if (!line) return text_run_id(parent); /* keep the first-run convention */
    uint64_t x = parent + UINT64_C(0x9e3779b97f4a7c15) * line;
    x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
    return x ^ (x >> 31);
}

bool chui_ak_tree_multiline(struct chui_ak_tree *tree, uint64_t id,
    size_t count, const uint8_t *lengths) {
    if (!tree || tree->failed) return false;
    struct entry *entry = lookup(tree, id);
    if (!entry || entry->text_run || entry->lines ||
        accesskit_node_role(entry->node) != ACCESSKIT_ROLE_MULTILINE_TEXT_INPUT ||
        count > CHUI_AK_MAX_TEXT || (count && !lengths)) {
        tree->failed = true; return false;
    }
    char *value = accesskit_node_value(entry->node);
    if (!value) { tree->failed = true; return false; }
    size_t bytes = strlen(value), offset = 0, lines = 1;
    bool valid = true;
    /* A hard break is one whole selectable span, never embedded in another
     * span. Bare CR is not the editor's line separator. Validate before copying. */
    for (size_t i = 0; valid && i < count; ++i) {
        size_t length = lengths[i];
        if (!length || length > bytes - offset) { valid = false; break; }
        bool lf = length == 1 && value[offset] == '\n';
        bool crlf = length == 2 && value[offset] == '\r' && value[offset + 1] == '\n';
        if (lf || crlf) ++lines;
        else if (memchr(value + offset, '\n', length) || memchr(value + offset, '\r', length)) valid = false;
        offset += length;
        if (offset < bytes && ((unsigned char)value[offset] & 0xc0) == 0x80) valid = false;
    }
    valid = valid && offset == bytes && lines <= CHUI_AK_MAX_NODES - tree->run_count;
    if (valid) {
        entry->lines = calloc(lines, sizeof(*entry->lines));
        valid = entry->lines != NULL;
    }
    if (valid) {
        entry->line_count = lines;
        size_t first = 0, begin = 0, line = 0;
        offset = 0;
        for (size_t i = 0; valid && i <= count; ++i) {
            if (i < count) offset += lengths[i];
            if (i < count && value[offset - 1] != '\n') continue;
            struct accesskit_node *run = accesskit_node_new(ACCESSKIT_ROLE_TEXT_RUN);
            if (!run) { valid = false; break; }
            entry->lines[line] = (struct text_line){multiline_run_id(id, line), run};
            char saved = value[offset];
            value[offset] = 0;
            accesskit_node_set_value(run, value + begin);
            value[offset] = saved;
            size_t span_count = i < count ? i + 1 - first : i - first;
            const uint8_t empty = 0;
            accesskit_node_set_character_lengths(run, span_count, span_count ? lengths + first : &empty);
            ++line;
            begin = offset;
            first = i + 1;
        }
        if (valid) {
            entry->text_run = entry->lines[0].node;
            tree->run_count += (unsigned)lines;
        }
    }
    accesskit_string_free(value);
    if (!valid) tree->failed = true;
    return valid;
}

static bool multiline_position(struct entry *entry, size_t offset, accesskit_text_position *out) {
    for (size_t line = 0; line < entry->line_count; ++line) {
        size_t count = accesskit_node_character_lengths(entry->lines[line].node).length;
        /* At a run boundary use the next logical run (also within a bidi line).
         * After LF this includes the empty final run; before LF stays here. */
        if (offset < count || (line + 1 == entry->line_count && offset == count)) {
            *out = (accesskit_text_position){entry->lines[line].id, offset};
            return true;
        }
        offset -= count;
    }
    return false;
}

static bool multiline_selection(struct chui_ak_tree *tree, struct entry *entry, size_t anchor, size_t focus) {
    accesskit_text_selection selection;
    if (!multiline_position(entry, anchor, &selection.anchor) ||
        !multiline_position(entry, focus, &selection.focus)) {
        tree->failed = true; return false;
    }
    accesskit_node_set_text_selection(entry->node, selection);
    return true;
}
