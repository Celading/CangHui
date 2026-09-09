package sdl.text

@When[os == "Linux"]
@C
private struct PangoTextAttribute {
    var klass = PangoRef()
    var start: UInt32 = 0
    var end: UInt32 = 0
}

@When[os == "Linux"]
internal func applyPangoTextPaint(api: PangoTextApi, layout: PangoRef, offsets: PangoTextOffsets,
    spec: NativeTextLineSpec): Unit {
    let attrs = PangoTextApi.require(unsafe { CFunc<() -> PangoRef>(api.symbol(0,
        "pango_attr_list_new"))() }, "paint attributes")
    try {
        let spans = spec.colors()
        for (i in 0..(spans.size + 1)) {
            let span = if (i == 0) { NativeTextColorSpan(0, spec.utf16Length, spec.red, spec.green, spec.blue, spec.alpha) }
                else { spans[i - 1] }
            if (span.start == span.end) { continue }
            let a = UInt32(offsets.byteIndex(span.start)); let b = UInt32(offsets.byteIndex(span.end))
            unsafe {
                let foreground = PangoTextApi.require(CFunc<(UInt16, UInt16, UInt16) -> PangoRef>(api.symbol(0,
                    "pango_attr_foreground_new"))(UInt16(span.red) * 257, UInt16(span.green) * 257, UInt16(span.blue) * 257), "foreground")
                let attr = CPointer<PangoTextAttribute>(foreground)
                var value = attr.read(); value.start = a; value.end = b; attr.write(value)
                CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(0, "pango_attr_list_change"))(attrs, foreground)
                let alpha = PangoTextApi.require(CFunc<(UInt16) -> PangoRef>(api.symbol(0,
                    "pango_attr_foreground_alpha_new"))(UInt16(span.alpha) * 257), "foreground alpha")
                let alphaAttr = CPointer<PangoTextAttribute>(alpha)
                var alphaValue = alphaAttr.read(); alphaValue.start = a; alphaValue.end = b; alphaAttr.write(alphaValue)
                CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(0, "pango_attr_list_change"))(attrs, alpha)
            }
        }
        unsafe { CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(0, "pango_layout_set_attributes"))(layout, attrs) }
    } finally { unsafe { CFunc<(PangoRef) -> Unit>(api.symbol(0, "pango_attr_list_unref"))(attrs) } }
}
