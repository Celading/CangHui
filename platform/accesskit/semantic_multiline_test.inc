static void multiline_runs_and_selection(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("");
    const uint8_t spans[] = {1, 3, 2, 3, 1, 1};
    assert(chui_ak_tree_add(t, 2, 1, "textarea", "Source", "a你\r\né\n\n", "", 0, 0, 200, 120, 0, CHUI_AK_FOCUS));
    assert(chui_ak_tree_multiline(t, 2, 6, spans));
    struct entry *entry = lookup(t, 2);
    assert(entry->line_count == 4 && t->run_count == 4);
    const char *values[] = {"a你\r\n", "é\n", "\n", ""};
    const size_t counts[] = {3, 2, 1, 0};
    for (size_t i = 0; i < 4; ++i) {
        char *value = accesskit_node_value(entry->lines[i].node);
        assert(!strcmp(value, values[i])); accesskit_string_free(value);
        assert(accesskit_node_character_lengths(entry->lines[i].node).length == counts[i]);
        assert(!accesskit_node_bounds(entry->lines[i].node).has_value);
        assert(!accesskit_node_supports_action(entry->lines[i].node, ACCESSKIT_ACTION_SET_TEXT_SELECTION));
    }
    for (size_t i = 0; i <= 6; ++i) {
        assert(chui_ak_tree_selection(t, 2, 6, i));
        accesskit_text_selection selection = accesskit_node_text_selection(entry->node).value;
        assert(selection.anchor.node == entry->lines[3].id && selection.anchor.character_index == 0);
        size_t line = i < 3 ? 0 : i < 5 ? 1 : i < 6 ? 2 : 3;
        size_t start = line == 0 ? 0 : line == 1 ? 3 : line == 2 ? 5 : 6;
        assert(selection.focus.node == entry->lines[line].id && selection.focus.character_index == i - start);
    }
    struct accesskit_tree_update *update = chui_ak_tree_finish(t);
    assert(update); accesskit_tree_update_free(update);
    for (unsigned empty = 0; empty < 2; ++empty) {
        t = chui_ak_tree_new("");
        assert(chui_ak_tree_add(t, 2, 1, "textarea", "", empty ? "" : "x", "", 0, 0, 1, 1, 0, 0));
        const uint8_t one = 1;
        assert(chui_ak_tree_multiline(t, 2, empty ? 0 : 1, empty ? NULL : &one));
        assert(chui_ak_tree_selection(t, 2, 0, empty ? 0 : 1));
        update = chui_ak_tree_finish(t); assert(update); accesskit_tree_update_free(update);
    }
}

static void multiline_rejection_and_limits(void) {
    const char *values[] = {"a\nb", "\r\n", "a\rb", "你", "\n", "a\nb", "a\nb", "a\nb", "a\nb"};
    const uint8_t good[] = {1, 1, 1}, combined[] = {3}, split[] = {1, 2};
    for (unsigned mode = 0; mode < 9; ++mode) {
        struct chui_ak_tree *t = chui_ak_tree_new("");
        assert(chui_ak_tree_add(t, 2, 1, mode == 4 ? "password" : "textarea", "", values[mode], "", 0, 0, 1, 1, 0, 0));
        bool ok = chui_ak_tree_multiline(t, 2, mode == 0 ? 1 : mode == 1 || mode == 3 ? 2 : 3,
            mode == 0 ? combined : mode == 3 ? split : good);
        if (mode < 5) assert(!ok);
        else {
            assert(ok);
            if (mode == 5) assert(add(t, multiline_run_id(2, 1), 1, "group", 0, 0));
            if (mode == 6) assert(add(t, 3, 2, "label", 0, 0));
            if (mode == 7) assert(!chui_ak_tree_multiline(t, 2, 3, good));
            if (mode == 8) assert(!chui_ak_tree_selection(t, 2, 0, SIZE_MAX));
        }
        assert(!chui_ak_tree_finish(t));
    }
    for (size_t breaks = CHUI_AK_MAX_NODES - 1; breaks <= CHUI_AK_MAX_NODES; ++breaks) {
        struct chui_ak_tree *t = chui_ak_tree_new("");
        char *value = calloc(breaks + 1, 1); uint8_t *spans = malloc(breaks);
        assert(value && spans); memset(value, '\n', breaks); memset(spans, 1, breaks);
        assert(chui_ak_tree_add(t, 2, 1, "textarea", "", value, "", 0, 0, 1, 1, 0, 0));
        bool ok = chui_ak_tree_multiline(t, 2, breaks, spans);
        assert(ok == (breaks < CHUI_AK_MAX_NODES));
        struct accesskit_tree_update *update = chui_ak_tree_finish(t);
        assert((update != NULL) == ok);
        if (update) accesskit_tree_update_free(update);
        free(value); free(spans);
    }
}

static void multiline_generated_collision_and_shared_budget(void) {
    struct chui_ak_tree *t = chui_ak_tree_new("");
    const uint8_t spans[] = {1, 1, 1};
    assert(chui_ak_tree_add(t, 2, 1, "textarea", "", "a\nb", "", 0, 0, 1, 1, 0, 0));
    assert(chui_ak_tree_multiline(t, 2, 3, spans));
    uint64_t colliding_parent = text_run_id(multiline_run_id(2, 1));
    const uint8_t five[] = {1, 1, 1, 1, 1};
    assert(add(t, colliding_parent, 1, "textfield", 0, 0));
    assert(chui_ak_tree_text(t, colliding_parent, 5, five));
    assert(!chui_ak_tree_finish(t)); /* generated vs generated, not semantic */

    t = chui_ak_tree_new("");
    for (uint64_t i = 2; i <= CHUI_AK_MAX_NODES; ++i) {
        assert(add(t, i, 1, "textfield", 0, 0));
        assert(chui_ak_tree_text(t, i, 5, five));
    }
    assert(chui_ak_tree_add(t, CHUI_AK_MAX_NODES + 1, 1, "textarea", "", "a\nb", "", 0, 0, 1, 1, 0, 0));
    assert(!chui_ak_tree_multiline(t, CHUI_AK_MAX_NODES + 1, 3, spans));
    assert(!chui_ak_tree_finish(t));
}
