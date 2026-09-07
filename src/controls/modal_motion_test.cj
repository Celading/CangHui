package chui.controls

import sdl.{FrameInfo, Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{Button, ComponentProbe, FrameHandler, Label, State, StateStore, Theme, UiContext, ZStack,
    buildRoot, currentStateGeneration}

@Test
func probeRoutesPointerAndKeyboardThroughModal(): Unit {
    let background = State<Int64>(0)
    let confirms = State<Int64>(0)
    let open = State<Bool>(true)
    let report = ComponentProbe("modal.route", width: 400.0, height: 300.0,
        theme: Theme.light(reduceMotion: true)).run("key Tab\nkey Enter\npress 20 20\nrelease 20 20") {
        ZStack {
            Button("background", {=> background.value += 1}).key("background")
            Modal(open) { Button("confirm", {=> confirms.value += 1}).key("confirm") }
        }
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(confirms.value, 1)
    @Expect(background.value, 0)
    @Expect(!open.value)
}

@Test
func probeAdvancesFrameClockOnce(): Unit {
    let elapsed = State<UInt64>(0)
    let _ = ComponentProbe("frame.once").run("advance 40\nadvance 60") {
        FrameHandler(onFrame: {info => elapsed.value += info.deltaMs}) { Label("time") }
    }
    @Expect(elapsed.value, UInt64(100))
}

@Test
func probeAsciiDoesNotRecommendActionsThroughModal(): Unit {
    let report = ComponentProbe("modal.ascii", width: 400.0, height: 300.0).run("@cui-ascii 80 20") {
        ZStack {
            Button("background", {=> ()}).key("background")
            Modal(State<Bool>(true)) { Label("dialog") }
        }
    }
    @Expect(report.contains("overlay-unverified"))
    @Expect(!report.contains("probe=\"press"))
}

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
