package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func compositionTransactionAreaEnterDoesNotCommitOrInsertNewline(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("base")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "ime-enter", composition: Some(composition))
    ctx.focus("ime-enter")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "拼"))))
    for (repeat in [false, true]) {
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Enter, repeat)))
        @Expect(text.value, "base")
        @Expect(composition.value.active)
    }
    @Expect(area.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(text.value, "base拼")
    @Expect(!composition.value.active)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(text.value, "base拼\n")
}

@Test
func compositionTransactionFieldSeparatesTypingAndImeUndoGroups(): Unit {
    for (direct in [false, true]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let text = State<String>("")
        let field = TextField(text, key: "ime-field")
        ctx.focus("ime-field")
        @Expect(field.handle(ctx, UiEvent.TextInput("ab")))
        if (!direct) {
            @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "pin"))))
        }
        let commit = if (direct) {
            UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Commit, text: "拼"))
        } else { UiEvent.TextInput("拼") }
        @Expect(field.handle(ctx, commit))
        @Expect(field.handle(ctx, UiEvent.TextInput("cd")))
        @Expect(text.value, "ab拼cd")
        field.undo(); @Expect(text.value, "ab拼")
        field.undo(); @Expect(text.value, "ab")
        field.undo(); @Expect(text.value, "")
        field.redo(); @Expect(text.value, "ab")
        field.redo(); @Expect(text.value, "ab拼")
        field.redo(); @Expect(text.value, "ab拼cd")
    }
}

@Test
func compositionTransactionAreaSeparatesTypingAndImeUndoGroups(): Unit {
    for (direct in [false, true]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let text = State<String>("")
        let area = TextArea(text, key: "ime-area")
        ctx.focus("ime-area")
        @Expect(area.handle(ctx, UiEvent.TextInput("ab")))
        if (!direct) {
            @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "pin"))))
        }
        let commit = if (direct) {
            UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Commit, text: "拼"))
        } else { UiEvent.TextInput("拼") }
        @Expect(area.handle(ctx, commit))
        @Expect(area.handle(ctx, UiEvent.TextInput("cd")))
        @Expect(text.value, "ab拼cd")
        area.undo(); @Expect(text.value, "ab拼")
        area.undo(); @Expect(text.value, "ab")
        area.undo(); @Expect(text.value, "")
        area.redo(); @Expect(text.value, "ab")
        area.redo(); @Expect(text.value, "ab拼")
        area.redo(); @Expect(text.value, "ab拼cd")
    }
}

@Test
func compositionTransactionAreaEmptyHistoryStillCancelsPreedit(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("unchanged")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "ime-empty-history", composition: Some(composition))
    ctx.focus("ime-empty-history")
    let begin = UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "未提交"))
    @Expect(area.handle(ctx, begin))
    area.undo()
    @Expect(!composition.value.active)
    @Expect(text.value, "unchanged")
    @Expect(area.handle(ctx, begin))
    area.redo()
    @Expect(!composition.value.active)
    @Expect(text.value, "unchanged")
}
