package sdl

import std.fs.exists

@Test
func systemUiFontMeasuresChineseAndLatinText(): Unit {
    let window = SdlWindow(WindowSpec("Font test", 320, 120))
    try {
        @Expect(window.renderer.textWidth("仓颉 GUI", pointSize: FontSizes.BODY) > 0.0)
        @Expect(window.renderer.textHeight(pointSize: FontSizes.BODY) > 0.0)
    } finally {
        window.close()
    }
}

@Test
func bundledFontIsDefaultAndCatchesMissingCjkGlyphs(): Unit {
    let bundled = bundledFontFixture()
    @Expect(!bundled.isEmpty())
    Fonts.clear()
    Fonts.clearApplicationFamily()
    Fonts.registerBundledFallback(bundled)
    let latinOnly = "/System/Library/Fonts/Supplemental/Arial.ttf"
    if (exists(latinOnly)) { Fonts.register("latin-only", latinOnly) }
    let window = SdlWindow(WindowSpec("Font fallback test", 360, 140))
    try {
        let defaultResolution = window.renderer.fontResolutionForText("CangHui 仓颉")
        @Expect(defaultResolution.sourceName(), "bundled")
        @Expect(defaultResolution.path, bundled)
        @Expect(window.renderer.textWidth("CangHui 仓颉", pointSize: FontSizes.BODY) > 0.0)

        if (exists(latinOnly)) {
            let latin = window.renderer.fontResolutionForText("CangHui", font: Some("latin-only"))
            @Expect(latin.sourceName(), "application")
            let cjk = window.renderer.fontResolutionForText("仓颉界面", font: Some("latin-only"))
            @Expect(cjk.sourceName(), "bundled")
            let boldCjk = window.renderer.fontResolutionForText(
                "仓颉界面", style: FontStyle(bold: true), font: Some("latin-only"))
            @Expect(boldCjk.sourceName(), "bundled")
        }
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearApplicationFamily()
        Fonts.clearBundledFallbackOverride()
    }
}
