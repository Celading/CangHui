package sdl

import std.fs.exists

@Test
func nativeMixedFallbackPreservesComplementaryScriptAdvances(): Unit {
    let latin = "/System/Library/Fonts/Supplemental/Arial.ttf"
    if (!exists(latin)) { return }
    let bundled = bundledFontFixture()
    @Expect(!bundled.isEmpty())
    Fonts.clear()
    Fonts.registerBundledFallback(bundled)
    Fonts.register("mixed-latin", latin)
    let window = SdlWindow(WindowSpec("Mixed font fallback", 420, 150))
    try {
        let r = window.renderer
        // Arial covers Arabic, Harmony covers Chinese; neither covers this complete run.
        let arabic = "مرحبا"
        let chinese = "仓绘"
        let mixed = r.textWidth(arabic + chinese, pointSize: 24.0, font: Some("mixed-latin"))
        let expected = r.textWidth(arabic, pointSize: 24.0, font: Some("mixed-latin")) +
            r.textWidth(chinese, pointSize: 24.0)
        @Expect(mixed > expected - 2.0 && mixed < expected + 2.0)
        r.text(arabic + chinese, 12.0, 12.0, Color.rgb(10, 20, 30), pointSize: 24.0,
            font: Some("mixed-latin"))
        let shapes = r.textShapeCount()
        r.text(arabic + chinese, 12.0, 12.0, Color.rgb(10, 20, 30), pointSize: 24.0,
            font: Some("mixed-latin"))
        @Expect(r.textShapeCount(), shapes)
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearBundledFallbackOverride()
    }
}

@Test
func nativeMixedFallbackChainsDoNotContaminateEachOther(): Unit {
    let latin = "/System/Library/Fonts/Supplemental/Arial.ttf"
    if (!exists(latin)) { return }
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    Fonts.register("arabic-primary", latin)
    Fonts.register("cjk-primary", bundledFontFixture())
    let window = SdlWindow(WindowSpec("Font chain isolation", 500, 140))
    try {
        let r = window.renderer
        let sample = "MMMMMMMMمرحبا仓绘"
        r.setThemeFontFamily(Some("cjk-primary"))
        let latinWidth = r.textWidth(sample, pointSize: 24.0, font: Some("arabic-primary"))
        r.text(sample, 0.0, 0.0, Color.rgb(20, 20, 20), pointSize: 24.0, font: Some("arabic-primary"))
        r.setThemeFontFamily(Some("arabic-primary"))
        let cjkWidth = r.textWidth(sample, pointSize: 24.0, font: Some("cjk-primary"))
        r.text(sample, 0.0, 35.0, Color.rgb(20, 20, 20), pointSize: 24.0, font: Some("cjk-primary"))
        @Expect(latinWidth != cjkWidth)
        let warmed = r.textShapeCount()
        r.setThemeFontFamily(Some("cjk-primary"))
        @Expect(r.textWidth(sample, pointSize: 24.0, font: Some("arabic-primary")), latinWidth)
        r.text(sample, 0.0, 70.0, Color.rgb(20, 20, 20), pointSize: 24.0, font: Some("arabic-primary"))
        @Expect(r.textShapeCount(), warmed)
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearBundledFallbackOverride()
    }
}

@Test
func nativeMixedFallbackSizeStyleAndEvictionRemainUsable(): Unit {
    let latin = "/System/Library/Fonts/Supplemental/Arial.ttf"
    if (!exists(latin)) { return }
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    Fonts.register("mixed-latin", latin)
    let window = SdlWindow(WindowSpec("Font chain variants", 600, 180))
    try {
        let r = window.renderer
        var previousShapes: UInt64 = 0
        // More than the chain cache cap: exercise parent/child lifetime on eviction and recreation.
        for (i in 0..40) {
            let size = Float32(15 + i)
            let style = FontStyle(bold: i % 2 == 1)
            let expected = r.textWidth("مرحبا", pointSize: size, style: style, font: Some("mixed-latin")) +
                r.textWidth("仓绘", pointSize: size, style: style)
            let mixed = r.textWidth("مرحبا仓绘", pointSize: size, style: style, font: Some("mixed-latin"))
            @Expect(mixed > expected - 2.0 && mixed < expected + 2.0)
            r.text("مرحبا仓绘", 0.0, 0.0, Color.rgb(10, 20, 30), pointSize: size,
                style: style, font: Some("mixed-latin"))
            @Expect(r.textShapeCount() > previousShapes)
            previousShapes = r.textShapeCount()
        }
        r.text("مرحبا仓绘", 0.0, 0.0, Color.rgb(10, 20, 30), pointSize: 15.0,
            font: Some("mixed-latin"))
        @Expect(r.textShapeCount() > previousShapes)
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearBundledFallbackOverride()
    }
}
