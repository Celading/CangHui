package sdl

@Test
func platformTextHeadlessOptInIsUnavailable(): Unit {
    let renderer = Renderer.headless()
    @Expect(!renderer.platformTextLayoutEnabled())
    @Expect(renderer.textCaretPositionsUtf16("x", Int64(0)).isNone())
    @Expect(renderer.textCaretPositionsUtf16("x", [Int64(0)]).isNone())
    @Expect(renderer.textHitUtf16("x", 0.0).isNone())
    @Expect(renderer.textSelectionSpansUtf16("x", 0, 1).isNone())
    @Expect(!renderer.usePlatformTextLayout(true))
    @Expect(renderer.usePlatformTextLayout(false))
}

@When[os == "macOS"]
@Test
func platformTextRendererSwitchesMetricsAndReusesNativeLines(): Unit {
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("Native text mode", 400, 160, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        let original = r.textWidth("👩‍👩‍👧‍👦", pointSize: 24.0)
        let decorated = FontStyle(bold: true, underline: true)
        let decoratedWidth = r.textWidth("Decorated 仓绘", pointSize: 24.0, style: decorated)
        @Expect(!r.platformTextLayoutEnabled())
        @Expect(r.usePlatformTextLayout(true))
        let native = r.textWidth("👩‍👩‍👧‍👦", pointSize: 24.0)
        @Expect(native < 60.0 && native < original)
        // Unsupported decorations keep measurement and drawing on SDL_ttf, not mixed owners.
        @Expect(r.textWidth("Decorated 仓绘", pointSize: 24.0, style: decorated), decoratedWidth)
        @Expect(r.textCaretPositionsUtf16("x", Int64(0), style: decorated).isNone())
        @Expect(r.textHitUtf16("x", 0.0, style: decorated).isNone())
        @Expect(r.textSelectionSpansUtf16("x", 0, 1, style: decorated).isNone())
        let mixed = "abc אבג def"
        let indices = Array<Int64>(12, {i => i})
        let batched = r.textCaretPositionsUtf16(mixed, indices).getOrThrow()
        let shaped = r.textShapeCount()
        for (i in 0..indices.size) {
            let scalar = r.textCaretPositionsUtf16(mixed, indices[i]).getOrThrow()
            @Expect(batched[i][0], scalar[0])
            @Expect(batched[i][1], scalar[1])
        }
        @Expect(r.textShapeCount(), shaped)
        @Expect(r.textCaretPositionsUtf16(mixed, Array<Int64>()).getOrThrow().isEmpty())
        r.resetTextMeasureCount()
        let target = r.createTargetTexture(400.0, 160.0)
        try {
            r.renderToTexture(target, 400.0, 160.0, Color.rgb(0, 0, 0)) {
                let width = r.textWidth("仓绘 مرحبا 😀", pointSize: 24.0)
                @Expect(width > 60.0)
                r.text("仓绘 مرحبا 😀", 10.0, 10.0, Color.rgb(255, 255, 255), pointSize: 24.0)
                let first = r.textShapeCount()
                r.text("仓绘 مرحبا 😀", 10.0, 60.0, Color.rgb(255, 255, 255), pointSize: 24.0)
                @Expect(r.textShapeCount(), first)
                @Expect(first, UInt64(1))
            }
        } finally { target.close() }
        @Expect(r.usePlatformTextLayout(false))
        @Expect(r.textWidth("👩‍👩‍👧‍👦", pointSize: 24.0), original)
        @Expect(!r.platformTextLayoutEnabled())
    } finally {
        window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride()
    }
}
