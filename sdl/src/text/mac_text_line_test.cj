package sdl.text

import std.math.abs

@When[os == "macOS"]
@Test
func coreTextLineRetainsNamedFontsClustersAndCaretGeometry(): Unit {
    let api = MacTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    try {
        let regular = MacTextLine(api, "仓绘 A", [path], path, 24.0, false)
        let bold = MacTextLine(api, "仓绘 A", [path], path, 24.0, true)
        let emoji = MacTextLine(api, "👩‍👩‍👧‍👦", [path], path, 24.0, false)
        let mixed = MacTextLine(api, "Aمرحبا仓", [path], path, 24.0, false)
        let empty = MacTextLine(api, "", [path], path, 24.0, false)
        try {
            @Expect(regular.primaryFont, "HarmonyOS_Sans_SC")
            @Expect(bold.primaryFont, "HarmonyOS_Sans_SC_Bold")
            @Expect(emoji.glyphCount(), Int64(1))
            @Expect(emoji.metrics.width > 10.0 && emoji.metrics.width < 60.0)
            @Expect(regular.hitUtf16(regular.caretUtf16(2)[0]), Int64(2))
            @Expect(mixed.caretUtf16(2)[0] > mixed.caretUtf16(5)[0])
            @Expect(empty.hitUtf16(0.0), Int64(-1))
            @Expect(empty.metrics.width, Float32(0.0))
            @Expect(empty.metrics.height > 0.0)
            let pixels = emoji.raster(NativeTextColor(255, 255, 255, 255))
            var colored: Int64 = 0
            for (i in 0..(pixels.pixels.size / 4)) {
                let p = i * 4
                if (pixels.pixels[p + 3] > 128 &&
                    (pixels.pixels[p] != pixels.pixels[p + 1] || pixels.pixels[p + 1] != pixels.pixels[p + 2])) {
                    colored++
                }
            }
            @Expect(colored > 30)
        } finally {
            empty.close(); mixed.close(); emoji.close(); bold.close(); regular.close()
        }
        // Closing lines twice is safe; reusing a closed line is rejected.
        regular.close()
        var rejected = false
        try { regular.hitUtf16(0.0) } catch (_: NativeTextException) { rejected = true }
        @Expect(rejected)
    } finally { api.close(); api.close() }
}

@When[os == "macOS"]
@Test
func coreTextRasterUsesRequestedColorAndRetainsEmbeddedNul(): Unit {
    let api = MacTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    try {
        let line = MacTextLine(api, "A\u{0}B", ["/missing/font.ttf", path], path, 24.0, false)
        let plain = MacTextLine(api, "AB", [path], path, 24.0, false)
        try {
            @Expect(line.glyphCount(), plain.glyphCount())
            @Expect(line.metrics.width, plain.metrics.width)
            @Expect(line.sourcePath, path)
            @Expect(line.hitUtf16(line.metrics.width), Int64(3))
            let image = line.raster(NativeTextColor(220, 40, 60, 128))
            var ink: Int64 = 0
            var maxAlpha: UInt8 = 0
            for (i in 0..(image.pixels.size / 4)) {
                let p = i * 4
                let a = image.pixels[p + 3]
                maxAlpha = max(maxAlpha, a)
                if (a > 100) {
                    ink++
                    @Expect(image.pixels[p] > 200)
                    @Expect(image.pixels[p + 1] < 65)
                }
            }
            @Expect(ink > 30)
            @Expect(maxAlpha <= 129)
        } finally { plain.close(); line.close() }
    } finally { api.close() }
}

@When[os == "macOS"]
@Test
func coreTextWhitespaceAndRasterLimitsAreExplicit(): Unit {
    let api = MacTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    try {
        let spaces = MacTextLine(api, "   ", [path], path, 24.0, false)
        let oversized = MacTextLine(api, String(Array<Rune>(2000, {_ => r'M'})), [path], path, 24.0, false)
        try {
            @Expect(spaces.metrics.width > 0.0)
            let blank = spaces.raster(NativeTextColor(255, 255, 255, 255))
            var alpha: Int64 = 0
            for (i in 0..(blank.pixels.size / 4)) { alpha += Int64(blank.pixels[i * 4 + 3]) }
            @Expect(alpha, Int64(0))
            var rejected = false
            try { oversized.raster(NativeTextColor(255, 255, 255, 255)) }
            catch (_: NativeTextException) { rejected = true }
            @Expect(rejected)
            @Expect(oversized.metrics.width > 16384.0)
        } finally { oversized.close(); spaces.close() }
        var badSize = false
        try { api.fontFromFile(path, 0.0, false) }
        catch (_: NativeTextException) { badSize = true }
        @Expect(badSize)
    } finally { api.close() }
}

@When[os == "macOS"]
@Test
func coreTextLogicalSelectionCanHaveDisjointVisualSpans(): Unit {
    let api = MacTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    try {
        let line = MacTextLine(api, "abc אבג def", [path], path, 24.0, false)
        try {
            let spans = line.selectionUtf16(3, 5)
            @Expect(spans.size, Int64(2))
            @Expect(abs(spans[0][0] - line.caretUtf16(3)[0]) < 0.01)
            @Expect(abs(spans[0][1] - line.caretUtf16(4)[0]) < 0.01)
            @Expect(abs(spans[1][0] - line.caretUtf16(5)[0]) < 0.01)
            @Expect(abs(spans[1][1] - line.caretUtf16(4)[1]) < 0.01)
            @Expect(spans[1][0] > spans[0][1])
            @Expect(line.selectionUtf16(5, 5).isEmpty())
            let all = line.selectionUtf16(-100, 100)
            var width: Float32 = 0.0
            for ((left, right) in all) { width += right - left }
            @Expect(abs(width - line.metrics.width) < 0.01)
        } finally { line.close() }
    } finally { api.close() }
}
