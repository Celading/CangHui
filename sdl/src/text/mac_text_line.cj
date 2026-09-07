package sdl.text

import std.math.{ceil, floor}

/** Pixel data owns its bytes; offsets place the padded image relative to the text's top-left. */
protected struct NativeTextRaster {
    public let pixels: Array<UInt8>
    public let width: Int32
    public let height: Int32
    public let offsetX: Float32
    public let offsetY: Float32
    public init(pixels: Array<UInt8>, width: Int32, height: Int32, x: Float32, y: Float32) {
        this.pixels = pixels; this.width = width; this.height = height
        this.offsetX = x; this.offsetY = y
    }
}

// One immutable native line owns BOTH measurement and raster/caret geometry.
// The API owner must outlive it. No UTF-8 offset is passed to a CoreText index API.
@When[os == "macOS"]
internal class MacTextLine {
    private let api: MacTextApi
    private let pointer: MacRef
    private var closed = false
    let metrics: NativeTextMetrics
    let ascent: Float64
    let descent: Float64
    let primaryFont: String
    let sourcePath: String

    init(api: MacTextApi, text: String, paths: Array<String>, defaultPath: String,
        pointSize: Float32, bold: Bool) {
        this.api = api
        var font = MacRef()
        var attrs = MacRef()
        var content = MacRef()
        var attributed = MacRef()
        var created = MacRef()
        try {
            let (selected, source) = api.fontChain(paths, defaultPath, Float64(pointSize), bold)
            font = selected
            this.sourcePath = source
            this.primaryFont = api.fontName(font)
            attrs = api.dictionary()
            api.set(attrs, api.constant(1, "kCTFontAttributeName"), font)
            api.set(attrs, api.constant(1, "kCTForegroundColorFromContextAttributeName"),
                api.constant(0, "kCFBooleanTrue"))
            content = api.string(text)
            attributed = MacTextApi.require(unsafe { CFunc<(MacRef, MacRef, MacRef) -> MacRef>(
                api.symbol(0, "CFAttributedStringCreate"))(MacRef(), content, attrs) }, "attributed string")
            created = MacTextApi.require(unsafe { CFunc<(MacRef) -> MacRef>(api.symbol(1,
                "CTLineCreateWithAttributedString"))(attributed) }, "line")
            var a = 0.0
            var d = 0.0
            var leading = 0.0
            let width = unsafe { CFunc<(MacRef, CPointer<Float64>, CPointer<Float64>, CPointer<Float64>) -> Float64>(
                api.symbol(1, "CTLineGetTypographicBounds"))(created, inout a, inout d, inout leading) }
            if (text.isEmpty()) {
                a = unsafe { CFunc<(MacRef) -> Float64>(api.symbol(1, "CTFontGetAscent"))(font) }
                d = unsafe { CFunc<(MacRef) -> Float64>(api.symbol(1, "CTFontGetDescent"))(font) }
            }
            this.ascent = a
            this.descent = d
            this.metrics = NativeTextMetrics(Float32(width), Float32(a + d + max(0.0, leading)))
            this.pointer = created
        } catch (e: Exception) { api.release(created); throw e }
        finally {
            api.release(attributed); api.release(content); api.release(attrs); api.release(font)
        }
    }

    func caretUtf16(index: Int64): (Float32, Float32) {
        ensureOpen()
        var secondary = 0.0
        let x = unsafe { CFunc<(MacRef, Int64, CPointer<Float64>) -> Float64>(api.symbol(1,
            "CTLineGetOffsetForStringIndex"))(pointer, index, inout secondary) }
        (Float32(x), Float32(secondary))
    }

    func hitUtf16(x: Float32): Int64 {
        ensureOpen()
        var point = MacTextPoint()
        point.x = Float64(x)
        unsafe { CFunc<(MacRef, MacTextPoint) -> Int64>(api.symbol(1,
            "CTLineGetStringIndexForPosition"))(pointer, point) }
    }

