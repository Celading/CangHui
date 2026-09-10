static struct chui_ak_tree *partition_fixture(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("");
    assert(chui_ak_tree_add(t, 2, 1, "textarea", "", "aאב\r\nz\n", "",
        0, 0, 100, 100, CHUI_AK_READONLY, CHUI_AK_FOCUS));
    const uint8_t lengths[] = {1, 2, 2, 2, 1, 1};
    assert(chui_ak_tree_multiline(t, 2, 6, lengths));
    return t;
}

static void partition_preserves_text_lines_selection_and_geometry(void) {
    struct chui_ak_tree *t = partition_fixture();
    const size_t groups[] = {1, 2, 1, 2, 0};
    assert(chui_ak_tree_partition(t, 2, 5, groups));
    struct entry *e = lookup(t, 2);
    assert(e->line_count == 5 && t->run_count == 5);
    const char *values[] = {"a", "אב", "\r\n", "z\n", ""};
    for (size_t i = 0; i < 5; ++i) {
        char *value = accesskit_node_value(e->lines[i].node);
        assert(!strcmp(value, values[i])); accesskit_string_free(value);
        assert(accesskit_node_character_lengths(e->lines[i].node).length == groups[i]);
    }
    assert(!accesskit_node_previous_on_line(e->lines[0].node).has_value);
    assert(accesskit_node_next_on_line(e->lines[0].node).value == e->lines[1].id);
    assert(accesskit_node_previous_on_line(e->lines[1].node).value == e->lines[0].id);
    assert(accesskit_node_next_on_line(e->lines[1].node).value == e->lines[2].id);
    assert(!accesskit_node_next_on_line(e->lines[2].node).has_value);
    assert(!accesskit_node_previous_on_line(e->lines[3].node).has_value);
    const float positions[] = {0, 9}, widths[] = {9, 8};
    assert(chui_ak_tree_run_geometry(t, 2, 1, 20, 0, 17, 20, 1, 2, positions, widths));
    assert(chui_ak_tree_selection(t, 2, 1, 6));
    accesskit_text_selection s = accesskit_node_text_selection(e->node).value;
    assert(s.anchor.node == e->lines[1].id && s.anchor.character_index == 0);
    assert(s.focus.node == e->lines[4].id && s.focus.character_index == 0);
    struct accesskit_tree_update *u = chui_ak_tree_finish(t);
    assert(u); accesskit_tree_update_free(u);
    t = chui_ak_tree_new("");
    assert(chui_ak_tree_add(t, 2, 1, "textfield", "", "", "", 0, 0, 20, 20, 0, 0));
    assert(chui_ak_tree_text(t, 2, 0, NULL));
    const size_t empty[] = {0};
    assert(chui_ak_tree_partition(t, 2, 1, empty));
    assert(chui_ak_tree_run_geometry(t, 2, 0, 5, 5, 0, 20, 0, 0, NULL, NULL));
    u = chui_ak_tree_finish(t); assert(u); accesskit_tree_update_free(u);
}

static void partition_rejects_inconsistent_or_reordered_transactions(void) {
    const size_t good[] = {1, 2, 1, 2, 0};
    const size_t cross_line[] = {5, 1, 0}, missing[] = {4, 2}, oversized[] = {SIZE_MAX};
    const size_t early_empty[] = {0, 4, 2, 0};
    for (unsigned i = 0; i < 9; ++i) {
        struct chui_ak_tree *t = partition_fixture();
        if (i == 0) assert(!chui_ak_tree_partition(t, 2, 3, cross_line));
        if (i == 1) assert(!chui_ak_tree_partition(t, 2, 2, missing));
        if (i == 2) assert(!chui_ak_tree_partition(t, 2, 1, oversized));
        if (i == 3) assert(!chui_ak_tree_partition(t, 2, 4, early_empty));
        if (i == 4) assert(!chui_ak_tree_partition(t, 2, 5, NULL));
        if (i == 5) {
            assert(chui_ak_tree_partition(t, 2, 5, good));
            assert(!chui_ak_tree_partition(t, 2, 5, good));
        }
        if (i == 6) {
            assert(chui_ak_tree_selection(t, 2, 0, 1));
            assert(!chui_ak_tree_partition(t, 2, 5, good));
        }
        if (i == 7) {
            assert(chui_ak_tree_run_geometry(t, 2, 2, 0, 0, 0, 20, 0, 0, NULL, NULL));
            assert(!chui_ak_tree_partition(t, 2, 5, good));
        }
        if (i == 8) assert(!chui_ak_tree_partition(t, 2, CHUI_AK_MAX_NODES + 1, good));
        assert(!chui_ak_tree_finish(t));
    }
}
