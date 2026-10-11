package chui.text

import chui.core.{GraphemeIndex, State, Theme, UiContext}
import sdl.{Key, Rect, Renderer, UiEvent}

@Test
func textAreaSoftWrapProjectsMixedRowsWithoutChangingBoundText(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let source = "abc你😀defghijkl\n中文，标点"
    let value = State<String>(source)
    let area = TextArea(value, key: "soft-wrap-contract", wrapMode: TextAreaWrapMode.SoftWrap)
    let rows = area.visualLines(ctx, 34.0)
    @Expect(rows.size > 2)
    @Expect(rows[0].logicalLine, Int64(0))
    @Expect(rows[rows.size - 1].logicalLine, Int64(1))
    @Expect(rows[0].startByte, Int64(0))
    @Expect(rows[rows.size - 1].endByte, source.size)
    @Expect(value.value, source)
}

@Test
func textAreaSoftWrapMapsSecondVisualRowToOriginalByteRange(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("abcdefghijklmno")
    let area = TextArea(value, key: "soft-wrap-hit", wrapMode: TextAreaWrapMode.SoftWrap)
    let rows = area.visualLines(ctx, 30.0)
    @Expect(rows.size >= 2)
    let second = rows[1]
    let offset = area.visualOffsetForPoint(ctx, 1, 1.0, 30.0)
    @Expect(offset >= second.startByte && offset <= second.endByte)
    @Expect(area.visualLineForOffset(ctx, second.startByte, 30.0), Int64(1))
}

@Test
func textAreaSoftWrapDrawAndVerticalNavigationKeepCaretInVisualRows(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let cursor = State<Int64>(0)
    let anchor = State<Int64>(0)
    let value = State<String>("abcdefghijklmno")
    let area = TextArea(value, key: "soft-wrap-navigation", cursor: Some(cursor), anchor: Some(anchor),
        wrapMode: TextAreaWrapMode.SoftWrap)
    area.layout(ctx, Rect(0.0, 0.0, 80.0, 72.0))
    ctx.focus("soft-wrap-navigation")
    area.draw(ctx)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(cursor.value > 0)
    @Expect(value.value, "abcdefghijklmno")
    @Expect(anchor.value, cursor.value)
}

@Test
func textAreaSoftWrapKeepsClustersAndModeSwitchSelection(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let source = "e\u{301}👩\u{200D}💻🇨🇳中文\n尾行"
    let value = State<String>(source)
    let cursor = State<Int64>(source.size)
    let anchor = State<Int64>(0)
    let area = TextArea(value, key: "soft-wrap-clusters", cursor: Some(cursor), anchor: Some(anchor))
    area.wrapMode(TextAreaWrapMode.SoftWrap)
    let boundaries = GraphemeIndex(source)
    for (row in area.visualLines(ctx, 1.0)) {
        @Expect(boundaries.floor(row.startByte), row.startByte)
        @Expect(boundaries.floor(row.endByte), row.endByte)
    }
    area.wrapMode(TextAreaWrapMode.NoWrap)
    area.wrapMode(TextAreaWrapMode.SoftWrap)
    @Expect(value.value, source)
    @Expect(cursor.value, source.size)
    @Expect(anchor.value, Int64(0))
}
