package chui.core

@Test
func wrapTextExplicitBreaksNeverReachOneRendererLine(): Unit {
    let ctx = testContext()
    let lines = wrapText(ctx, "alpha\nbeta\r\n\rgamma\n", 1000.0, 15.0, Int64.Max)
    @Expect(lines.size, 5)
    @Expect(lines[0], "alpha")
    @Expect(lines[1], "beta")
    @Expect(lines[2], "")
    @Expect(lines[3], "gamma")
    @Expect(lines[4], "")
    for (line in lines) { @Expect(!line.contains("\n") && !line.contains("\r")) }
}

@Test
func wrapTextParagraphLimitShowsOmittedContentAndPreservesGraphemes(): Unit {
    let ctx = testContext()
    let limited = wrapText(ctx, "alpha\nbeta\ngamma", 1000.0, 15.0, 2)
    @Expect(limited.size, 2)
    @Expect(limited[0], "alpha")
    @Expect(limited[1], "beta…")
    let narrow = wrapText(ctx, "alpha beta gamma\nmore", 80.0, 15.0, 1)
    @Expect(narrow.size, 1)
    @Expect(narrow[0].endsWith("…"))
    @Expect(!narrow[0].endsWith("……"))
    let wrapped = wrapText(ctx, "ééé\nééé", 20.0, 15.0, Int64.Max)
    let combined = StringBuilder()
    for (line in wrapped) {
        @Expect(!line.contains("\n"))
        combined.append(line)
    }
    @Expect(combined.toString(), "éééééé")
}

/*
 * maxRunesFitting 的 gallop 定界与旧的全范围二分同属一个单调谓词上的最大 k 求解，
 * 结果必须逐值一致；参照度量函数取「宽度=字符数」，让每个断言精确到边界。
 */

@Test
func maxRunesFittingGallopMatchesReference(): Unit {
    let runes = Array<Rune>(5000, repeat: r'字')
    let measure = {s: String => Float32(s.toRuneArray().size)}
    // 横跨 gallop 种子（32）、各级探针（128/512）与阈值（512）的目标值，逐一验证最大性。
    for (want in [1, 31, 32, 33, 127, 128, 129, 511, 512, 513, 2048, 4999]) {
        @Expect(maxRunesFitting(runes, 0, Float32(want), measure), want)
    }
    // 整段可容纳、以及一个字符都放不下。
    @Expect(maxRunesFitting(runes, 0, 5000.0, measure), 5000)
    @Expect(maxRunesFitting(runes, 0, 0.5, measure), 0)
    // start 偏移后按剩余长度走短路径。
    @Expect(maxRunesFitting(runes, 4990, 100.0, measure), 10)
}

@Test
func wrapTextLongDocumentReconstructs(): Unit {
    let ctx = testContext()
    let builder = StringBuilder()
    for (_ in 0..2000) {
        builder.append(r'资')
    }
    let text = builder.toString()
    let lines = wrapText(ctx, text, 300.0, 15.0, Int64.Max)
    // 无空格 CJK 文本走逐字符断行：多行、不丢字、每行都在宽度内。
    @Expect(lines.size > 1)
    let joined = StringBuilder()
    for (line in lines) {
        joined.append(line)
        @Expect(ctx.renderer.textWidth(line, pointSize: 15.0) <= 300.0)
    }
    @Expect(joined.toString(), text)
}
