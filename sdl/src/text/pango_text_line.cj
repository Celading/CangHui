package sdl.text

import std.collection.ArrayList

@When[os == "Linux"]
internal class PangoTextLine <: PlatformTextLine {
    private let api: PangoTextApi
    private let pointer: PangoRef
    private let offsets: PangoTextOffsets
    private var closed = false
    let metrics: NativeTextMetrics
    let sourcePath: String
    let variations: String
    private let empty: Bool

    init(api: PangoTextApi, text: String, paths: Array<String>, defaultPath: String,
        size: Float32, bold: Bool, paint!: ?NativeTextLineSpec = None) {
        this.api = api; this.empty = text.isEmpty()
        this.offsets = PangoTextOffsets(text)
        if (!(size > 0.0 && size <= 4096.0)) { throw NativeTextException("Pango text size is outside the supported range") }
        if (let Some(spec) <- paint) {
            if (spec.text != text) { throw NativeTextException("Native line paint belongs to different text") }
        }
        let fonts = api.fontMap(paths, defaultPath)
        let context = fonts.context()
        var desc = PangoRef(); var layout = PangoRef()
        try {
            desc = fonts.description(size, bold)
            let (source, variation) = fonts.source(context, desc)
            this.sourcePath = source; this.variations = variation
            unsafe {
                layout = PangoTextApi.require(CFunc<(PangoRef) -> PangoRef>(api.symbol(0, "pango_layout_new"))(context), "layout")
                CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(0, "pango_layout_set_font_description"))(layout, desc)
                CFunc<(PangoRef, Int32) -> Unit>(api.symbol(0, "pango_layout_set_single_paragraph_mode"))(layout, 1)
                try (c = LibC.mallocCString(text).asResource()) {
                    CFunc<(PangoRef, CString, Int32) -> Unit>(api.symbol(0, "pango_layout_set_text"))(layout, c.value, Int32(text.size))
                }
            }
            if (let Some(spec) <- paint) { applyPangoTextPaint(api, layout, offsets, spec) }
            var w: Int32 = 0; var h: Int32 = 0
            unsafe { CFunc<(PangoRef, CPointer<Int32>, CPointer<Int32>) -> Unit>(api.symbol(0,
                "pango_layout_get_size"))(layout, inout w, inout h) }
            if (w < 0 || h <= 0) { throw NativeTextException("Pango returned invalid line extents") }
            this.metrics = NativeTextMetrics(Float32(w) / 1024.0, Float32(h) / 1024.0)
            this.pointer = layout
        } catch (e: Exception) { api.unref(layout); throw e }
        finally {
            if (desc.isNotNull()) { unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(0, "pango_font_description_free"))(desc) } }
            api.unref(context)
        }
    }

    private func ensureOpen(): Unit {
        if (closed) { throw NativeTextException("Pango native line is closed") }
    }
    public func nativeMetrics(): NativeTextMetrics { ensureOpen(); metrics }
    public func primarySourcePath(): String { ensureOpen(); sourcePath }

    public func caretUtf16(index: Int64): (Float32, Float32) {
        ensureOpen()
        let byteIndex = offsets.byteIndex(index)
        var strong = PangoTextRect(); var weak = PangoTextRect()
        unsafe { CFunc<(PangoRef, Int32, CPointer<PangoTextRect>, CPointer<PangoTextRect>) -> Unit>(api.symbol(0,
            "pango_layout_get_cursor_pos"))(pointer, byteIndex, inout strong, inout weak) }
        (Float32(strong.x) / 1024.0, Float32(weak.x) / 1024.0)
    }

    public func hitUtf16(x: Float32): Int64 {
        ensureOpen()
        if (empty) { return -1 }
        if (x != x) { throw NativeTextException("Pango hit coordinate is NaN") }
        // Outside the layout Pango returns false but still supplies a clamped hit.
        let units = Int32(max(-2000000000.0, min(2000000000.0, Float64(x) * 1024.0)))
        var index: Int32 = 0; var trailing: Int32 = 0
        unsafe { let _ = CFunc<(PangoRef, Int32, Int32, CPointer<Int32>, CPointer<Int32>) -> Int32>(api.symbol(0,
            "pango_layout_xy_to_index"))(pointer, units, 0, inout index, inout trailing) }
        offsets.utf16Index(index, trailing)
    }

    public func selectionUtf16(start: Int64, end: Int64): Array<(Float32, Float32)> {
        ensureOpen()
        let a = offsets.byteIndex(start); let b = offsets.byteIndex(end)
        let spans = ArrayList<(Float32, Float32)>()
        if (start >= end) { return spans.toArray() }
        var ranges = CPointer<Int32>(); var count: Int32 = 0
        unsafe {
            let line = PangoTextApi.require(CFunc<(PangoRef, Int32) -> PangoRef>(api.symbol(0,
                "pango_layout_get_line_readonly"))(pointer, 0), "layout line")
            CFunc<(PangoRef, Int32, Int32, CPointer<CPointer<Int32>>, CPointer<Int32>) -> Unit>(api.symbol(0,
                "pango_layout_line_get_x_ranges"))(line, a, b, inout ranges, inout count)
        }
        try {
            if (count < 0 || count > 1048576 || (count > 0 && ranges.isNull())) {
                throw NativeTextException("Pango selection ranges are invalid")
            }
            for (i in 0..Int64(count)) {
                let left = unsafe { Float32(ranges.read(i * 2)) / 1024.0 }
                let right = unsafe { Float32(ranges.read(i * 2 + 1)) / 1024.0 }
                if (right > left) { spans.add((left, right)) }
            }
            spans.toArray()
        } finally { unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(6, "g_free"))(PangoRef(ranges)) } }
    }

    func unknownGlyphCount(): Int32 {
        ensureOpen()
        unsafe { CFunc<(PangoRef) -> Int32>(api.symbol(0, "pango_layout_get_unknown_glyphs_count"))(pointer) }
    }

    public func raster(color: NativeTextColor): NativeTextRaster {
        ensureOpen(); pangoTextRaster(api, pointer, color)
    }

    public func close(): Unit {
        if (closed) { return }; closed = true; api.unref(pointer)
    }
}
