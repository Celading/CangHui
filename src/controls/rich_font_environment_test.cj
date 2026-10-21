package chui.controls

import chui.core.{Theme, UiContext, TypographyEnvironment}
import sdl.{Fonts, SdlWindow, Size, WindowSpec}
import std.fs.exists
import std.math.abs

@When[os == "macOS"]
@Test
func richTextFontEnvironmentChangeInvalidatesBaseAndExplicitSpanCaches(): Unit {
    let first = "/System/Library/Fonts/Supplemental/Arial.ttf"
    let second = "assets/fonts/HarmonyOS_Sans_SC.ttf"
    @Expect(exists(first) && exists(second))
    Fonts.registerBundledFallback(second)
    let window = SdlWindow(WindowSpec("RichText font cache", 500, 220, supersample: 1))
    try {
        let ctx = UiContext(window.renderer, Theme.light())
        for (native in [false, true]) {
            @Expect(window.renderer.usePlatformTextLayout(native))
            for (explicit in [false, true]) {
                for (width in [Float32(155.0), Float32(3000.0)]) {
                    Fonts.register("Dynamic rich family", first)
                    let cached = fontEnvironmentRichText(explicit)
                    let available = Size(width, 1000.0)
                    let before = ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Dynamic rich family")) {=> cached.measure(ctx, available) }
                    Fonts.register("Dynamic rich family", second)
                    let after = ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Dynamic rich family")) {=> cached.measure(ctx, available) }
                    let expected = ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Dynamic rich family")) {=> fontEnvironmentRichText(explicit).measure(ctx, available) }
                    @Expect(abs(after.w - expected.w) < 0.01)
                    @Expect(abs(after.h - expected.h) < 0.01)
                    if (available.w > 1000.0) {
                    @Expect(abs(before.w - expected.w) > 0.1 || abs(before.h - expected.h) > 0.1)
                }
                    let warm = ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Dynamic rich family")) {=> cached.measure(ctx, available) }
                    @Expect(warm.w, after.w)
                    @Expect(warm.h, after.h)
                }
            }
        }
    } finally {
        window.close()
        Fonts.unregister("Dynamic rich family")
        Fonts.clearBundledFallbackOverride()
    }
}

private func fontEnvironmentRichText(explicit: Bool): RichText {
    if (explicit) {
        return RichText([RichSpan.text("iiii WWWW Typeface width wrap sample").fontFamily("Dynamic rich family")])
            .fontSize(24.0)
    }
    RichText([RichSpan.text("iiii WWWW Typeface width wrap sample")]).fontSize(24.0)
}
