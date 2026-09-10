package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, MouseButton, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func textFieldPreeditRendersWithoutEditingTheDocument(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let value = State<String>("a原b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let field = TextField(value, key: "field-preedit", cursor: Some(cursor), anchor: Some(anchor))
    field.layout(ctx, Rect(0.0, 0.0, 320.0, 38.0))
    ctx.focus("field-preedit")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "PIN", selectionStart: 3))))
    field.draw(ctx)
    var found = false
    for (command in renderer.drawIr()) {
        if (command.kind == "text") { found = found || command.toJson().contains("aPINb") }
    }
    @Expect(found)
    @Expect(value.value, "a原b")
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(1))
    @Expect(field.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(value.value, "a拼b")
    field.undo()
    @Expect(value.value, "a原b")
}

@Test
func textFieldCompositionCancelAndFocusLossDoNotCommit(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("old")
    let state = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let field = TextField(value, key: "field-cancel", composition: Some(state))
    field.layout(ctx, Rect(0.0, 0.0, 100.0, 38.0))
    ctx.focus("field-cancel")
    let begin = UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "中文"))
    @Expect(field.handle(ctx, begin))
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!state.value.active)
    @Expect(field.handle(ctx, begin))
    let _ = field.handle(ctx, UiEvent.WindowFocusChanged(false))
    @Expect(!state.value.active)
    @Expect(field.handle(ctx, begin))
    ctx.focus("another")
    field.draw(ctx)
    @Expect(!state.value.active)
    @Expect(value.value, "old")
    field.undo()
    @Expect(value.value, "old")
}

@Test
func textFieldCompositionRejectsInvalidRangesAndUnfocusedOrReadOnlyInput(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("a你b")
    let field = TextField(value, key: "field-invalid")
    let event = UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "PIN"))
    @Expect(!field.handle(ctx, event))
    ctx.focus("field-invalid")
    @Expect(!field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin,
        text: "PIN", replacementStartByte: 2, replacementEndByte: 4))))
    let ro = TextField(value, key: "field-readonly", editable: false)
    ctx.focus("field-readonly")
    @Expect(!ro.handle(ctx, event))
    @Expect(!ro.handle(ctx, UiEvent.TextInput("X")))
    @Expect(value.value, "a你b")
}

@Test
func textFieldCompositionTracksReplacementAndDoesNotReuseAnExternalDocumentRange(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let state = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let field = TextField(value, key: "field-range", cursor: Some(cursor), anchor: Some(anchor), composition: Some(state))
    ctx.focus("field-range")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "p"))))
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Update, text: "pin"))))
    @Expect(state.value.replacementStartByte, Int64(1))
    @Expect(state.value.replacementEndByte, Int64(4))
    value.value = "new"
    cursor.value = 3; anchor.value = 3
    @Expect(field.handle(ctx, UiEvent.TextInput("文")))
    @Expect(value.value, "new文")
    @Expect(!state.value.active)
    field.undo()
    @Expect(value.value, "new")
}

@Test
func textFieldPreeditPointerUsesDisplayedSuffixAndThenCancels(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let value = State<String>("a原b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let state = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let field = TextField(value, key: "field-hit", cursor: Some(cursor), anchor: Some(anchor), composition: Some(state))
    field.layout(ctx, Rect(0.0, 0.0, 320.0, 38.0))
    ctx.focus("field-hit")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin,
        text: "PIN", selectionStart: 3))))
    field.draw(ctx)
    @Expect(field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + 8.25 * 4.1, 18.0)))
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(4))
    @Expect(!state.value.active)
    @Expect(value.value, "a原b")
}

@Test
func secureTextFieldMasksTransientCompositionAndKeepsUndoDisabled(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let value = State<String>("secret")
    let field = TextField(value, key: "field-secret").secureEntry()
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))
    ctx.focus("field-secret")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "密钥"))))
    field.draw(ctx)
    var masked = false
    for (command in renderer.drawIr()) {
        let json = command.toJson()
        @Expect(!json.contains("secret"))
        @Expect(!json.contains("密钥"))
        masked = masked || json.contains("••••••••")
    }
    @Expect(masked)
    @Expect(value.value, "secret")
    @Expect(field.handle(ctx, UiEvent.TextInput("钥")))
    field.undo()
    @Expect(value.value, "secret钥")
}

@Test
func textFieldPreeditFollowsCaretAndCommitStaysSingleLine(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let value = State<String>("")
    let field = TextField(value, key: "field-long")
    field.layout(ctx, Rect(0.0, 0.0, 80.0, 38.0))
    ctx.focus("field-long")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin,
        text: "01234567890123456789", selectionStart: 20))))
    field.draw(ctx)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x >= 8.0 && caret.right() <= 74.0)
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Commit, text: "你\r\n好"))))
    @Expect(value.value, "你 好")
    field.undo()
    @Expect(value.value, "")
}
