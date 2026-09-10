package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Rect, Renderer}

@Test
func readonlyTextControlsDoNotPublishImeAnchors(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let field = TextField(State<String>("read"), key: "field", editable: false)
    field.layout(ctx, Rect(0.0, 0.0, 300.0, 40.0)); ctx.focus("field")
    field.draw(ctx)
    @Expect(ctx.textInputAnchorRect().isNone())
    @Expect(!ctx.hasTextInputRequest())
    ctx.clearTextInputAnchor()
    let area = TextArea(State<String>("read\nonly"), key: "area", editable: false)
    area.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0)); ctx.focus("area")
    area.draw(ctx)
    @Expect(ctx.textInputAnchorRect().isNone())
    @Expect(!ctx.hasTextInputRequest())
}

@Test
func editingSessionDemandIsIndependentOfVisibleCaret(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let scroll = State<Float32>(0.0)
    let area = TextArea(State<String>("0\n1\n2\n3\n4\n5\n6\n7\n8\n9"), key: "area",
        cursor: Some(State<Int64>(0)), anchor: Some(State<Int64>(0)), scroll: Some(scroll))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 60.0)); ctx.focus("area")
    area.draw(ctx)
    @Expect(ctx.hasTextInputRequest())
    @Expect(ctx.textInputAnchorRect().isSome())
    ctx.clearTextInputAnchor(); scroll.value = 120.0
    area.draw(ctx)
    @Expect(ctx.hasTextInputRequest())
    @Expect(ctx.textInputAnchorRect().isNone())
    ctx.clearTextInputAnchor(); ctx.focus("other")
    area.draw(ctx)
    @Expect(!ctx.hasTextInputRequest())
}

@Test
func customCaretAnchorsPreserveLegacyInputRequest(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    @Expect(!ctx.hasTextInputRequest())
    ctx.setTextInputAnchor(Rect(1.0, 2.0, 1.0, 20.0))
    @Expect(ctx.hasTextInputRequest())
    ctx.clearTextInputAnchor()
    @Expect(!ctx.hasTextInputRequest())
    @Expect(ctx.textInputAnchorRect().isNone())
    ctx.requestTextInput()
    @Expect(ctx.hasTextInputRequest())
    @Expect(ctx.textInputAnchorRect().isNone())
}
