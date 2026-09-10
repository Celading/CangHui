package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func submitRequiresFocusAndDoesNotRepeat(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let calls = State<Int64>(0)
    let value = State<String>("query")
    let first = TextField(value, key: "first").onSubmit {=> calls.value += 1}
    let second = TextField(value, key: "second").onSubmit {=> calls.value += 10}
    ctx.focus("second")
    @Expect(!first.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(second.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(second.handle(ctx, UiEvent.KeyDown(Key.Enter, true)))
    @Expect(calls.value, Int64(10))
    @Expect(value.value, "query")
}

@Test
func readOnlyAndUnregisteredFieldsDoNotSubmit(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let calls = State<Int64>(0)
    let value = State<String>("query")
    let ro = TextField(value, key: "readonly", editable: false).onSubmit {=> calls.value += 1}
    ctx.focus("readonly")
    @Expect(!ro.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    let plain = TextField(value, key: "plain")
    ctx.focus("plain")
    @Expect(!plain.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(calls.value, Int64(0))
}

@Test
func preeditEnterDoesNotSubmitUncommittedText(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let submitted = State<String>("")
    let value = State<String>("")
    let field = TextField(value, key: "ime").onSubmit {=> submitted.value = value.value}
    ctx.focus("ime")
    @Expect(field.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "pin"))))
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(submitted.value, "")
    @Expect(field.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(submitted.value, "")
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(submitted.value, "拼")
}
