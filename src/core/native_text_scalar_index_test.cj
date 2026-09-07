package chui.core

@Test
func nativeScalarOffsetsRetainCombiningZwjCrLfAndSupplementaryBoundaries(): Unit {
    let text = "A仓😀e\u{301}👩\u{200D}👧\r\n🇨🇳"
    let bytes: Array<Int64> = [0, 1, 4, 8, 9, 11, 15, 18, 22, 23, 24, 28, 32]
    let utf16: Array<Int64> = [0, 1, 2, 4, 5, 6, 8, 9, 11, 12, 13, 15, 17]
    let scalar = NativeTextScalarIndex(text)
    for (i in 0..bytes.size) {
        @Expect(scalar.utf16OffsetForByte(bytes[i]), Some(utf16[i]))
        @Expect(scalar.byteOffsetForUtf16(utf16[i]), Some(bytes[i]))
    }
    let editor = NativeTextIndex(text)
    @Expect(editor.utf16OffsetForByte(9), Int64(4)) // e + accent stays one caret unit.
    @Expect(scalar.utf16OffsetForByte(9), Some(Int64(5))) // But a paint range may split it.
    @Expect(editor.utf16OffsetForByte(18), Int64(6))
    @Expect(scalar.utf16OffsetForByte(18), Some(Int64(9)))
    @Expect(editor.utf16OffsetForByte(23), Int64(11)) // CRLF is one grapheme.
    @Expect(scalar.utf16OffsetForByte(23), Some(Int64(12)))
}

@Test
func nativeScalarOffsetsRejectEveryInteriorAndDoNotClamp(): Unit {
    let scalar = NativeTextScalarIndex("A仓😀")
    for (byte in [Int64.Min, Int64(-1), 2, 3, 5, 6, 7, 9, Int64.Max]) {
        @Expect(scalar.utf16OffsetForByte(byte).isNone())
    }
    for (native in [Int64.Min, Int64(-1), 3, 5, Int64.Max]) {
        @Expect(scalar.byteOffsetForUtf16(native).isNone())
    }
    @Expect(scalar.utf16OffsetForByte(8), Some(Int64(4)))
    @Expect(scalar.byteOffsetForUtf16(4), Some(Int64(8)))
}

@Test
func nativeScalarOffsetsPreserveEmptyAndNulBoundaries(): Unit {
    let empty = NativeTextScalarIndex("")
    @Expect(empty.utf16OffsetForByte(0), Some(Int64(0)))
    @Expect(empty.byteOffsetForUtf16(0), Some(Int64(0)))
    @Expect(empty.utf16OffsetForByte(1).isNone())
    @Expect(empty.byteOffsetForUtf16(-1).isNone())
    let nul = NativeTextScalarIndex("A\u{0}😀")
    @Expect(nul.utf16OffsetForByte(2), Some(Int64(2)))
    @Expect(nul.utf16OffsetForByte(6), Some(Int64(4)))
}

@Test
func nativeScalarOffsetsHandleOneLongCombiningClusterWithoutRounding(): Unit {
    let text = "e" + String(Array<Rune>(24000, {_ => r'\u{301}'}))
    let scalar = NativeTextScalarIndex(text)
    @Expect(GraphemeIndex(text).count, Int64(1))
    for (i in 0..24001) {
        @Expect(scalar.utf16OffsetForByte(1 + i * 2), Some(1 + i))
        @Expect(scalar.byteOffsetForUtf16(1 + i), Some(1 + i * 2))
    }
}

@Test
func nativeScalarOffsetsRespectAllUtfEncodingWidthTransitions(): Unit {
    let text = "\u{0}\u{7F}\u{80}\u{7FF}\u{800}\u{D7FF}\u{E000}\u{FFFF}\u{10000}\u{10FFFF}"
    let bytes: Array<Int64> = [0, 1, 2, 4, 6, 9, 12, 15, 18, 22, 26]
    let utf16: Array<Int64> = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12]
    let scalar = NativeTextScalarIndex(text)
    for (i in 0..bytes.size) {
        @Expect(scalar.utf16OffsetForByte(bytes[i]), Some(utf16[i]))
        @Expect(scalar.byteOffsetForUtf16(utf16[i]), Some(bytes[i]))
    }
}