    func glyphCount(): Int64 {
        ensureOpen()
        let runs = unsafe { CFunc<(MacRef) -> MacRef>(api.symbol(1, "CTLineGetGlyphRuns"))(pointer) }
        var count: Int64 = 0
        for (i in 0..api.count(runs)) {
            count += unsafe { CFunc<(MacRef) -> Int64>(api.symbol(1, "CTRunGetGlyphCount"))(api.item(runs, i)) }
        }
        count
    }

    func raster(color: NativeTextColor): NativeTextRaster {
        ensureOpen()
        let bounds = unsafe { CFunc<(MacRef, MacRef) -> MacTextRect>(api.symbol(1,
            "CTLineGetImageBounds"))(pointer, MacRef()) }
        // Include typographic advances and overhangs; antialiasing may extend past ideal bounds.
        let left = floor(min(0.0, bounds.x)) - 2.0
        let right = ceil(max(Float64(metrics.width), bounds.x + bounds.w)) + 2.0
        let top = ceil(max(ascent, bounds.y + bounds.h)) + 2.0
        let bottom = floor(min(-descent, bounds.y)) - 2.0
        let w = right - left
        let h = top - bottom
        // An explicit resource bound, not an implicit crop or a pretend successful blank image.
        if (!(w >= 1.0 && h >= 1.0 && w <= 16384.0 && h <= 4096.0 && w * h <= 4194304.0)) {
            throw NativeTextException("CoreText raster exceeds the 16 MiB image limit")
        }
        let width = Int64(w)
        let height = Int64(h)
        let space = MacTextApi.require(unsafe { CFunc<() -> MacRef>(api.symbol(2,
            "CGColorSpaceCreateDeviceRGB"))() }, "RGB color space")
        var context = MacRef()
        try {
            // Premultiplied RGBA, big-endian component order, 8 bits per component.
            context = MacTextApi.require(unsafe {
                CFunc<(MacRef, UIntNative, UIntNative, UIntNative, UIntNative, MacRef, UInt32) -> MacRef>(
                    api.symbol(2, "CGBitmapContextCreate"))(MacRef(), UIntNative(width), UIntNative(height),
                        UIntNative(8), UIntNative(width * 4), space, 0x4001)
            }, "bitmap context")
            unsafe {
                CFunc<(MacRef, Float64, Float64, Float64, Float64) -> Unit>(api.symbol(2,
                    "CGContextSetRGBFillColor"))(context, Float64(color.red) / 255.0,
                        Float64(color.green) / 255.0, Float64(color.blue) / 255.0, Float64(color.alpha) / 255.0)
                CFunc<(MacRef, Float64, Float64) -> Unit>(api.symbol(2,
                    "CGContextSetTextPosition"))(context, -left, -bottom)
                CFunc<(MacRef, MacRef) -> Unit>(api.symbol(1, "CTLineDraw"))(pointer, context)
            }
            let raw = unsafe { CPointer<UInt8>(CFunc<(MacRef) -> MacRef>(api.symbol(2,
                "CGBitmapContextGetData"))(context)) }
            if (raw.isNull()) { throw NativeTextException("CoreText raster has no pixels") }
            let pixels = Array<UInt8>(width * height * 4, {_ => 0})
            for (i in 0..(width * height)) {
                let offset = i * 4
                let alpha = unsafe { raw.read(offset + 3) }
                pixels[offset + 3] = alpha
                if (alpha > 0) {
                    for (channel in 0..3) {
                        let premultiplied = unsafe { raw.read(offset + channel) }
                        pixels[offset + channel] = UInt8(min(Int64(255),
                            (Int64(premultiplied) * 255 + Int64(alpha) / 2) / Int64(alpha)))
                    }
                }
            }
            NativeTextRaster(pixels, Int32(width), Int32(height), Float32(left), Float32(ascent - top))
        } finally {
            if (context.isNotNull()) {
                unsafe { CFunc<(MacRef) -> Unit>(api.symbol(2, "CGContextRelease"))(context) }
            }
            unsafe { CFunc<(MacRef) -> Unit>(api.symbol(2, "CGColorSpaceRelease"))(space) }
        }
    }

    func close(): Unit {
        if (closed) { return }
        closed = true
        api.release(pointer)
    }

    private func ensureOpen(): Unit {
        if (closed) { throw NativeTextException("CoreText line is closed") }
    }
}
