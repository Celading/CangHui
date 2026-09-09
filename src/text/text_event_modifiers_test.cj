package chui.text

import chui.core.{UiContext, Theme, State}
import sdl.{Renderer, Rect, UiEvent, Key}
import sdl.input.Keyboard

@Test
func textFieldNavigationUsesEventModifierRatherThanCurrentDeviceState(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let caret = State<Int64>(0)
    let anchor = State<Int64>(0)
    let field = TextField(State<String>("a你b"), key: "field", editable: false,
        cursor: Some(caret), anchor: Some(anchor))
    field.layout(ctx, Rect(0.0, 0.0, 320.0, 40.0))
    ctx.focus("field", viaKeyboard: true)
    let shift = !Keyboard.modifiers().shift
    let mask = if (shift) { UInt16(1) } else { UInt16(0) }
    @Expect(ctx.withEventModifiers(Some(mask), {=> field.handle(ctx, UiEvent.KeyDown(Key.End, false)) }))
    @Expect(caret.value, Int64(5))
    @Expect(anchor.value, if (shift) { Int64(0) } else { Int64(5) })
}

@Test
func textAreaNavigationUsesEventModifierRatherThanCurrentDeviceState(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let caret = State<Int64>(0)
    let anchor = State<Int64>(0)
    let area = TextArea(State<String>("a你b"), key: "area",
        cursor: Some(caret), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 100.0))
    ctx.focus("area", viaKeyboard: true)
    let shift = !Keyboard.modifiers().shift
    let mask = if (shift) { UInt16(1) } else { UInt16(0) }
    @Expect(ctx.withEventModifiers(Some(mask), {=> area.handle(ctx, UiEvent.KeyDown(Key.End, false)) }))
    @Expect(caret.value, Int64(5))
    @Expect(anchor.value, if (shift) { Int64(0) } else { Int64(5) })
}
