package sdl.text

@When[os == "Linux"]
internal func pangoTextRaster(api: PangoTextApi, line: PangoRef, color: NativeTextColor): NativeTextRaster {
    var ink = PangoTextRect(); var logical = PangoTextRect()
    unsafe { CFunc<(PangoRef, CPointer<PangoTextRect>, CPointer<PangoTextRect>) -> Unit>(api.symbol(0,
        "pango_layout_get_pixel_extents"))(line, inout ink, inout logical) }
    let left = min(Int64(ink.x), Int64(logical.x)) - 2
    let top = min(Int64(ink.y), Int64(logical.y)) - 2
    let right = max(Int64(ink.x) + Int64(ink.w), Int64(logical.x) + Int64(logical.w)) + 2
    let bottom = max(Int64(ink.y) + Int64(ink.h), Int64(logical.y) + Int64(logical.h)) + 2
    let w = max(1, right - left); let h = max(1, bottom - top)
    if (w > 16384 || h > 4096 || w * h > 4194304) { throw NativeTextException("Pango raster exceeds16MiB or dimension limits") }
    let surface = PangoTextApi.require(unsafe { CFunc<(Int32, Int32, Int32) -> PangoRef>(api.symbol(4,
        "cairo_image_surface_create"))(0, Int32(w), Int32(h)) }, "raster surface")
    var cr = PangoRef()
    try {
        unsafe {
            if (CFunc<(PangoRef) -> Int32>(api.symbol(4, "cairo_surface_status"))(surface) != 0) {
                throw NativeTextException("Cairo raster allocation failed")
            }
            cr = PangoTextApi.require(CFunc<(PangoRef) -> PangoRef>(api.symbol(4, "cairo_create"))(surface), "raster context")
            CFunc<(PangoRef, Float64, Float64, Float64, Float64) -> Unit>(api.symbol(4, "cairo_set_source_rgba"))(
                cr, Float64(color.red) / 255.0, Float64(color.green) / 255.0, Float64(color.blue) / 255.0, Float64(color.alpha) / 255.0)
            CFunc<(PangoRef, Float64, Float64) -> Unit>(api.symbol(4, "cairo_move_to"))(cr, -Float64(left), -Float64(top))
            CFunc<(PangoRef, PangoRef) -> Unit>(api.symbol(1, "pango_cairo_show_layout"))(cr, line)
            if (CFunc<(PangoRef) -> Int32>(api.symbol(4, "cairo_status"))(cr) != 0) {
                throw NativeTextException("Cairo text rasterization failed")
            }
            CFunc<(PangoRef) -> Unit>(api.symbol(4, "cairo_surface_flush"))(surface)
            let data = CFunc<(PangoRef) -> CPointer<UInt8>>(api.symbol(4, "cairo_image_surface_get_data"))(surface)
            let stride = Int64(CFunc<(PangoRef) -> Int32>(api.symbol(4, "cairo_image_surface_get_stride"))(surface))
            if (data.isNull() || stride < w * 4) { throw NativeTextException("Cairo raster has invalid storage") }
            let pixels = Array<UInt8>(w * h * 4, repeat: 0)
            for (y in 0..h) {
                for (x in 0..w) {
                    // Reading native UInt32 works on either endian: Cairo ARGB32
                    // is a native-endian premultiplied integer, NOT RGBA bytes.
                    let argb = CPointer<UInt32>(data + y * stride + x * 4).read()
                    let a = (argb >> 24) & 255
                    let out = (y * w + x) * 4
                    pixels[out + 3] = UInt8(a)
                    if (a != 0) {
                        pixels[out] = UInt8(min(UInt32(255), (((argb >> 16) & 255) * 255 + a / 2) / a))
                        pixels[out + 1] = UInt8(min(UInt32(255), (((argb >> 8) & 255) * 255 + a / 2) / a))
                        pixels[out + 2] = UInt8(min(UInt32(255), ((argb & 255) * 255 + a / 2) / a))
                    }
                }
            }
            NativeTextRaster(pixels, Int32(w), Int32(h), Float32(left), Float32(top))
        }
    } finally {
        unsafe {
            if (cr.isNotNull()) { CFunc<(PangoRef) -> Unit>(api.symbol(4, "cairo_destroy"))(cr) }
            CFunc<(PangoRef) -> Unit>(api.symbol(4, "cairo_surface_destroy"))(surface)
        }
    }
}
