package sdl.text

import std.math.{ceil, floor}
import std.collection.{ArrayList, HashMap, HashSet}

@When[os == "macOS"]
private func applyMacTextColor(api: MacTextApi, attributed: MacRef, span: NativeTextColorSpan): Unit {
    if (span.start == span.end) { return }
    var range = MacTextRange()
    range.location = span.start; range.length = span.end - span.start
    let color = MacTextApi.require(unsafe {
        CFunc<(Float64, Float64, Float64, Float64) -> MacRef>(api.symbol(2,
            "CGColorCreateGenericRGB"))(Float64(span.red) / 255.0, Float64(span.green) / 255.0,
                Float64(span.blue) / 255.0, Float64(span.alpha) / 255.0) }, "span color")
    try {
        unsafe {
            CFunc<(MacRef, MacTextRange, MacRef, MacRef) -> Unit>(api.symbol(0,
                "CFAttributedStringSetAttribute"))(attributed, range,
                    api.constant(1, "kCTForegroundColorFromContextAttributeName"),
                    api.constant(0, "kCFBooleanFalse"))
            CFunc<(MacRef, MacTextRange, MacRef, MacRef) -> Unit>(api.symbol(0,
                "CFAttributedStringSetAttribute"))(attributed, range,
                    api.constant(1, "kCTForegroundColorAttributeName"), color)
        }
    } finally { api.release(color) }
}

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
internal class MacTextLine <: PlatformTextLine {
    private let api: MacTextApi
    private let pointer: MacRef
    private var closed = false
    let metrics: NativeTextMetrics
    let ascent: Float64
    let descent: Float64
    let primaryFont: String
    let sourcePath: String

    init(api: MacTextApi, text: String, paths: Array<String>, defaultPath: String,
        pointSize: Float32, bold: Bool, paint!: ?NativeTextLineSpec = None) {
        this.api = api
        if (let Some(spec) <- paint) {
            if (spec.text != text) { throw NativeTextException("Native line paint belongs to different text") }
        }
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
            if (let Some(spec) <- paint) {
                let mutable = MacTextApi.require(unsafe { CFunc<(MacRef, Int64, MacRef) -> MacRef>(
                    api.symbol(0, "CFAttributedStringCreateMutableCopy"))(MacRef(), 0, attributed) },
                    "mutable attributed string")
                api.release(attributed)
                attributed = mutable
                // A context-colored run can inherit the preceding run's graphics state.
                // Freeze the base color as an attribute too, in the same layout identity.
                applyMacTextColor(api, attributed, NativeTextColorSpan(0, spec.utf16Length,
                    spec.red, spec.green, spec.blue, spec.alpha))
                for (span in spec.layoutColors()) {
                    applyMacTextColor(api, attributed, span)
                }
            }
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

    public func nativeMetrics(): NativeTextMetrics { metrics }
    public func primarySourcePath(): String { sourcePath }

    public func caretUtf16(index: Int64): (Float32, Float32) {
        ensureOpen()
        var secondary = 0.0
        let x = unsafe { CFunc<(MacRef, Int64, CPointer<Float64>) -> Float64>(api.symbol(1,
            "CTLineGetOffsetForStringIndex"))(pointer, index, inout secondary) }
        (Float32(x), Float32(secondary))
    }

    public func hitUtf16(x: Float32): Int64 {
        ensureOpen()
        var point = MacTextPoint()
        point.x = Float64(x)
        unsafe { CFunc<(MacRef, MacTextPoint) -> Int64>(api.symbol(1,
            "CTLineGetStringIndexForPosition"))(pointer, point) }
    }

    public func rightToLeftUtf16(indices: Array<Int64>): Array<Bool> {
        ensureOpen()
        // Scan native runs once, not once per query. Alternating LTR/RTL text
        // otherwise degenerates into a quadratic run scan. Keep only requested
        // offsets; native runs remain the sole owner of resolved bidi direction.
        let pending = HashSet<Int64>()
        for (index in indices) { pending.add(index) }
        let resolved = HashMap<Int64, Bool>()
        let runs = unsafe { CFunc<(MacRef) -> MacRef>(api.symbol(1, "CTLineGetGlyphRuns"))(pointer) }
        for (i in 0..api.count(runs)) {
            let run = api.item(runs, i)
            let range = unsafe { CFunc<(MacRef) -> MacTextRange>(api.symbol(1, "CTRunGetStringRange"))(run) }
            let status = unsafe { CFunc<(MacRef) -> UInt32>(api.symbol(1, "CTRunGetStatus"))(run) }
            let rtl = (status & UInt32(1)) != UInt32(0)
            for (index in range.location..(range.location + range.length)) {
                if (pending.contains(index)) { resolved[index] = rtl; pending.remove(index) }
            }
            if (pending.isEmpty()) { break }
        }
        if (!pending.isEmpty()) { throw NativeTextException("CoreText direction index has no character run") }
        Array<Bool>(indices.size, {i => resolved[indices[i]]})
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

    // Logical selection may paint disconnected visual intervals in a bidi line.
    // Run endpoints disambiguate CTLine's primary/secondary positions at bidi boundaries.
    public func selectionUtf16(start: Int64, end: Int64): Array<(Float32, Float32)> {
        ensureOpen()
        let spans = ArrayList<(Float32, Float32)>()
        if (start >= end) { return spans.toArray() }
        let runs = unsafe { CFunc<(MacRef) -> MacRef>(api.symbol(1, "CTLineGetGlyphRuns"))(pointer) }
        for (i in 0..api.count(runs)) {
            let run = api.item(runs, i)
            let range = unsafe { CFunc<(MacRef) -> MacTextRange>(api.symbol(1,
                "CTRunGetStringRange"))(run) }
            let a = max(start, range.location)
            let b = min(end, range.location + range.length)
            if (a >= b) { continue }
            let count = unsafe { CFunc<(MacRef) -> Int64>(api.symbol(1, "CTRunGetGlyphCount"))(run) }
            if (count < 1) { continue }
            var first = MacTextPoint()
            var one = MacTextRange()
            one.length = 1
            unsafe { CFunc<(MacRef, MacTextRange, CPointer<MacTextPoint>) -> Unit>(api.symbol(1,
                "CTRunGetPositions"))(run, one, inout first) }
            let width = unsafe {
                CFunc<(MacRef, MacTextRange, CPointer<Float64>, CPointer<Float64>, CPointer<Float64>) -> Float64>(
                    api.symbol(1, "CTRunGetTypographicBounds"))(run, MacTextRange(), CPointer<Float64>(),
                        CPointer<Float64>(), CPointer<Float64>()) }
            let status = unsafe { CFunc<(MacRef) -> UInt32>(api.symbol(1, "CTRunGetStatus"))(run) }
            let left = Float32(first.x)
            let right = Float32(first.x + width)
            let rtl = (status & UInt32(1)) != UInt32(0)
            let xA = if (a == range.location) { if (rtl) { right } else { left } }
                else { caretUtf16(a)[0] }
            let xB = if (b == range.location + range.length) { if (rtl) { left } else { right } }
                else { caretUtf16(b)[0] }
            let lower = max(left, min(xA, xB))
            let upper = min(right, max(xA, xB))
            if (upper > lower) { spans.add((lower, upper)) }
        }
        spans.toArray()
    }

    public func raster(color: NativeTextColor): NativeTextRaster {
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

    public func close(): Unit {
        if (closed) { return }
        closed = true
        api.release(pointer)
    }

    private func ensureOpen(): Unit {
        if (closed) { throw NativeTextException("CoreText line is closed") }
    }
}
