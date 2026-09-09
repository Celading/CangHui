package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, Rect, Renderer, UiEvent}

private func documentNavigationKey(ctx: UiContext, area: TextArea, key: Key, mask: UInt16): Bool {
    ctx.withEventModifiers(Some(mask), {=> area.handle(ctx, UiEvent.KeyDown(key, false)) })
}

@Test
func textAreaControlHomeEndMoveAcrossWholeDocumentWithoutEditing(): Unit {
    for (editable in [true, false]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let text = State<String>("a你\r\né\n尾")
        let caret = State<Int64>(6)
        let anchor = State<Int64>(6)
        let area = TextArea(text, key: "area", editable: editable,
            cursor: Some(caret), anchor: Some(anchor))
        area.layout(ctx, Rect(0.0, 0.0, 320.0, 120.0)); ctx.focus("area")
        @Expect(documentNavigationKey(ctx, area, Key.End, UInt16(0x0040)))
        @Expect(caret.value, text.value.size)
        @Expect(anchor.value, text.value.size)
        @Expect(documentNavigationKey(ctx, area, Key.Home, UInt16(0x0080)))
        @Expect(caret.value, Int64(0))
        @Expect(anchor.value, Int64(0))
        @Expect(text.value, "a你\r\né\n尾")
    }
}

@Test
func textAreaControlShiftHomeEndKeepDirectionalSelectionAnchor(): Unit {
    for (editable in [true, false]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let text = State<String>("a你\r\né\n尾")
        let caret = State<Int64>(6)
        let anchor = State<Int64>(6)
        let area = TextArea(text, key: "area", editable: editable,
            cursor: Some(caret), anchor: Some(anchor))
        area.layout(ctx, Rect(0.0, 0.0, 320.0, 120.0)); ctx.focus("area")
        @Expect(documentNavigationKey(ctx, area, Key.Home, UInt16(0x0041)))
        @Expect(caret.value, Int64(0))
        @Expect(anchor.value, Int64(6))
        @Expect(documentNavigationKey(ctx, area, Key.End, UInt16(0x0082)))
        @Expect(caret.value, text.value.size)
        @Expect(anchor.value, Int64(6))
        @Expect(documentNavigationKey(ctx, area, Key.Home, UInt16(0x0040)))
        @Expect(caret.value, Int64(0))
        @Expect(anchor.value, Int64(0))
        @Expect(text.value, "a你\r\né\n尾")
    }
}

@Test
func textAreaPlainHomeEndRetainLineSemanticsAndShiftSelection(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let caret = State<Int64>(6)
    let anchor = State<Int64>(6)
    let area = TextArea(State<String>("a你\r\né\n尾"), key: "area", editable: false,
        cursor: Some(caret), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 120.0)); ctx.focus("area")
    @Expect(documentNavigationKey(ctx, area, Key.End, UInt16(0)))
    @Expect(caret.value, Int64(9))
    @Expect(anchor.value, Int64(9))
    @Expect(documentNavigationKey(ctx, area, Key.Home, UInt16(1)))
    @Expect(caret.value, Int64(6))
    @Expect(anchor.value, Int64(9))
    @Expect(documentNavigationKey(ctx, area, Key.Home, UInt16(0)))
    @Expect(anchor.value, Int64(6))
}

@Test
func textAreaDocumentNavigationKeepsEmptyDocumentStable(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let caret = State<Int64>(0)
    let anchor = State<Int64>(0)
    let area = TextArea(State<String>(""), key: "area", editable: false,
        cursor: Some(caret), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 120.0)); ctx.focus("area")
    for (key in [Key.Home, Key.End]) {
        for (mask in [UInt16(0x0040), UInt16(0x0082)]) {
            @Expect(documentNavigationKey(ctx, area, key, mask))
            @Expect(caret.value, Int64(0))
            @Expect(anchor.value, Int64(0))
        }
    }
}

@Test
func textAreaDocumentNavigationCannotMoveAnUnfocusedEditor(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let caret = State<Int64>(2)
    let anchor = State<Int64>(2)
    let area = TextArea(State<String>("a\nb\nc"), key: "area",
        cursor: Some(caret), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 120.0)); ctx.focus("other")
    for (key in [Key.Home, Key.End]) {
        @Expect(!documentNavigationKey(ctx, area, key, UInt16(0x0041)))
        @Expect(caret.value, Int64(2))
        @Expect(anchor.value, Int64(2))
    }
}
