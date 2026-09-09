package sdl

import std.env.getVariable
import sdl.text.{NativeTextLineSpec, NativeTextColorSpan, NativeTextException}

@When[os == "macOS"]
private func directionTestFont(): ?String { Some(bundledFontFixture()) }

@When[os == "Linux"]
private func directionTestFont(): ?String {
    if (getVariable("CANGHUI_TEST_PANGO") == Some("1")) {
        Some("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    } else { None }
}

@When[os != "macOS" && os != "Linux"]
private func directionTestFont(): ?String { None }

@Test
func nativeTextDirectionsRequireTheSelectedNativeBackend(): Unit {
    let r = Renderer.headless()
    @Expect(r.textRightToLeftUtf16("א", [Int64(0)]).isNone())
    @Expect(r.textRightToLeftUtf16(NativeTextLineSpec("א"), [Int64(0)]).isNone())
}

@Test
func nativeTextDirectionsKeepBidiNumbersAndSingleRtlCharacters(): Unit {
    let path = match (directionTestFont()) { case Some(value) => value; case None => return }
    Fonts.clear(); Fonts.registerBundledFallback(path)
    let window = SdlWindow(WindowSpec("Direction query", 400, 160, supersample: 1))
    try {
        let r = window.renderer
        @Expect(r.textRightToLeftUtf16("AאB", [Int64(0), 1, 2]).isNone())
        @Expect(r.usePlatformTextLayout(true))
        for ((text, indices, expected) in [
            ("AאB", [Int64(0), 1, 2], [false, true, false]),
            ("Aא12בB", [Int64(0), 1, 2, 3, 4, 5], [false, true, false, false, true, false]),
            // Leading neutral emoji follows the first strong RTL character.
            ("😀אe\u{301}", [Int64(0), 2, 3, 4], [true, true, false, false]),
            ("اَل", [Int64(0), 1, 2], [true, true, true]),
            ("AאB", [Int64(2), 1, 0, 1], [false, true, false, true])
        ]) {
            let values = r.textRightToLeftUtf16(text, indices).getOrThrow()
            @Expect(values.size, expected.size)
            for (i in 0..values.size) { @Expect(values[i], expected[i]) }
        }
        @Expect(r.textRightToLeftUtf16("", Array<Int64>()).getOrThrow().isEmpty())
        @Expect(r.textRightToLeftUtf16("abc", Array<Int64>()).getOrThrow().isEmpty())
        let alternating = String(Array<Rune>(2048, {i => if (i % 2 == 0) { r'A' } else { r'א' } }))
        let alternatingIndices = Array<Int64>(2048, {i => i})
        let alternatingDirections = r.textRightToLeftUtf16(alternating, alternatingIndices).getOrThrow()
        for (i in 0..2048) { @Expect(alternatingDirections[i], i % 2 == 1) }
        for ((text, indices) in [
            ("", [Int64(0)]), ("😀א", [Int64(0), 1]),
            ("😀א", [Int64(3)]), ("A", [Int64(-1)]), ("A", [Int64.Max])
        ]) {
            var rejected = false
            try { r.textRightToLeftUtf16(text, indices) }
            catch (_: NativeTextException) { rejected = true }
            @Expect(rejected)
        }
        let decorated = FontStyle(underline: true)
        @Expect(r.textRightToLeftUtf16("AאB", [Int64(1)], style: decorated).isNone())
        @Expect(r.usePlatformTextLayout(false))
        @Expect(r.textRightToLeftUtf16("AאB", [Int64(1)]).isNone())
        println("NATIVE_DIRECTION scalar/bidi/neutral/invalid/backend executed")
    } finally { window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride() }
}

@Test
func nativeTextDirectionsSharePlainAndColoredLayoutIdentityAtFractionalScale(): Unit {
    let path = match (directionTestFont()) { case Some(value) => value; case None => return }
    Fonts.clear(); Fonts.registerBundledFallback(path)
    let window = SdlWindow(WindowSpec("Direction layout identity", 400, 160, supersample: 1))
    try {
        let r = window.renderer
        @Expect(r.usePlatformTextLayout(true))
        let text = "Aא12בB"
        let indices = [Int64(0), 1, 2, 3, 4, 5]
        let spec = NativeTextLineSpec(text, colors: [NativeTextColorSpan(1, 5, 230, 40, 50, 255)])
        let expected = [false, true, false, false, true, false]
        let scales: Array<Float32> = [1.0, 1.25, 1.9, 2.0]
        for (scale in scales) {
            r.setScale(scale)
            let _ = r.textWidth(text, pointSize: 24.0)
            let _ = r.textSize(spec, pointSize: 24.0).getOrThrow()
            let shaped = r.textShapeCount()
            let plain = r.textRightToLeftUtf16(text, indices, pointSize: 24.0).getOrThrow()
            let colored = r.textRightToLeftUtf16(spec, indices, pointSize: 24.0).getOrThrow()
            let _ = r.textCaretPositionsUtf16(spec, indices, pointSize: 24.0).getOrThrow()
            for (i in 0..expected.size) {
                @Expect(plain[i], expected[i]); @Expect(colored[i], expected[i])
            }
            @Expect(r.textShapeCount(), shaped)
        }
        @Expect(r.textRightToLeftUtf16(spec, indices, style: FontStyle(underline: true)).isNone())
        println("NATIVE_DIRECTION paint/fractional-scale/cache executed")
    } finally { window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride() }
}
