package chui

import chui.controls.Modal
import chui.core.{State, Theme, UiContext, emit}
import chui.text.{TextArea, TextField, TextCompositionSnapshot}
import sdl.{Key, Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}

private func verifyModalCompositionEscape(multiline: Bool): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light(reduceMotion: true))
    ctx.viewportWidth = 400.0; ctx.viewportHeight = 300.0
    let open = State<Bool>(true)
    let text = State<String>("old")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let modal = Modal(open) {
        if (multiline) {
            emit(TextArea(text, key: "modal-ime", composition: Some(composition)))
        } else {
            emit(TextField(text, key: "modal-ime", composition: Some(composition)))
        }
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    ctx.focus("modal-ime")
    @Expect(ctx.dispatchOverlay(UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin, text: "新"))))
    @Expect(composition.value.active)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!composition.value.active)
    @Expect(open.value)
    @Expect(ctx.hasOverlay())
    @Expect(text.value, "old")
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!open.value)
    @Expect(!ctx.hasOverlay())
}

@Test
func modalLetsTextFieldCancelCompositionBeforeEscapeDismisses(): Unit {
    verifyModalCompositionEscape(false)
}

@Test
func modalLetsTextAreaCancelCompositionBeforeEscapeDismisses(): Unit {
    verifyModalCompositionEscape(true)
}
