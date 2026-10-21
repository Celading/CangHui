package chui.core

import sdl.{Fonts, Renderer, SdlWindow, Size, WindowSpec}
import std.fs.exists
import std.math.abs

@When[os == "macOS"]
@Test
func labelFontEnvironmentChangeInvalidatesSingleAndWrappedCaches(): Unit {
    let first = "/System/Library/Fonts/Supplemental/Arial.ttf"
    let second = "assets/fonts/HarmonyOS_Sans_SC.ttf"
    @Expect(exists(first) && exists(second))
    Fonts.registerBundledFallback(second)
    let window = SdlWindow(WindowSpec("Label font cache", 500, 220, supersample: 1))
    try {
        let ctx = UiContext(window.renderer, Theme.light())
        for (native in [false, true]) {
            @Expect(window.renderer.usePlatformTextLayout(native))
            for (wrapped in [false, true]) {
                Fonts.register("Dynamic label family", first)
                let cached = Label("iiii WWWW Typeface width wrap sample").fontSize(24.0)
                    .fontFamily("Dynamic label family")
                if (wrapped) { cached.wrap() }
                let available = Size(if (wrapped) { 155.0 } else { 3000.0 }, 1000.0)
                let before = cached.measure(ctx, available)
                Fonts.register("Dynamic label family", second)
                let after = cached.measure(ctx, available)
                let fresh = Label("iiii WWWW Typeface width wrap sample").fontSize(24.0)
                    .fontFamily("Dynamic label family")
                if (wrapped) { fresh.wrap() }
                let expected = fresh.measure(ctx, available)
                @Expect(abs(after.w - expected.w) < 0.01)
                @Expect(abs(after.h - expected.h) < 0.01)
                if (available.w > 1000.0) {
                    @Expect(abs(before.w - expected.w) > 0.1 || abs(before.h - expected.h) > 0.1)
                }
                let warm = cached.measure(ctx, available)
                @Expect(warm.w, after.w)
                @Expect(warm.h, after.h)
            }
        }
    } finally {
        window.close()
        Fonts.unregister("Dynamic label family")
        Fonts.clearBundledFallbackOverride()
    }
}

@When[os == "macOS"]
@Test
func labelFontEnvironmentChangeFromHeadlessToLiveUsesRealMetrics(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Label renderer cache", 400, 120, supersample: 1))
    try {
        let cached = Label("iiii WWWW 中文").fontSize(24.0)
        let available = Size(3000.0, 300.0)
        let headless = UiContext(Renderer.headless(), Theme.light())
        let live = UiContext(window.renderer, Theme.light())
        let before = cached.measure(headless, available)
        let after = cached.measure(live, available)
        let expected = Label("iiii WWWW 中文").fontSize(24.0).measure(live, available)
        @Expect(abs(before.w - expected.w) > 1.0)
        @Expect(abs(after.w - expected.w) < 0.01)
        @Expect(headless.renderer.textLayoutEnvironmentKey() != live.renderer.textLayoutEnvironmentKey())
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}
