package sdl

import sdl.text.{NativeTextLineSpec, NativeTextColorSpan}
import std.math.abs

@Test
func attributedTextUnsupportedBackendNeverPretendsToDrawOrMeasure(): Unit {
    let renderer = Renderer.recordingHeadless()
    let spec = NativeTextLineSpec("A😀", colors: [NativeTextColorSpan(0, 1, 240, 20, 30, 255)])
    @Expect(renderer.textSize(spec).isNone())
    @Expect(renderer.textCaretPositionsUtf16(spec, Int64(0)).isNone())
    @Expect(renderer.textCaretPositionsUtf16(spec, [Int64(0)]).isNone())
    @Expect(renderer.textHitUtf16(spec, 0.0).isNone())
    @Expect(renderer.textSelectionSpansUtf16(spec, 0, 1).isNone())
    @Expect(!renderer.text(spec, 0.0, 0.0))
    @Expect(renderer.drawIr().isEmpty())
}

@When[os == "macOS"]
@Test
func attributedRendererSharesOneLineAcrossAllQueriesAndDraws(): Unit {
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("Attributed native text", 400, 180, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let spec = NativeTextLineSpec("abc אבג def", colors: [NativeTextColorSpan(1, 5, 230, 30, 40, 255)])
        r.resetTextMeasureCount()
        let size = r.textSize(spec, pointSize: 24.0).getOrThrow()
        @Expect(size.w > 60.0)
        @Expect(r.textShapeCount(), UInt64(1))
        let indices = Array<Int64>(12, {i => i})
        let all = r.textCaretPositionsUtf16(spec, indices, pointSize: 24.0).getOrThrow()
        for (i in 0..indices.size) {
            let single = r.textCaretPositionsUtf16(spec, indices[i], pointSize: 24.0).getOrThrow()
            @Expect(single[0], all[i][0])
            @Expect(single[1], all[i][1])
        }
        @Expect(r.textHitUtf16(spec, all[1][0], pointSize: 24.0).getOrThrow(), Int64(1))
        let selected = r.textSelectionSpansUtf16(spec, 3, 5, pointSize: 24.0).getOrThrow()
        @Expect(selected.size >= 2)
        @Expect(r.text(spec, 10.0, 10.0, pointSize: 24.0))
        @Expect(r.textShapeCount(), UInt64(1))
        // Same immutable contents share cache; caller-owned source arrays cannot retarget it.
        let same = NativeTextLineSpec(spec.text, colors: spec.colors())
        @Expect(r.textSize(same, pointSize: 24.0).getOrThrow().w, size.w)
        @Expect(r.textShapeCount(), UInt64(1))
        let changed = NativeTextLineSpec(spec.text, colors: [NativeTextColorSpan(1, 5, 30, 230, 40, 255)])
        let _ = r.textSize(changed, pointSize: 24.0)
        @Expect(r.textShapeCount(), UInt64(2))
        let baseChanged = NativeTextLineSpec(spec.text, colors: spec.colors(), red: 90)
        let _ = r.textSize(baseChanged, pointSize: 24.0)
        @Expect(r.textShapeCount(), UInt64(3))
        let _ = r.textWidth(spec.text, pointSize: 24.0)
        @Expect(r.textShapeCount(), UInt64(4))
        // Unsupported styles reject both halves, never silently use a plain native line.
        let italic = FontStyle(italic: true)
        @Expect(r.textSize(spec, style: italic).isNone())
        @Expect(r.textCaretPositionsUtf16(spec, Int64(0), style: italic).isNone())
        @Expect(!r.text(spec, 0.0, 0.0, style: italic))
        r.setScale(2.0)
        let scaled = r.textSize(spec, pointSize: 24.0).getOrThrow()
        @Expect(abs(scaled.w - size.w) < 0.05)
        let scaledCaret = r.textCaretPositionsUtf16(spec, Int64(1), pointSize: 24.0).getOrThrow()
        @Expect(abs(scaledCaret[0] - all[1][0]) < 0.05)
        @Expect(r.text(spec, 10.0, 40.0, pointSize: 24.0))
        @Expect(r.usePlatformTextLayout(false))
        @Expect(r.textSize(spec).isNone())
    } finally { window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride() }
}
