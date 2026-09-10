package chui.core

import sdl.{FrameInfo, IconName, MouseButton, Rect, UiEvent}

@Test
func longPressKeepsFramesAliveWithoutInkAndStopsAfterFiring(): Unit {
    let ctx = testContext()
    let longs = State<Int64>(0)
    let clicks = State<Int64>(0)
    let surface = InteractionSurface(action: {=> clicks.value += 1}, key: Some("hold")) { Label("Hold") }
        .gestures(GestureHandlers(onLongPress: Some({=> longs.value += 1}), longPressMs: UInt64(900)))
    surface.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0))
    @Expect(ctx.takeFrameRequest())
    ctx.cancelInkRipple("hold")
    surface.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(600), UInt64(600))))
    @Expect(ctx.takeFrameRequest())
    @Expect(longs.value, 0)
    surface.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(900), UInt64(300))))
    @Expect(longs.value, 1)
    @Expect(!ctx.takeFrameRequest())
    surface.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1200), UInt64(300))))
    surface.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0))
    @Expect(longs.value, 1)
    @Expect(clicks.value, 0)
}

@Test
func draggingNeverAlsoFiresLongPressAndDisabledFrameCancelsCapture(): Unit {
    let ctx = testContext()
    let longs = State<Int64>(0)
    let cancels = State<Int64>(0)
    let surface = InteractionSurface(action: {=> ()}, key: Some("drag-hold")) { Label("Drag") }
        .gestures(GestureHandlers(onLongPress: Some({=> longs.value += 1}),
            onDragUpdate: Some({_, _, _, _ => ()}), onDragCancel: Some({=> cancels.value += 1})))
    surface.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    surface.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    surface.handle(ctx, UiEvent.MouseMove(40.0, 20.0))
    @Expect(ctx.hasPointerCapture("drag-hold"))
    ctx.takeFrameRequest()
    surface.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1000), UInt64(1000))))
    @Expect(longs.value, 0)
    @Expect(!ctx.takeFrameRequest())
    let disabled = surface.enabled(false)
    disabled.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1100), UInt64(100))))
    @Expect(cancels.value, 1)
    @Expect(!ctx.hasPointerCapture("drag-hold"))
    @Expect(!ctx.isPressed("drag-hold"))
    disabled.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1200), UInt64(100))))
    @Expect(cancels.value, 1)
}

@Test
func stockButtonsExposeGesturesUnderTheirExistingKeys(): Unit {
    let longs = State<Int64>(0)
    let handlers = GestureHandlers(onLongPress: Some({=> longs.value += 1}))
    let widgets: Array<Widget> = [
        Button("Hold", {=> ()}).key("stock-hold").gestures(handlers),
        IconButton(IconName.Save, onClick: {=> ()}).key("stock-icon").gestures(handlers)
    ]
    let ctx = testContext()
    for (widget in widgets) {
        widget.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
        widget.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
        widget.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(700), UInt64(700))))
        widget.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 10.0))
        @Expect(widget.interactionOwnerIds().size, 1)
    }
    @Expect(longs.value, 2)
}

@Test
func explicitGestureKeyRetainsPressDeadlineAcrossBuildOrderChanges(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let longs = State<Int64>(0)
    let first = buildRoot({=>
        Button("Hold", {=> ()}).key("stable-hold")
            .gestures(GestureHandlers(onLongPress: Some({=> longs.value += 1})))
    }, store)
    first.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    ctx.frame = FrameInfo(UInt64(1000), UInt64(0))
    first.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    let second = buildRoot({=>
        VStack {
            Label("New preceding node")
            Button("Hold", {=> ()}).key("stable-hold")
                .gestures(GestureHandlers(onLongPress: Some({=> longs.value += 1})))
        }
    }, store)
    second.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    second.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1100), UInt64(100))))
    @Expect(longs.value, 0)
    second.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(1500), UInt64(400))))
    @Expect(longs.value, 1)
}
