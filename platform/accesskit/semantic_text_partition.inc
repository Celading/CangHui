/* Same transaction, text bytes, spans and generated-ID owner. Only the native
 * run boundaries change; no second document or inferred newline is introduced. */
bool chui_ak_tree_partition(struct chui_ak_tree *tree, uint64_t id,
    size_t count, const size_t *span_counts) {
    if (!tree || tree->failed) return false;
    struct entry *entry = lookup(tree, id);
    if (!entry || !entry->text_run || entry->partitioned || !count || !span_counts ||
        count > CHUI_AK_MAX_NODES || accesskit_node_text_selection(entry->node).has_value) {
        tree->failed = true; return false;
    }
    size_t old_count = entry->lines ? entry->line_count : 1, total = 0;
    if (count > CHUI_AK_MAX_NODES - (tree->run_count - old_count)) {
        tree->failed = true; return false;
    }
    for (size_t i = 0; i < old_count; ++i) {
        struct accesskit_node *run = entry->lines ? entry->lines[i].node : entry->text_run;
        if (accesskit_node_bounds(run).has_value) { tree->failed = true; return false; }
        total += accesskit_node_character_lengths(run).length;
    }
    uint8_t *lengths = malloc(total ? total : 1);
    struct text_line *runs = calloc(count, sizeof(*runs));
    char *value = accesskit_node_value(entry->node);
    bool valid = lengths && runs && value;
    size_t copied = 0;
    for (size_t i = 0; valid && i < old_count; ++i) {
        struct accesskit_node *run = entry->lines ? entry->lines[i].node : entry->text_run;
        accesskit_lengths part = accesskit_node_character_lengths(run);
        if (part.length) memcpy(lengths + copied, part.values, part.length);
        copied += part.length;
    }
    size_t bytes = value ? strlen(value) : 0, first = 0, offset = 0;
    bool previous_break = true;
    for (size_t i = 0; valid && i < count; ++i) {
        size_t spans = span_counts[i], begin = offset;
        if (spans > total - first || (!spans &&
            (i + 1 != count || first != total || (bytes && value[bytes - 1] != '\n')))) {
            valid = false; break;
        }
        for (size_t j = 0; j < spans; ++j) {
            offset += lengths[first + j];
            if (value[offset - 1] == '\n' && j + 1 != spans) { valid = false; break; }
        }
        if (!valid) break;
        struct accesskit_node *run = accesskit_node_new(ACCESSKIT_ROLE_TEXT_RUN);
        if (!run) { valid = false; break; }
        runs[i] = (struct text_line){multiline_run_id(id, i), run};
        char saved = value[offset]; value[offset] = 0;
        accesskit_node_set_value(run, value + begin); value[offset] = saved;
        const uint8_t empty = 0;
        accesskit_node_set_character_lengths(run, spans, spans ? lengths + first : &empty);
        if (i && !previous_break) {
            accesskit_node_set_previous_on_line(run, runs[i - 1].id);
            accesskit_node_set_next_on_line(runs[i - 1].node, runs[i].id);
        }
        previous_break = offset > begin && value[offset - 1] == '\n';
        first += spans;
    }
    valid = valid && first == total && offset == bytes &&
        ((!bytes || value[bytes - 1] == '\n') == (span_counts[count - 1] == 0));
    if (valid) {
        for (size_t i = 0; i < old_count; ++i)
            accesskit_node_free(entry->lines ? entry->lines[i].node : entry->text_run);
        free(entry->lines);
        entry->lines = runs; entry->line_count = count; entry->text_run = runs[0].node;
        entry->partitioned = true;
        tree->run_count = (unsigned)(tree->run_count - old_count + count);
    } else {
        if (runs) {
            for (size_t i = 0; i < count; ++i) if (runs[i].node) accesskit_node_free(runs[i].node);
            free(runs);
        }
        tree->failed = true;
    }
    free(lengths);
    if (value) accesskit_string_free(value);
    return valid;
}
