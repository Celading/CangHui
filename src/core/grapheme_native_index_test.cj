package chui.core

@Test
func nativeTextOffsetsRoundTripOnlyWholeGraphemes(): Unit {
    // UTF-8 byte boundaries: A, 仓, 😀, e+accent, family ZWJ, CRLF, flag, Z.
    let text = "A仓😀e\u{301}👩‍👩‍👧‍👦\r\n🇨🇳Z"
    let bytes: Array<Int64> = [0, 1, 4, 8, 11, 36, 38, 46, 47]
    let utf16: Array<Int64> = [0, 1, 2, 4, 6, 17, 19, 23, 24]
    let index = NativeTextIndex(text)
    @Expect(index.graphemes.count, Int64(8))
    for (i in 0..bytes.size) {
        @Expect(index.graphemes.boundary(i), bytes[i])
        @Expect(index.utf16OffsetForByte(bytes[i]), utf16[i])
        @Expect(index.byteOffsetForUtf16(utf16[i]), bytes[i])
        @Expect(index.utf16OffsetForByte(bytes[i], forward: true), utf16[i])
        @Expect(index.byteOffsetForUtf16(utf16[i], forward: true), bytes[i])
    }
    for (i in 0..(bytes.size - 1)) {
        for (p in (bytes[i] + 1)..bytes[i + 1]) {
            @Expect(index.utf16OffsetForByte(p), utf16[i])
            @Expect(index.utf16OffsetForByte(p, forward: true), utf16[i + 1])
        }
        for (p in (utf16[i] + 1)..utf16[i + 1]) {
            @Expect(index.byteOffsetForUtf16(p), bytes[i])
            @Expect(index.byteOffsetForUtf16(p, forward: true), bytes[i + 1])
        }
    }
}

@Test
func nativeTextOffsetsClampMissingAndOutOfRangePositions(): Unit {
    for (text in ["", "😀", "e\u{301}", "\r\n", "क्\u{200D}ष"]) {
        let index = NativeTextIndex(text)
        for (forward in [false, true]) {
            @Expect(index.byteOffsetForUtf16(-1, forward: forward), Int64(0))
            @Expect(index.utf16OffsetForByte(-1, forward: forward), Int64(0))
            @Expect(index.byteOffsetForUtf16(Int64.Max, forward: forward), text.size)
            @Expect(index.byteOffsetForUtf16(index.utf16OffsetForByte(Int64.Max,
                forward: forward)), text.size)
        }
    }
}

@Test
func nativeTextOffsetsPreserveLogicalOrderForBidirectionalContent(): Unit {
    // This maps storage offsets only, not visual left/right or primary/secondary carets.
    let text = "Aمرحبا仓"
    let index = NativeTextIndex(text)
    let bytes: Array<Int64> = [0, 1, 3, 5, 7, 9, 11, 14]
    for (i in 0..bytes.size) {
        @Expect(index.byteOffsetForUtf16(i), bytes[i])
        @Expect(index.utf16OffsetForByte(bytes[i]), i)
    }
}

@Test
func nativeTextOffsetsHandleLongMixedLines(): Unit {
    let text = String(Array<Rune>(24000, {i =>
        if (i % 3 == 0) { r'A' } else if (i % 3 == 1) { r'仓' } else { r'😀' }
    }))
    let index = NativeTextIndex(text)
    @Expect(index.graphemes.count, Int64(24000))
    for (i in 0..8000) {
        @Expect(index.byteOffsetForUtf16(i * 4), i * 8)
        @Expect(index.utf16OffsetForByte(i * 8), i * 4)
    }
}
