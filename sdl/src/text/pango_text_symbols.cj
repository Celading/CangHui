package sdl.text

@When[os == "Linux"]
internal func pangoRequiredSymbols(): Array<(Int64, Array<String>)> {
    [
        (0, ["pango_font_map_create_context", "pango_font_map_load_font", "pango_font_description_new",
            "pango_font_description_set_family", "pango_font_description_set_absolute_size",
            "pango_font_description_set_weight", "pango_font_description_free", "pango_layout_new",
            "pango_layout_set_text", "pango_layout_set_font_description", "pango_context_set_round_glyph_positions",
            "pango_layout_get_size", "pango_layout_get_pixel_extents", "pango_layout_get_cursor_pos",
            "pango_layout_get_direction",
            "pango_layout_xy_to_index", "pango_layout_get_line_readonly", "pango_layout_line_get_x_ranges",
            "pango_layout_get_unknown_glyphs_count", "pango_layout_set_single_paragraph_mode",
            "pango_attr_list_new", "pango_attr_foreground_new", "pango_attr_foreground_alpha_new",
            "pango_attr_list_change", "pango_layout_set_attributes", "pango_attr_list_unref"]),
        (1, ["pango_cairo_font_map_new", "pango_cairo_context_set_font_options", "pango_cairo_show_layout"]),
        (2, ["pango_fc_font_map_set_config", "pango_fc_font_get_pattern"]),
        (3, ["FcConfigCreate", "FcConfigParseAndLoadFromMemory", "FcConfigAppFontAddFile",
            "FcConfigBuildFonts", "FcConfigDestroy", "FcPatternGetString"]),
        (4, ["cairo_font_options_create", "cairo_font_options_set_hint_metrics", "cairo_font_options_set_hint_style",
            "cairo_font_options_destroy", "cairo_image_surface_create", "cairo_surface_status", "cairo_create",
            "cairo_status", "cairo_set_source_rgba", "cairo_move_to", "cairo_surface_flush",
            "cairo_image_surface_get_data", "cairo_image_surface_get_stride", "cairo_destroy", "cairo_surface_destroy"]),
        (5, ["g_object_unref"]), (6, ["g_free"])
    ]
}
