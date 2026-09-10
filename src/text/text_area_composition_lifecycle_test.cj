package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

@Test
func textAreaWindowFocusLossClearsCompositionWithoutLosingLogicalFocus(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("old")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "area-window-ime", composition: Some(composition))
    ctx.focus("area-window-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "新"))))
    let generation = composition.value.generation
    let _ = area.handle(ctx, UiEvent.WindowFocusChanged(false))
    @Expect(!composition.value.active)
    @Expect(composition.value.preedit, "")
    @Expect(composition.value.generation > generation)
    @Expect(ctx.hasFocus("area-window-ime"))
    @Expect(text.value, "old")
    area.undo()
    @Expect(text.value, "old")
}

@Test
func textAreaEscapeConsumesOnlyAnActiveComposition(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("old")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "area-escape-ime", composition: Some(composition))
    ctx.focus("area-escape-ime")
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Escape, false)))
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "新"))))
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!composition.value.active)
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Escape, false)))
    @Expect(text.value, "old")
}

@Test
func textAreaUpdateAfterExternalEditCannotReviveOldReplacementRange(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "area-revision-ime", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    ctx.focus("area-revision-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "p"))))
    text.value = "newtext"; cursor.value = 7; anchor.value = 7
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Update, text: "pin"))))
    @Expect(composition.value.replacementStartByte, Int64(7))
    @Expect(composition.value.replacementEndByte, Int64(7))
    @Expect(area.handle(ctx, UiEvent.TextInput("拼")))
    @Expect(text.value, "newtext拼")
    area.undo()
    @Expect(text.value, "newtext")
}

@Test
func textAreaDrawClearsExternallyInvalidatedCompositionSnapshot(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("old")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "area-draw-ime", composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 90.0))
    ctx.focus("area-draw-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "新"))))
    text.value = "external"
    area.draw(ctx)
    @Expect(!composition.value.active)
    @Expect(composition.value.preedit, "")
    @Expect(text.value, "external")
}
