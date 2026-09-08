package chui.core

import sdl.{MouseButton, PointerDeviceKind, PointerEvent, PointerPhase, Rect, UiEvent,
    pointerEventToLegacyUiEvent}

@Test
func pointerCancellationInsideNeverActivatesButtonAndNextClickWorks(): Unit {
    let ctx = testContext()
    let clicks = State<Int64>(0)
    let button = Button("Save", {=> clicks.value += 1}).key("cancel-button")
    button.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0))
    button.handle(ctx, pointerEventToLegacyUiEvent(PointerEvent(
        PointerPhase.Cancel, PointerDeviceKind.Touch, UInt64(1), 20.0, 20.0)))
    @Expect(clicks.value, 0)
    @Expect(!ctx.isPressed("cancel-button"))
    button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0))
    @Expect(clicks.value, 0)
    button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0))
    button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0))
    @Expect(clicks.value, 1)
}

@Test
func pointerCancellationEndsGestureByCancelNotDrop(): Unit {
    let ctx = testContext()
    let cancels = State<Int64>(0)
    let drops = State<Int64>(0)
    let surface = InteractionSurface(action: {=> ()}, key: Some("cancel-drag")) { Label("Drag") }
        .gestures(GestureHandlers(onDragUpdate: Some({_, _, _, _ => ()}),
            onDragEnd: Some({_, _ => drops.value += 1}),
            onDragCancel: Some({=> cancels.value += 1})))
    surface.layout(ctx, Rect(0.0, 0.0, 120.0, 40.0))
    surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 20.0))
    surface.handle(ctx, UiEvent.MouseMove(40.0, 20.0))
    surface.handle(ctx, pointerEventToLegacyUiEvent(PointerEvent(
        PointerPhase.Cancel, PointerDeviceKind.Touch, UInt64(1), 40.0, 20.0)))
    @Expect(cancels.value, 1)
    @Expect(drops.value, 0)
    @Expect(!ctx.hasPointerCapture("cancel-drag"))
    @Expect(!ctx.isDragging("cancel-drag"))
    surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 40.0, 20.0))
    @Expect(drops.value, 0)
}

@Test
func pointerCancellationTraversesConsumingOverlayAndRecoversAfterCallbackFailure(): Unit {
    let ctx = testContext()
    let cancelled = State<Int64>(0)
    let overlayCalls = State<Int64>(0)
    let root = InteractionSurface(action: {=> ()}, key: Some("under-modal")) { Label("Drag") }
        .gestures(GestureHandlers(onDragUpdate: Some({_, _, _, _ => ()}),
            onDragCancel: Some({=>
                cancelled.value += 1
                throw IllegalStateException("cancel callback failed")
            })))
    root.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    root.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 20.0))
    root.handle(ctx, UiEvent.MouseMove(40.0, 20.0))
    ctx.leftMouseDown = true
    ctx.setOverlay(Overlay(handleEvent: {_, _ => overlayCalls.value += 1; true}, render: {_ => ()}))
    var failed = false
    try { let _ = ctx.cancelPointerInteraction(root) }
    catch (e: IllegalStateException) { failed = e.message == "cancel callback failed" }
    @Expect(failed)
    @Expect(overlayCalls.value, 1)
    @Expect(cancelled.value, 1)
    @Expect(ctx.dragId, "")
    @Expect(ctx.pressedId, "")
    @Expect(ctx.pointerCaptureOwner(), "")
    @Expect(!ctx.leftMouseDown)
    let _ = ctx.cancelPointerInteraction(root)
    @Expect(cancelled.value, 1)
    @Expect(overlayCalls.value, 2)
}

@Test
func pointerCancellationProbeSuppressesActionThenPermitsFreshClick(): Unit {
    let report = ComponentProbe("cancel-flow", width: 160.0, height: 60.0).run(
        "press 20 20\ncancel\nrelease 20 20\nassert activation save 0\n" +
        "press 20 20\nrelease 20 20\nassert activation save 1") {
        Button("Save", probedAction("save", {=> ()})).key("cancel-save")
    }
    @Expect(report.contains("\"ok\":true"))
}
