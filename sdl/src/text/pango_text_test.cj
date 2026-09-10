package sdl.text

import std.env.getVariable
import std.fs.File
import std.math.abs

@When[os == "Linux"]
private func pangoNativeTests(): Bool { getVariable("CANGHUI_TEST_PANGO") == Some("1") }

@When[os == "Linux"]
@Test
func pangoOffsetsConvertScalarsWithoutInventingGraphemeBoundaries(): Unit {
    let map = PangoTextOffsets("A😀e\u{301}👨‍👩‍👧‍👦")
    @Expect(map.byteIndex(3), Int32(5))
    @Expect(map.utf16Index(1, 1), Int64(3))
    @Expect(map.utf16Index(5, 2), Int64(5))
    @Expect(map.utf16Index(8, 7), Int64(16))
    for (bad in [Int64(-1), Int64(2), Int64(99)]) {
        var rejected = false
        try { map.byteIndex(bad) } catch (_: NativeTextException) { rejected = true }
        @Expect(rejected)
    }
    var rejected = false
    try { PangoTextOffsets("A\u{0}B") } catch (_: NativeTextException) { rejected = true }
    @Expect(rejected)
}

@When[os == "Linux"]
@Test
func pangoPrivateFilesPreserveOrderAndVariableBold(): Unit {
    if (!pangoNativeTests()) { return }
    let api = PangoTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    let copy = "target/pango&<copy>.ttf"
    File.writeTo(copy, File.readFrom(path))
    try {
        let first = PangoTextLine(api, "仓绘 A", [path, copy], path, 24.0, false)
        let second = PangoTextLine(api, "仓绘 A", [copy, path], path, 24.0, false)
        let bold = PangoTextLine(api, "仓绘 A", [copy, path], path, 24.0, true)
        try {
            @Expect(first.sourcePath, path); @Expect(second.sourcePath, copy)
            @Expect(bold.sourcePath, copy); @Expect(bold.variations.contains("wght=700"))
            @Expect(first.metrics.width, second.metrics.width)
            @Expect(first.unknownGlyphCount(), Int32(0))
        } finally { bold.close(); second.close(); first.close() }
        println("PANGO_NATIVE font-order/bold pass")
    } finally { api.close() }
}

@When[os == "Linux"]
@Test
func pangoLineKeepsBidiAndScaleGeometryTogether(): Unit {
    if (!pangoNativeTests()) { return }
    let api = PangoTextApi()
    let path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    try {
        let line = PangoTextLine(api, "abc אבג def", [path], path, 24.0, false)
        let large = PangoTextLine(api, "abc אבג def", [path], path, 48.0, false)
        try {
            @Expect(line.unknownGlyphCount(), Int32(0))
            @Expect(line.caretUtf16(4)[0] != line.caretUtf16(4)[1])
            @Expect(abs(large.metrics.width / 2.0 - line.metrics.width) < 0.05)
            @Expect(abs(large.caretUtf16(5)[0] / 2.0 - line.caretUtf16(5)[0]) < 0.05)
            @Expect(line.hitUtf16(line.caretUtf16(1)[0]), Int64(1))
            let spans = line.selectionUtf16(0, 5)
            @Expect(spans.size >= 2)
            @Expect(spans[spans.size - 1][0] > spans[0][1])
        } finally { large.close(); line.close() }
        println("PANGO_NATIVE bidi/scale pass")
    } finally { api.close() }
}

@When[os == "Linux"]
@Test
func pangoRasterConvertsAlphaAndUsesImmutablePaint(): Unit {
    if (!pangoNativeTests()) { return }
    let api = PangoTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    try {
        let line = PangoTextLine(api, "仓绘 AA", [path], path, 32.0, false)
        let spec = NativeTextLineSpec("仓绘 AA", colors: [NativeTextColorSpan(0, 2, 220, 30, 40, 255)],
            red: 20, green: 210, blue: 30, alpha: 128)
        let painted = PangoTextLine(api, spec.text, [path], path, 32.0, false, paint: Some(spec))
        try {
            let image = line.raster(NativeTextColor(220, 40, 60, 128))
            var ink: Int64 = 0
            for (i in 0..(image.pixels.size / 4)) {
                let p = i * 4; let alpha = image.pixels[p + 3]
                @Expect(alpha <= 129)
                if (alpha > 100) { ink++; @Expect(image.pixels[p] > 200); @Expect(image.pixels[p + 1] < 65) }
            }
            @Expect(ink > 30)
            let colored = painted.raster(NativeTextColor(0, 0, 0, 255))
            var red: Int64 = 0; var green: Int64 = 0
            for (i in 0..(colored.pixels.size / 4)) {
                let p = i * 4
                if (colored.pixels[p + 3] > 100) {
                    if (colored.pixels[p] > 200 && colored.pixels[p + 1] < 65) { red++ }
                    if (colored.pixels[p + 1] > 190 && colored.pixels[p] < 65) { green++ }
                }
            }
            @Expect(red > 30 && green > 30)
        } finally { painted.close(); line.close() }
        println("PANGO_NATIVE raster/paint pass")
    } finally { api.close() }
}

@When[os == "Linux"]
@Test
func pangoEmptyLimitsAndFontMapEvictionKeepOwnership(): Unit {
    if (!pangoNativeTests()) { return }
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    for (_ in 0..3) {
        let api = PangoTextApi()
        try {
            let held = PangoTextLine(api, "仓绘", [path], path, 24.0, false)
            let empty = PangoTextLine(api, "", [path], path, 24.0, false)
            try {
                @Expect(empty.hitUtf16(0.0), Int64(-1)); @Expect(empty.metrics.width, Float32(0.0))
                @Expect(empty.metrics.height > 0.0)
                for (i in 0..24) {
                    let next = PangoTextLine(api, "test", ["/missing/${i}.ttf", path], path, 24.0, false)
                    next.close()
                }
                @Expect(held.unknownGlyphCount(), Int32(0))
                @Expect(held.raster(NativeTextColor(255, 255, 255, 255)).pixels.size > 0)
            } finally { empty.close(); held.close(); held.close() }
            let oversized = PangoTextLine(api, String(Array<Rune>(2000, {_ => r'M'})), [path], path, 24.0, false)
            var rejected = false
            try { oversized.raster(NativeTextColor(255, 255, 255, 255)) }
            catch (_: NativeTextException) { rejected = true }
            finally { oversized.close() }
            @Expect(rejected)
        } finally { api.close(); api.close() }
    }
    println("PANGO_NATIVE lifecycle/limits pass")
}
