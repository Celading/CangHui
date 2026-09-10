package chui.text

import std.env.getVariable
import std.math.abs
import chui.core.{State, Theme, UiContext, SemanticRuntime, SemanticTreeSnapshot, Widget, withActiveSemanticRuntime}
import sdl.{Fonts, Rect, SdlWindow, WindowSpec, TextCompositionEvent, TextCompositionPhase, UiEvent}

@When[os == "macOS"]
private func semanticGlyphTestFont(): ?String { Some("assets/fonts/HarmonyOS_Sans_SC.ttf") }
@When[os == "Linux"]
private func semanticGlyphTestFont(): ?String {
    if (getVariable("CANGHUI_TEST_PANGO") == Some("1")) { Some("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf") }
    else { None }
}
@When[os != "macOS" && os != "Linux"]
private func semanticGlyphTestFont(): ?String { None }

private func drawGlyphSnapshot(ctx: UiContext, widget: Widget, runtime: SemanticRuntime): SemanticTreeSnapshot {
    let target = ctx.renderer.createTargetTexture(420.0, 180.0)
    try {
        runtime.beginFrame()
        withActiveSemanticRuntime(runtime, { =>
            ctx.renderer.renderToTexture(target, 420.0, 180.0, ctx.theme.bg) { widget.draw(ctx) }
        })
        runtime.commitFrame()
    } finally { target.close() }
}

@Test
func nativeTextFieldPublishesActualGlyphsAfterFollowAndSuppressesPreeditSecrets(): Unit {
    let path = match (semanticGlyphTestFont()) { case Some(value) => value; case None => return }
    Fonts.registerBundledFallback(path)
    let window = SdlWindow(WindowSpec("Field semantic glyphs", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        @Expect(r.usePlatformTextLayout(true))
        let ctx = UiContext(r, Theme.light())
        let runtime = SemanticRuntime("glyphs")
        let value = State<String>("abc אבג long content keeps going")
        let field = TextField(value, key: "field")
        field.layout(ctx, Rect(10.0, 10.0, 100.0, 38.0))
        let first = drawGlyphSnapshot(ctx, field, runtime).nodes[0].textGeometry.getOrThrow()
        @Expect(first.x < 18.0)
        @Expect(first.layout.value, value.value)
        @Expect(first.layout.glyph(4).rightToLeft)
        let spans = r.textSelectionSpansUtf16(value.value, 4, 5).getOrThrow()
        @Expect(abs(first.layout.glyph(4).frame.x - spans[0][0]) < 0.1)
        let second = drawGlyphSnapshot(ctx, field, runtime).nodes[0].textGeometry.getOrThrow()
        @Expect(first.layout.same(second.layout))
        ctx.focus("field")
        @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin,
            text: "ni", selectionStart: 2, selectionLength: 0))))
        @Expect(drawGlyphSnapshot(ctx, field, runtime).nodes[0].textGeometry.isNone())
        let secure = TextField(State<String>("secret"), key: "secure").secureEntry()
        secure.layout(ctx, Rect(0.0, 0.0, 120.0, 38.0))
        let secret = drawGlyphSnapshot(ctx, secure, runtime).nodes[0]
        @Expect(secret.value, ""); @Expect(secret.textGeometry.isNone())
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}

@Test
func nativeTextAreaGlyphsPreserveHardLinesColoredLayoutAndClampedScroll(): Unit {
    let path = match (semanticGlyphTestFont()) { case Some(value) => value; case None => return }
    Fonts.registerBundledFallback(path)
    let window = SdlWindow(WindowSpec("Area semantic glyphs", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        @Expect(r.usePlatformTextLayout(true))
        let ctx = UiContext(r, Theme.light())
        let runtime = SemanticRuntime("glyphs")
        let value = State<String>("abc אבג\nمرحبا\r\n\n")
        let vertical = State<Float32>(999.0)
        let area = TextArea(value, key: "area", scroll: Some(vertical), editable: false)
        let frame = Rect(10.0, 12.0, 240.0, 60.0)
        area.layout(ctx, frame)
        let geometry = drawGlyphSnapshot(ctx, area, runtime).nodes[0].textGeometry.getOrThrow()
        @Expect(vertical.value < 999.0)
        @Expect(abs(geometry.y - (textInputViewport(frame).y - vertical.value)) < 0.1)
        @Expect(geometry.layout.value, value.value)
        @Expect(geometry.layout.glyph(4).rightToLeft)
        let last = geometry.layout.glyph(geometry.layout.count - 1)
        @Expect(last.startByte, value.value.size); @Expect(last.endByte, value.value.size)
        @Expect(last.line, Int64(3)); @Expect(last.frame.w, Float32(0.0))
        let cache = NativeSemanticGlyphCache()
        cache.resolve(ctx, "AאB", TextFieldTypography())
        for (_ in 0..20) { cache.resolve(ctx, "AאB", TextFieldTypography()) }
        @Expect(cache.rebuildCount(), UInt64(1))
        r.setScale(1.25)
        cache.resolve(ctx, "AאB", TextFieldTypography())
        @Expect(cache.rebuildCount(), UInt64(2))
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}
