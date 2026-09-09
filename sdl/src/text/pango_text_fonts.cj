package sdl.text

import std.collection.{ArrayList, HashSet, HashMap}
import std.fs.canonicalize

@When[os == "Linux"]
private func pangoXmlText(text: String): String {
    text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        .replace("\r", "&#13;").replace("\n", "&#10;").replace("\t", "&#9;")
}

// Each file has a private scan-time family alias. Equal family names from two
// application files cannot silently swap their ordered place in the cascade.
@When[os == "Linux"]
internal class PangoTextFonts {
    private let api: PangoTextApi
    private var map = PangoRef()
    private var closed = false
    private let families: String
    private let sources = HashMap<String, String>()

    init(api: PangoTextApi, paths: Array<String>, defaultPath: String) {
        this.api = api
        let ordered = ArrayList<String>()
        let seen = HashSet<String>()
        for (path in paths) { if (seen.add(path)) { ordered.add(path) } }
        if (seen.add(defaultPath)) { ordered.add(defaultPath) }
        if (ordered.size > 64) { throw NativeTextException("Pango font chain exceeds64 files") }
        let config = PangoTextApi.require(unsafe {
            CFunc<() -> PangoRef>(api.symbol(3, "FcConfigCreate"))() }, "private font config")
        let names = StringBuilder()
        try {
            let xml = StringBuilder()
            xml.append("<fontconfig>")
            let files = ArrayList<(String, String)>()
            let canonicalPaths = HashSet<String>()
            for (i in 0..ordered.size) {
                let path = ordered[i]
                if (path.isEmpty() || path.contains("\u{0}")) { continue }
                var absolute = ""
                try { absolute = canonicalize(path).toString() } catch (_: Exception) { continue }
                if (!canonicalPaths.add(absolute)) { continue }
                files.add((absolute, path))
                xml.append("<match target=\"scan\"><test name=\"file\" compare=\"eq\"><string>${pangoXmlText(absolute)}</string></test><edit name=\"family\" mode=\"assign_replace\"><string>chui-file-${files.size - 1}</string></edit></match>")
            }
            xml.append("</fontconfig>")
            unsafe {
                try (c = LibC.mallocCString(xml.toString()).asResource()) {
                    if (CFunc<(PangoRef, CString, Int32) -> Int32>(api.symbol(3,
                        "FcConfigParseAndLoadFromMemory"))(config, c.value, 1) == 0) {
                        throw NativeTextException("Pango private font rules failed")
                    }
                }
                for (i in 0..files.size) {
                    let (absolute, original) = files[i]
                    try (c = LibC.mallocCString(absolute).asResource()) {
                        if (CFunc<(PangoRef, CString) -> Int32>(api.symbol(3,
                            "FcConfigAppFontAddFile"))(config, c.value) != 0) {
                            if (!sources.isEmpty()) { names.append(",") }
                            names.append("chui-file-${i}"); sources[absolute] = original
                        }
                    }
                }
                if (sources.isEmpty() || CFunc<(PangoRef) -> Int32>(api.symbol(3,
                    "FcConfigBuildFonts"))(config) == 0) { throw NativeTextException("Pango has no usable font files") }
                map = PangoTextApi.require(CFunc<() -> PangoRef>(api.symbol(1,
                    "pango_cairo_font_map_new"))(), "font map")
                CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(2, "pango_fc_font_map_set_config"))(map, config)
            }
            this.families = names.toString()
        } catch (e: Exception) { api.unref(map); throw e }
        finally { unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(3, "FcConfigDestroy"))(config) } }
    }

    func context(): PangoRef {
        if (closed) { throw NativeTextException("Pango font map is closed") }
        let context = PangoTextApi.require(unsafe { CFunc<(PangoRef) -> PangoRef>(api.symbol(0,
            "pango_font_map_create_context"))(map) }, "font context")
        let options = unsafe { CFunc<() -> PangoRef>(api.symbol(4, "cairo_font_options_create"))() }
        try {
            unsafe {
                CFunc<(PangoRef, Int32) -> Unit>(api.symbol(0, "pango_context_set_round_glyph_positions"))(context, 0)
                CFunc<(PangoRef, Int32) -> Unit>(api.symbol(4, "cairo_font_options_set_hint_metrics"))(options, 1)
                CFunc<(PangoRef, Int32) -> Unit>(api.symbol(4, "cairo_font_options_set_hint_style"))(options, 1)
                CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(1, "pango_cairo_context_set_font_options"))(context, options)
            }
            context
        } catch (e: Exception) { api.unref(context); throw e }
        finally { unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(4, "cairo_font_options_destroy"))(options) } }
    }

    func description(size: Float32, bold: Bool): PangoRef {
        let desc = PangoTextApi.require(unsafe { CFunc<() -> PangoRef>(api.symbol(0,
            "pango_font_description_new"))() }, "font description")
        try {
            unsafe {
                try (c = LibC.mallocCString(families).asResource()) {
                    CFunc<(PangoRef, CString) -> Unit>(api.symbol(0, "pango_font_description_set_family"))(desc, c.value)
                }
                CFunc<(PangoRef, Float64) -> Unit>(api.symbol(0, "pango_font_description_set_absolute_size"))(desc, Float64(size) * 1024.0)
                CFunc<(PangoRef, Int32) -> Unit>(api.symbol(0, "pango_font_description_set_weight"))(desc, if (bold) { 700 } else { 400 })
            }
            desc
        } catch (e: Exception) {
            unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(0, "pango_font_description_free"))(desc) }
            throw e
        }
    }

    func source(context: PangoRef, desc: PangoRef): (String, String) {
        let font = PangoTextApi.require(unsafe { CFunc<(PangoRef, PangoRef, PangoRef) -> PangoRef>(
            api.symbol(0, "pango_font_map_load_font"))(map, context, desc) }, "selected font")
        try {
            let pattern = unsafe { CFunc<(PangoRef) -> PangoRef>(api.symbol(2, "pango_fc_font_get_pattern"))(font) }
            let path = api.patternString(pattern, "file")
            let original = match (sources.get(path)) {
                case Some(value) => value
                case None => throw NativeTextException("Pango selected a font outside the explicit chain")
            }
            (original, api.patternString(pattern, "fontvariations"))
        } finally { api.unref(font) }
    }

    func close(): Unit {
        if (closed) { return }; closed = true; api.unref(map)
    }
}
