package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Color, MouseButton, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func textAreaPreeditReplacesDisplayedMultiLineRangeWithoutChangingDocument(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let value = State<String>("a原\n字b")
    let cursor = State<Int64>(8)
    let anchor = State<Int64>(1)
    let area = TextArea(value, key: "display-ime", cursor: Some(cursor), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 112.0))
    ctx.focus("display-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "PIN", selectionStart: 3, selectionLength: 0))))
    area.draw(ctx)
    var completeLine = false
    var oldContent = false
    for (command in renderer.drawIr()) {
        if (command.kind == "text") {
            let json = command.toJson()
            completeLine = completeLine || json.contains("aPINb")
            oldContent = oldContent || json.contains("原") || json.contains("字")
        }
    }
    @Expect(completeLine)
    @Expect(!oldContent)
    @Expect(value.value, "a原\n字b")
    @Expect(cursor.value, Int64(8))
    @Expect(anchor.value, Int64(1))
    @Expect(area.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(value.value, "a拼b")
    area.undo()
    @Expect(value.value, "a原\n字b")
}

@Test
func textAreaPreeditClickMapsVisibleSuffixBeforeCancelling(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("a原\n字b")
    let cursor = State<Int64>(8)
    let anchor = State<Int64>(1)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(value, key: "display-click", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 112.0))
    ctx.focus("display-click")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "PIN", selectionStart: 3, selectionLength: 0))))
    area.draw(ctx)
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + 8.25 * 4.1, 12.0)))
    @Expect(!composition.value.active)
    @Expect(cursor.value, Int64(8))
    @Expect(anchor.value, Int64(8))
    @Expect(value.value, "a原\n字b")
}

@Test
func textAreaPreeditWidthFollowsCompositionAndRestoresAfterCancel(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("aXb")
    let horizontal = State<Float32>(0.0)
    let area = TextArea(value, key: "display-width", cursor: Some(State<Int64>(2)),
        anchor: Some(State<Int64>(1)), horizontalScroll: Some(horizontal))
    area.layout(ctx, Rect(0.0, 0.0, 80.0, 112.0))
    ctx.focus("display-width")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "01234567890123456789", selectionStart: 20,
        selectionLength: 0))))
    area.draw(ctx)
    @Expect(horizontal.value > 100.0)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x >= 8.0 && caret.right() <= 72.0)
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Cancel))))
    area.draw(ctx)
    @Expect(horizontal.value, Float32(0.0))
    @Expect(value.value, "aXb")
}

@Test
func textAreaDisplayDecorationProjectionSplitsReplacementAndRebasesRows(): Unit {
    let source = "a原\n字b\nz"
    let color = Color.rgb(210, 30, 40)
    let style = TextAreaDecorationStyle(foreground: Some(color))
    let projection = TextAreaDisplayProjection(source, UInt64(7), TextCompositionSnapshot(
        active: true, preedit: "PIN", replacementStartByte: 1, replacementEndByte: 8,
        documentRevision: UInt64(7)))
    let decoration = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(UInt64(7), [
        TextAreaDecoration(0, source.size, style),
        TextAreaDecoration(2, 4, style) // Invalid source byte, do not validate only after projection.
    ]))
    let projected = projection.decorations(decoration.value.decorations())
    @Expect(projected.size, Int64(2))
    @Expect(projected[0].startByte, Int64(0))
    @Expect(projected[0].endByte, Int64(1))
    @Expect(projected[1].startByte, Int64(4))
    @Expect(projected[1].endByte, Int64(7))
    let runs = TextAreaDecorationCache().visibleRuns(source, UInt64(7), Some(decoration), 1, 2,
        display: Some(projection), displayRevision: UInt64(1))
    @Expect(runs.size, Int64(1))
    @Expect(runs[0].lineIndex, Int64(1))
    @Expect(runs[0].startByte, Int64(6)) // z moved from document row2 to display row1.
    @Expect(projection.text[runs[0].startByte..runs[0].endByte], "z")
}

@Test
func textAreaDisplayRejectsStaleOrInvalidSplicesAndKeepsScalarPreeditOffsets(): Unit {
    let raw = TextCompositionSnapshot(active: true, preedit: "e\u{301}\r\n你",
        selectionStart: 3, selectionLength: 2, replacementStartByte: 1, replacementEndByte: 4,
        documentRevision: UInt64(7))
    let projected = TextAreaDisplayProjection("a原b", UInt64(7), raw)
    @Expect(projected.text, "ae\u{301} 你b")
    @Expect(projected.selectionStart, Int64(5))
    @Expect(projected.selectionEnd, Int64(8))
    @Expect(projected.documentOffset(7), Int64(1)) // Within preedit CJK scalar -> replacement start.
    @Expect(projected.documentOffset(8), Int64(4))
    let stale = TextAreaDisplayProjection("a原b", UInt64(8), raw)
    @Expect(!stale.active)
    @Expect(stale.text, "a原b")
    let invalid = TextAreaDisplayProjection("a原b", UInt64(7), TextCompositionSnapshot(
        active: true, preedit: "x", replacementStartByte: 2, replacementEndByte: 4,
        documentRevision: UInt64(7)))
    @Expect(!invalid.active)
    @Expect(invalid.text, "a原b")
}

@Test
func textAreaDisplayCacheChecksPayloadEvenWhenExternalGenerationIsReused(): Unit {
    let cache = TextAreaDisplayCache()
    let first = TextCompositionSnapshot(active: true, preedit: "x", documentRevision: UInt64(7))
    let _ = cache.resolve("ab", UInt64(7), first)
    for (_ in 0..100) { let _ = cache.resolve("ab", UInt64(7), first) }
    @Expect(cache.revision, UInt64(1))
    let changed = cache.resolve("ab", UInt64(7), TextCompositionSnapshot(active: true,
        preedit: "longer", documentRevision: UInt64(7)))
    @Expect(cache.revision, UInt64(2))
    @Expect(changed.text, "longerab")
    let normal = cache.resolve("ab", UInt64(7), TextCompositionSnapshot())
    @Expect(cache.revision, UInt64(3))
    @Expect(normal.text, "ab")
    @Expect(!normal.active)
}
