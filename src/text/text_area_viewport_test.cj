package chui.text

import chui.core.{ScrollBarLayout, ScrollBarStyle, ScrollBarVisibility, ScrollOptions, State, Theme, UiContext}
import sdl.{MouseButton, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func textAreaViewportShrinkRevealsUnchangedCaretOnBothAxes(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("row\nrow\nrow\nrow\n012345678901234567890123456789")
    let cursor = State<Int64>(value.value.size)
    let anchor = State<Int64>(value.value.size)
    let vertical = State<Float32>(0.0)
    let horizontal = State<Float32>(0.0)
    let area = TextArea(value, key: "resize-caret", cursor: Some(cursor), anchor: Some(anchor),
        scroll: Some(vertical), horizontalScroll: Some(horizontal))
    ctx.focus("resize-caret")
    area.layout(ctx, Rect(0.0, 0.0, 420.0, 240.0))
    area.draw(ctx)
    @Expect(vertical.value, Float32(0.0))
    @Expect(horizontal.value, Float32(0.0))
    area.layout(ctx, Rect(20.0, 30.0, 100.0, 72.0))
    area.draw(ctx)
    @Expect(vertical.value, Float32(84.0))
    @Expect(horizontal.value > 100.0)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x >= 28.0 && caret.right() <= 112.0)
    @Expect(caret.y >= 38.0 && caret.bottom() <= 94.0)
    @Expect(cursor.value, value.value.size)
    @Expect(anchor.value, value.value.size)
}

@Test
func textAreaViewportStableOrMovedDoesNotUndoManualScroll(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("012345678901234567890123456789\na\nb\nc\nd\ne\nf\ng")
    let vertical = State<Float32>(0.0)
    let horizontal = State<Float32>(0.0)
    let area = TextArea(value, key: "resize-wheel", cursor: Some(State<Int64>(0)),
        anchor: Some(State<Int64>(0)), scroll: Some(vertical), horizontalScroll: Some(horizontal))
        .scrollOptions(ScrollOptions.immediate())
    ctx.focus("resize-wheel")
    area.layout(ctx, Rect(0.0, 0.0, 100.0, 72.0))
    area.draw(ctx)
    @Expect(area.handle(ctx, UiEvent.MouseWheel(1.0, 0.0, 20.0, 20.0)))
    @Expect(area.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    let y = vertical.value
    let x = horizontal.value
    @Expect(y > 0.0 && x > 0.0)
    for (_ in 0..3) {
        area.layout(ctx, Rect(40.0, 50.0, 100.0, 72.0))
        area.draw(ctx)
    }
    @Expect(vertical.value, y)
    @Expect(horizontal.value, x)
}

@Test
func textAreaViewportShrinkDoesNotRevealAnUnfocusedCaret(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("a\nb\nc\nd\n012345678901234567890123456789")
    let vertical = State<Float32>(0.0)
    let horizontal = State<Float32>(0.0)
    let area = TextArea(value, key: "resize-unfocused", scroll: Some(vertical),
        horizontalScroll: Some(horizontal))
    area.layout(ctx, Rect(0.0, 0.0, 420.0, 240.0))
    area.draw(ctx)
    area.layout(ctx, Rect(0.0, 0.0, 100.0, 72.0))
    area.draw(ctx)
    @Expect(vertical.value, Float32(0.0))
    @Expect(horizontal.value, Float32(0.0))
    ctx.focus("resize-unfocused")
    area.draw(ctx)
    @Expect(vertical.value > 0.0)
    @Expect(horizontal.value > 0.0)
}

@Test
func textAreaViewportShrinkFollowsPreeditWithoutMutatingDocument(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("aXb")
    let horizontal = State<Float32>(0.0)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(value, key: "resize-preedit", cursor: Some(State<Int64>(2)),
        anchor: Some(State<Int64>(1)), composition: Some(composition), horizontalScroll: Some(horizontal))
    ctx.focus("resize-preedit")
    area.layout(ctx, Rect(0.0, 0.0, 420.0, 112.0))
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "01234567890123456789", selectionStart: 20))))
    area.draw(ctx)
    let generation = composition.value.generation
    area.layout(ctx, Rect(0.0, 0.0, 80.0, 112.0))
    area.draw(ctx)
    @Expect(horizontal.value > 100.0)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x >= 8.0 && caret.right() <= 72.0)
    @Expect(value.value, "aXb")
    @Expect(composition.value.generation, generation)
}

@Test
func textAreaWideScrollbarsReserveTextGeometryAndAvoidTheSharedCorner(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let text = State<String>("0123456789012345678901234567890123456789\na\nb\nc\nd\ne\nf\ng\nh")
    let area = TextArea(text, key: "wide-scrollbars")
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(width: 24.0, margin: 2.0,
            layout: ScrollBarLayout.Reserved)))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    area.draw(ctx)
    var contentClip = false
    for (command in renderer.drawIr()) {
        if (command.kind == "clip.push" && command.toJson().contains("\"width\":166") &&
            command.toJson().contains("\"height\":66")) { contentClip = true }
    }
    @Expect(contentClip)
    // Clicking field padding may focus/select text; it must not become a bar drag/page target.
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 85.0)))
    @Expect(ctx.dragId, "wide-scrollbars")
}

@Test
func textAreaMetricsExposeActualEditorGutterGeometryAndRefreshAfterResize(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("0123456789012345678901234567890123456789\na\nb\nc\nd\ne\nf\ng\nh")
    let offset = State<Float32>(0.0)
    let area = TextArea(text, key: "editor-metrics", scroll: Some(offset))
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(width: 24.0, margin: 2.0,
            layout: ScrollBarLayout.Reserved)))
    @Expect(area.metrics().viewport.w, Float32(0.0))
    @Expect(area.metrics().contentHeight, Float32(0.0))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(area.metrics().viewport.x, Float32(8.0))
    @Expect(area.metrics().viewport.w, Float32(166.0))
    @Expect(area.metrics().viewport.h, Float32(66.0))
    @Expect(area.metrics().reservedRight, Float32(18.0))
    @Expect(area.metrics().contentHeight > area.metrics().viewport.h)
    offset.value = 40.0
    @Expect(area.metrics().offsetY, Float32(0.0))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(area.metrics().offsetY, Float32(40.0))
    text.value = "short"
    area.layout(ctx, Rect(10.0, 20.0, 400.0, 300.0))
    @Expect(area.metrics().viewport.x, Float32(18.0))
    @Expect(area.metrics().viewport.w, Float32(384.0))
    @Expect(area.metrics().reservedRight, Float32(0.0))
    @Expect(area.metrics().offsetY, Float32(0.0))
}

@Test
func textAreaMetricsKeepIntrinsicPaddingWhenTheScrollbarIsHidden(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let area = TextArea(State<String>("a\nb\nc\nd\ne\nf\ng"), key: "hidden-editor-metrics")
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(visibility: ScrollBarVisibility.Hidden)))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(area.metrics().viewport.x, Float32(8.0))
    @Expect(area.metrics().viewport.w, Float32(184.0))
    @Expect(area.metrics().reservedRight, Float32(0.0))
}
