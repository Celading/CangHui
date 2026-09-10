package chui_editor

import chui.{ComponentProbe, Theme}

@Test
func seedDocumentHasTextAndStats(): Unit {
    let model = EditorModel()
    @Expect(!model.isEmpty())
    @Expect(model.lines.value > 0)
    @Expect(model.chars.value > 0)
}

@Test
func newAndClearEmptyTheDocument(): Unit {
    let model = EditorModel()
    model.newDoc()
    @Expect(model.isEmpty())
    @Expect(model.chars.value, 0)
    @Expect(model.lines.value, 0)
    @Expect(model.status.value, "新建文档")
}

@Test
func appendDateAddsALineWithoutLosingContent(): Unit {
    let model = EditorModel()
    let beforeLines = model.lines.value
    model.appendDate()
    // 追加一个新行，行数增长且文本包含 ISO 年份。
    @Expect(model.lines.value, beforeLines + 1)
    @Expect(model.text.value.contains("-")) // ISO 日期分隔符
    @Expect(model.status.value, "已追加")
}

@Test
func appendIntoEmptyDoesNotLeadWithNewline(): Unit {
    let model = EditorModel()
    model.clear()
    model.appendRule()
    // 向空文档追加时恰好得到该行，无前导空行。
    @Expect(model.lines.value, 1)
    @Expect(!model.text.value.startsWith("\n"))
}

@Test
func saveReportsCurrentStats(): Unit {
    let model = EditorModel()
    model.save()
    @Expect(model.status.value.contains("字"))
    @Expect(model.status.value.contains("行"))
}

@Test
func statsTrackEditsLive(): Unit {
    let model = EditorModel()
    model.text.value = "abc\n中文"
    // 字按 rune 计数且不含换行符：a、b、c、中、文 = 5。
    @Expect(model.chars.value, 5)
    @Expect(model.lines.value, 2)
}

@Test
func lineNumberGutterTracksLogicalRowsWithoutVisualWrapping(): Unit {
    @Expect(lineNumberText(""), "1")
    @Expect(lineNumberText("a\n中文\n\tcode"), "1\n2\n3")
}

@Test
func editorGraphemeFlowKeepsModelGutterAndDecorationsInSync(): Unit {
    for (width in [Float32(320.0), Float32(760.0), Float32(1280.0)]) {
        for (dark in [false, true]) {
            let model = EditorModel()
            model.text.value = "header\nxe\u{301}🇨🇳👩‍👩‍👧‍👦"
            let report = ComponentProbe("editor.grapheme-flow", width: width, height: 560.0,
                theme: if (dark) { Theme.dark() } else { Theme.light() }).run(
                "focus editor.body\nkey End\nkey Backspace\nkey Left\nkey Backspace\n" +
                "text z\u{301}\nkey Right\nkey Backspace\ndraw") {
                editorView(model)
            }
            @Expect(report.contains("\"ok\":true"))
            @Expect(!report.contains("\"ok\":false"))
            @Expect(model.text.value, "header\nxz\u{301}")
            @Expect(model.lines.value, Int64(2))
            @Expect(lineNumberText(model.text.value), "1\n2")
        }
    }
}
