package sdl.text

@Test
func nativeLineSpecOwnsColorRangesAndValidatesUtf16Scalars(): Unit {
    let red = NativeTextColorSpan(0, 1, 240, 20, 30, 255)
    let blue = NativeTextColorSpan(1, 3, 20, 40, 240, 180)
    let input = [red, blue]
    let spec = NativeTextLineSpec("A😀é", colors: input)
    let key = spec.colorKey
    input[0] = blue
    let first = spec.colors()
    first[1] = red
    @Expect(spec.colors()[0].start, Int64(0))
    @Expect(spec.colors()[1].end, Int64(3))
    @Expect(spec.colorKey, key)
    // Surrogate interiors are rejected; combining-scalar boundaries remain legal.
    let accent = NativeTextLineSpec("A😀é", colors: [NativeTextColorSpan(4, 5, 0, 0, 0, 255)])
    @Expect(accent.colors()[0].start, Int64(4))
    for ((start, end) in [(Int64(-1), Int64(0)), (Int64(1), Int64(2)),
        (Int64(2), Int64(3)), (Int64(3), Int64(2)), (Int64(4), Int64(6)),
        (Int64(0), Int64(9223372036854775807))]) {
        var rejected = false
        try { NativeTextLineSpec("A😀é", colors: [NativeTextColorSpan(start, end, 0, 0, 0, 255)]) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
    @Expect(NativeTextLineSpec("", colors: [NativeTextColorSpan(0, 0, 0, 0, 0, 255)]).text, "")
}

@When[os == "macOS"]
@Test
func coreTextColoredLineUsesAttributesAndOriginalDefaultColor(): Unit {
    let api = MacTextApi()
    let path = "../assets/fonts/HarmonyOS_Sans_SC.ttf"
    let spec = NativeTextLineSpec("ABCD", colors: [NativeTextColorSpan(0, 3, 240, 20, 30, 255),
        NativeTextColorSpan(1, 2, 20, 230, 30, 255)], red: 20, green: 40, blue: 240)
    try {
        let line = MacTextLine(api, spec.text, [path], path, 32.0, false, paint: Some(spec))
        try {
            let raster = line.raster(NativeTextColor(0, 0, 0, 255))
            var red: Int64 = 0
            var green: Int64 = 0
            var blue: Int64 = 0
            for (i in 0..(raster.pixels.size / 4)) {
                let p = i * 4
                if (raster.pixels[p + 3] < 200) { continue }
                if (raster.pixels[p] > 180 && raster.pixels[p + 1] < 80) { red++ }
                if (raster.pixels[p + 1] > 180 && raster.pixels[p] < 80) { green++ }
                if (raster.pixels[p + 2] > 180 && raster.pixels[p] < 80) { blue++ }
            }
            @Expect(red > 40)
            @Expect(green > 30)
            @Expect(blue > 30)
            @Expect(line.hitUtf16(line.caretUtf16(2)[0]), Int64(2))
            let selected = line.selectionUtf16(1, 2)
            @Expect(selected.size, Int64(1))
            @Expect(selected[0][1] > selected[0][0])
        } finally { line.close() }
        var mismatch = false
        try { MacTextLine(api, "other", [path], path, 32.0, false, paint: Some(spec)) }
        catch (_: NativeTextException) { mismatch = true }
        @Expect(mismatch)
    } finally { api.close() }
}
