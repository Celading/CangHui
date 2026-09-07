package chui.core

@Test
func plainTextFitNeverCutsInsideGraphemes(): Unit {
    let ctx = testContext()
    @Expect(ellipsize(ctx, "e\u{301}XYZ", 33.0, 15.0), "…")
    let lines = wrapText(ctx, "e\u{301}x", 10.0, 15.0, 10)
    @Expect(lines.size, Int64(2))
    @Expect(lines[0], "e\u{301}")
    @Expect(lines[1], "x")
}

@Test
func graphemeIndexClampsPositionsAndRejectsFalseJoins(): Unit {
    let empty = GraphemeIndex("")
    @Expect(empty.count, Int64(0))
    @Expect(empty.next(100), Int64(0))
    let index = GraphemeIndex("e\u{301}🇨🇳x")
    @Expect(index.count, Int64(3))
    @Expect(index.floor(-1), Int64(0))
    @Expect(index.ceil(1), Int64(3))
    @Expect(index.floor(7), Int64(3))
    @Expect(index.previous(11), Int64(3))
    @Expect(index.next(3), Int64(11))
    @Expect(index.ceil(100), Int64(12))
    for (text in ["aᅡ", "a\u{200D}b", "क्b", "\u{0}\u{301}"]) {
        @Expect(GraphemeIndex(text).count, Int64(2))
    }
}

@Test
func graphemeLongParagraphWrapPreservesEveryCluster(): Unit {
    let builder = StringBuilder()
    for (_ in 0..20000) { builder.append("e\u{301}") }
    let lines = wrapText(testContext(), builder.toString(), 99.0, 15.0, 6000)
    // Headless width is 8.25 per byte: exactly four three-byte clusters per line.
    @Expect(lines.size, Int64(5000))
    for (line in lines) { @Expect(line, "e\u{301}e\u{301}e\u{301}e\u{301}") }
}
