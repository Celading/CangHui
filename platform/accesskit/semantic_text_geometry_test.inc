static struct chui_ak_tree *geometry_fixture(bool multiline) {
    struct chui_ak_tree *t = chui_ak_tree_new("geometry");
    assert(chui_ak_tree_add(t, 2, 1, multiline ? "textarea" : "textfield", "",
        multiline ? "a\n你" : "a你", "", 10, 20, 100, 60, CHUI_AK_READONLY, CHUI_AK_FOCUS));
    const uint8_t one[] = {1, 3}, multi[] = {1, 1, 3};
    assert(multiline ? chui_ak_tree_multiline(t, 2, 3, multi) : chui_ak_tree_text(t, 2, 2, one));
    return t;
}

static void geometry_is_copied_directional_and_optional(void) {
    for (uint32_t direction = 0; direction < 4; ++direction) {
        struct chui_ak_tree *t = geometry_fixture(false);
        struct accesskit_node *run = lookup(t, 2)->text_run;
        assert(!accesskit_node_bounds(run).has_value);
        float positions[] = {0, 5.25f}, widths[] = {5.25f, 10.5f};
        assert(chui_ak_tree_run_geometry(t, 2, 0, 17.5, 28.25, 16, 18,
            direction, 2, positions, widths));
        positions[0] = 999; widths[0] = 999;
        accesskit_opt_coords p = accesskit_node_character_positions(run);
        accesskit_opt_coords w = accesskit_node_character_widths(run);
        assert(p.has_value && w.has_value && p.length == 2 && w.length == 2);
        assert(p.values[0] == 0 && w.values[0] == 5.25f);
        accesskit_opt_rect bounds = accesskit_node_bounds(run);
        assert(bounds.has_value && bounds.value.x0 == 17.5 && bounds.value.y0 == 28.25);
        assert(bounds.value.x1 == 33.5 && bounds.value.y1 == 46.25);
        const accesskit_text_direction expected[] = {ACCESSKIT_TEXT_DIRECTION_LEFT_TO_RIGHT,
            ACCESSKIT_TEXT_DIRECTION_RIGHT_TO_LEFT, ACCESSKIT_TEXT_DIRECTION_TOP_TO_BOTTOM,
            ACCESSKIT_TEXT_DIRECTION_BOTTOM_TO_TOP};
        accesskit_opt_text_direction d = accesskit_node_text_direction(run);
        assert(d.has_value && d.value == expected[direction]);
        assert(!accesskit_node_supports_action(run, ACCESSKIT_ACTION_SET_TEXT_SELECTION));
        assert(chui_ak_tree_selection(t, 2, 2, 1));
        struct accesskit_tree_update *u = chui_ak_tree_finish(t); assert(u); accesskit_tree_update_free(u);
    }
    struct chui_ak_tree *t = geometry_fixture(false);
    struct accesskit_tree_update *u = chui_ak_tree_finish(t); assert(u); accesskit_tree_update_free(u);
}

static void geometry_multiline_and_empty_runs(void) {
    struct chui_ak_tree *t = geometry_fixture(true);
    const float positions[] = {0, 8}, widths[] = {8, 0};
    assert(chui_ak_tree_run_geometry(t, 2, 0, 10, 20, 8, 18, 0, 2, positions, widths));
    assert(chui_ak_tree_run_geometry(t, 2, 1, 10, 38, 16, 18, 0, 1, positions, widths));
    assert(chui_ak_tree_selection(t, 2, 1, 3));
    accesskit_opt_text_selection s = accesskit_node_text_selection(lookup(t, 2)->node);
    assert(s.has_value && s.value.focus.node == multiline_run_id(2, 1));
    assert(s.value.focus.character_index == 1);
    struct accesskit_tree_update *u = chui_ak_tree_finish(t); assert(u); accesskit_tree_update_free(u);
    t = chui_ak_tree_new("");
    assert(chui_ak_tree_add(t, 2, 1, "textarea", "", "\n", "", 0, 0, 10, 40, 0, 0));
    const uint8_t lf = 1;
    assert(chui_ak_tree_multiline(t, 2, 1, &lf));
    const float zero = 0;
    assert(chui_ak_tree_run_geometry(t, 2, 0, 0, 0, 0, 20, 0, 1, &zero, &zero));
    assert(chui_ak_tree_run_geometry(t, 2, 1, 0, 20, 0, 20, 0, 0, NULL, NULL));
    u = chui_ak_tree_finish(t); assert(u); accesskit_tree_update_free(u);
}

static void geometry_rejects_invalid_input_atomically(void) {
    assert(!chui_ak_tree_run_geometry(NULL, 2, 0, 0, 0, 10, 20, 0, 0, NULL, NULL));
    for (unsigned mode = 0; mode < 16; ++mode) {
        struct chui_ak_tree *t = geometry_fixture(false);
        float p[] = {0, 5}, w[] = {5, 5};
        if (mode == 0) p[0] = NAN;
        if (mode == 1) w[0] = INFINITY;
        if (mode == 2) p[0] = -1;
        if (mode == 3) w[0] = -1;
        if (mode == 4) p[1] = -1;
        if (mode == 5) { p[0] = 6; w[0] = 1; } /* non-monotonic, each rect fits */
        if (mode == 6) w[1] = 6;
        if (mode == 7) assert(chui_ak_tree_run_geometry(t, 2, 0, 0, 0, 10, 20, 0, 2, p, w));
        assert(!chui_ak_tree_run_geometry(t, mode == 8 ? 999 : 2, mode == 9 ? 1 : 0,
            mode == 10 ? NAN : 0, 0, mode == 11 ? -1 : 10, mode == 12 ? INFINITY : 20,
            mode == 13 ? 4 : 0, mode == 14 ? 1 : 2, mode == 15 ? NULL : p, w));
        assert(!chui_ak_tree_finish(t));
    }
    struct chui_ak_tree *t = chui_ak_tree_new("");
    assert(chui_ak_tree_add(t, 2, 1, "password", "", "secret", "", 0, 0, 20, 20, 0, 0));
    assert(!chui_ak_tree_run_geometry(t, 2, 0, 0, 0, 20, 20, 0, 0, NULL, NULL));
    assert(!chui_ak_tree_finish(t));
}

static void geometry_rejects_missing_text_overflow_and_wrong_span_counts(void) {
    for (unsigned mode = 0; mode < 7; ++mode) {
        struct chui_ak_tree *t = geometry_fixture(false);
        const float p[] = {0, 5}, w[] = {5, 5};
        assert(!chui_ak_tree_run_geometry(t, 2, mode == 0 ? SIZE_MAX : 0,
            mode == 1 ? 1.7976931348623157e308 : 0, 0,
            mode == 1 ? 1.7976931348623157e308 : 10, 20,
            mode == 2 ? UINT32_MAX : 0,
            mode == 3 ? SIZE_MAX : mode == 4 ? 0 : 2,
            mode == 5 ? NULL : p, mode == 6 ? NULL : w));
        assert(!chui_ak_tree_finish(t));
    }
    struct chui_ak_tree *t = chui_ak_tree_new("");
    assert(chui_ak_tree_add(t, 2, 1, "textfield", "", "", "", 0, 0, 0, 0, 0, 0));
    assert(!chui_ak_tree_run_geometry(t, 2, 0, 0, 0, 0, 0, 0, 0, NULL, NULL));
    assert(!chui_ak_tree_text(t, 2, 0, NULL)); /* error remains sticky */
    assert(!chui_ak_tree_finish(t));
}
