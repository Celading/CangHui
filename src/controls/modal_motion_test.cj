package chui.controls

import sdl.{FrameInfo, Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{Button, State, StateStore, Theme, UiContext, buildRoot, currentStateGeneration}

@Test
func hiddenAndSettledModalDoNotInvalidateIdleFrames(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let hidden = Modal(State<Bool>(false)) {=> ()}
    let before = currentStateGeneration()
    let _ = hidden.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(16), UInt64(16))))
    hidden.draw(ctx)
    @Expect(currentStateGeneration(), before)
    @Expect(!ctx.takeFrameRequest())

    let open = Modal(State<Bool>(true)) {=> ()}
    let _ = open.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1000), UInt64(1000))))
    let settled = currentStateGeneration()
    let _ = ctx.takeFrameRequest()
    let _ = open.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1016), UInt64(16))))
    open.draw(ctx)
    @Expect(currentStateGeneration(), settled)
    @Expect(!ctx.takeFrameRequest())
}

@Test
func modalEntranceBlocksHiddenActionsThenSettles(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 300.0
    let clicks = State<Int64>(0)
    let open = State<Bool>(true)
    let modal = Modal(open) { Button("Confirm", {=> clicks.value += 1}).key("confirm") }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.takeFrameRequest())
    @Expect(modal.focusableIds().isEmpty())
    let _ = ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 200.0, 150.0))
    let _ = ctx.dispatchOverlay(UiEvent.MouseUp(MouseButton.Left, 200.0, 150.0))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false))
    @Expect(clicks.value, 0)
    let _ = modal.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1000), UInt64(1000))))
    let _ = ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 200.0, 150.0))
    let _ = ctx.dispatchOverlay(UiEvent.MouseUp(MouseButton.Left, 200.0, 150.0))
    @Expect(clicks.value, 1)
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false))
    @Expect(!open.value)
}

@Test
func modalMotionSurvivesRebuildAndReducedMotionFinishesImmediately(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let open = State<Bool>(true)
    let captured = State<?Modal>(None)
    let body = {=> captured.value = Some(Modal(open) {=> ()})}
    let _ = buildRoot(body, store)
    let first = captured.value.getOrThrow()
    let _ = first.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1000), UInt64(1000))))
    let _ = ctx.takeFrameRequest()
    let _ = buildRoot(body, store)
    captured.value.getOrThrow().draw(ctx)
    @Expect(!ctx.takeFrameRequest()) // a rebuild does not replay a settled entrance
    open.value = false
    captured.value.getOrThrow().draw(ctx)
    open.value = true
    let _ = buildRoot(body, store)
    captured.value.getOrThrow().draw(ctx)
    @Expect(ctx.takeFrameRequest())
    ctx.theme = ctx.theme.withReduceMotion(true)
    captured.value.getOrThrow().draw(ctx)
    @Expect(!ctx.takeFrameRequest())
}

@Test
func modalEscapeWorksBeforeEntranceFinishes(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let open = State<Bool>(true)
    let modal = Modal(open) {=> ()}
    modal.draw(ctx)
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false))
    @Expect(!open.value)
    @Expect(!ctx.hasOverlay())
}
