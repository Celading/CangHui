package sdl

import std.env.getVariable
import std.math.abs
import sdl.text.{NativeTextLineSpec, NativeTextColorSpan}

@When[os == "Linux"]
@Test
func pangoRendererSharesGeometryPaintScaleAndCache(): Unit {
    if (getVariable("CANGHUI_TEST_PANGO") != Some("1")) { return }
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("Pango renderer", 500, 200, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(!r.platformTextLayoutEnabled())
        @Expect(r.usePlatformTextLayout(true))
        let spec = NativeTextLineSpec("abc אבג 仓绘", colors: [NativeTextColorSpan(0, 3, 230, 40, 60, 255)])
        r.resetTextMeasureCount()
        let size = r.textSize(spec, pointSize: 24.0).getOrThrow()
        let caret = r.textCaretPositionsUtf16(spec, Int64(1), pointSize: 24.0).getOrThrow()
        @Expect(r.textHitUtf16(spec, caret[0], pointSize: 24.0).getOrThrow(), Int64(1))
        @Expect(r.textSelectionSpansUtf16(spec, 0, 5, pointSize: 24.0).getOrThrow().size >= 2)
        let target = r.createTargetTexture(500.0, 200.0)
        try {
            r.renderToTexture(target, 500.0, 200.0, Color.rgb(0, 0, 0)) {
                @Expect(r.text(spec, 8.0, 8.0, pointSize: 24.0))
                @Expect(r.text(spec, 8.0, 48.0, pointSize: 24.0))
            }
        } finally { target.close() }
        @Expect(r.textShapeCount(), UInt64(1))
        r.setScale(2.0)
        let scaled = r.textSize(spec, pointSize: 24.0).getOrThrow()
        @Expect(abs(scaled.w - size.w) < 0.05)
        let scaledCaret = r.textCaretPositionsUtf16(spec, Int64(1), pointSize: 24.0).getOrThrow()
        @Expect(abs(scaledCaret[0] - caret[0]) < 0.05)
        let decorated = FontStyle(underline: true)
        @Expect(r.textSize(spec, style: decorated).isNone())
        @Expect(!r.text(spec, 0.0, 0.0, style: decorated))
        @Expect(r.usePlatformTextLayout(false))
        @Expect(r.textSize(spec).isNone())
        @Expect(r.usePlatformTextLayout(true))
        @Expect(r.text(spec, 8.0, 8.0, pointSize: 24.0))
    } finally { window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride() }
}
