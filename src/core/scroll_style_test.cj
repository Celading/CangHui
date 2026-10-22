package chui.core

import sdl.{Color, Rect, Size, UiEvent, MouseButton, Renderer, FrameInfo}

private class ScrollStyleChild <: Widget {
    let extent: Size
    var rect = Rect.zero()
    var draws: Int64 = 0
    public init(extent: Size) { this.extent = extent }
    public func measure(_: UiContext, _: Size): Size { extent }
    public func layout(_: UiContext, value: Rect): Unit { rect = value }
    public func draw(_: UiContext): Unit { draws += 1 }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func scrollbarHiddenRemovesLaneButPreservesWheelAndExternalOffset(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let child = ScrollStyleChild(Size(100.0, 500.0))
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "hidden-style") { emit(child) }.scrollState(offset)
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(visibility: ScrollBarVisibility.Hidden)))
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.metrics().reservedRight, Float32(0.0))
    @Expect(child.rect.w, Float32(200.0))
    @Expect(!view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 60.0)))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 195.0, 60.0)))
    @Expect(offset.value, Float32(72.0))
    offset.value = 200.0
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.metrics().offsetY, Float32(200.0))
    view.draw(ctx)
    for (command in ctx.renderer.drawIr()) { @Expect(!command.kind.startsWith("paint.")) }
}

@Test
func scrollbarCustomWidthDrivesLayoutAndTheActualDraggableLane(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let style = ScrollBarStyle(width: 20.0, margin: 4.0, minThumbLength: 24.0)
    let view = ScrollView(key: "wide-style") { emit(ScrollStyleChild(Size(100.0, 500.0))) }
        .scrollState(offset).scrollOptions(ScrollOptions.immediate(bar: style, contentInset: 5.0))
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.metrics().reservedRight, Float32(33.0))
    @Expect(view.metrics().viewport.w, Float32(167.0))
    ctx.leftMouseDown = true
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 180.0, 10.0)))
    @Expect(view.handle(ctx, UiEvent.MouseMove(180.0, 55.0)))
    @Expect(offset.value > 0.0)
}

@Test
func scrollbarOverlayAndResizeReportFreshViewportWithoutDoubleReservation(): Unit {
    let ctx = testContext()
    let x = State<Float32>(50.0)
    let y = State<Float32>(100.0)
    let view = ScrollView(key: "overlay-style") { emit(ScrollStyleChild(Size(500.0, 400.0))) }
        .horizontalContent(500.0).horizontalScrollState(x).scrollState(y)
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(layout: ScrollBarLayout.Overlay)))
    @Expect(view.metrics().viewport.w, Float32(0.0))
    view.layout(ctx, Rect(10.0, 20.0, 200.0, 100.0))
    @Expect(view.metrics().viewport.x, Float32(10.0))
    @Expect(view.metrics().viewport.w, Float32(200.0))
    @Expect(view.metrics().viewport.h, Float32(100.0))
    @Expect(view.metrics().reservedRight, Float32(0.0))
    @Expect(view.metrics().reservedBottom, Float32(0.0))
    view.layout(ctx, Rect(10.0, 20.0, 800.0, 600.0))
    @Expect(view.metrics().viewport.w, Float32(800.0))
    @Expect(x.value, Float32(0.0))
    @Expect(y.value, Float32(0.0))
}

@Test
func scrollbarFullyTransparentChromeDoesNotStealPointerButKeepsExplicitReservation(): Unit {
    let ctx = testContext()
    let bar = ScrollBar("transparent-style")
    bar.configure(ScrollBarStyle(opacity: 0.0))
    let offset = State<Float32>(0.0)
    @Expect(!bar.press(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 95.0, 60.0))
    @Expect(scrollBarGutter(style: ScrollBarStyle(opacity: 0.0)), Float32(10.0))
}

@Test
func scrollbarTinyViewportsNeverProduceThumbsLongerThanTracks(): Unit {
    for (size in [Float32(1.0), Float32(4.0), Float32(10.0), Float32(18.0)]) {
        let rect = Rect(0.0, 0.0, size, size)
        let track = scrollBarTrackRect(rect)
        let thumb = scrollThumbRect(rect, 0.0, 1000.0, size).getOrThrow()
        @Expect(thumb.h <= track.h)
        @Expect(thumb.bottom() <= rect.bottom())
        let horizontal = scrollThumbRectH(rect, 0.0, 1000.0, size).getOrThrow()
        @Expect(horizontal.w <= scrollBarTrackRectH(rect).w)
        @Expect(horizontal.right() <= rect.right())
    }
}

@Test
func scrollbarStyleSwitchCancelsAnInvisibleRetainedDrag(): Unit {
    let ctx = testContext()
    let bar = ScrollBar("switch-style")
    let offset = State<Float32>(0.0)
    ctx.leftMouseDown = true
    @Expect(bar.press(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 95.0, 8.0))
    bar.configure(ScrollBarStyle(visibility: ScrollBarVisibility.Hidden))
    @Expect(!bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 70.0))
    @Expect(ctx.dragId.isEmpty())
    @Expect(offset.value, Float32(0.0))
}

@Test
func scrollbarHorizontalStyleUsesTheSameGeometryAndInputPolicy(): Unit {
    let ctx = testContext()
    let bar = HScrollBar("horizontal-style")
    let style = ScrollBarStyle(width: 20.0, margin: 4.0, minThumbLength: 24.0)
    bar.configure(style)
    let offset = State<Float32>(0.0)
    ctx.leftMouseDown = true
    @Expect(bar.press(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 10.0, 80.0))
    @Expect(bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 55.0))
    @Expect(offset.value > 0.0)
    bar.configure(ScrollBarStyle(opacity: 0.0))
    @Expect(!bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 70.0))
    @Expect(ctx.dragId.isEmpty())
}

@Test
func scrollbarRoundedPaintRetainsOriginalColorAlphaAndSeparateTrackOpacity(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let bar = ScrollBar("paint-style")
    bar.configure(ScrollBarStyle(radius: 3.0, trackRadius: 2.0, opacity: 0.5,
        trackOpacity: 1.0, thumbOpacity: 1.0, thumbColor: Some(Color.rgba(10, 20, 30, 128)),
        trackColor: Some(Color.rgb(40, 50, 60))))
    bar.draw(ctx, Rect(0.0, 0.0, 100.0, 100.0), 0.0, 500.0, 100.0)
    let commands = ctx.renderer.drawIr()
    @Expect(commands.size, 2)
    @Expect(commands[0].kind, "paint.fill-rounded-rect")
    @Expect(commands[0].toJson().contains("\"a\":127"))
    @Expect(commands[1].toJson().contains("\"r\":10,\"g\":20,\"b\":30,\"a\":64"))
}

@Test
func scrollbarAppearanceMotionSettlesAndReducedMotionDoesNotKeepFramesAlive(): Unit {
    let style = ScrollBarStyle(thumbColor: Some(Color.rgb(0, 0, 0)),
        hoverColor: Some(Color.rgb(200, 0, 0)), interactionAnimation: Some(AnimationSpec(duration: 100,
            easing: Easing.Linear)))
    let ctx = testContext()
    let paint = ScrollBarVisual()
    ctx.frame = FrameInfo(50, 50)
    let first = paint.color(ctx, style, true, false)
    @Expect(first.r > 0 && first.r < 200)
    @Expect(ctx.takeFrameRequest())
    ctx.frame = FrameInfo(150, 100)
    @Expect(paint.color(ctx, style, true, false).r, UInt8(200))
    @Expect(!ctx.takeFrameRequest())
    let reduced = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    reduced.frame = FrameInfo(16, 16)
    @Expect(ScrollBarVisual().color(reduced, style, true, false).r, UInt8(200))
    @Expect(!reduced.takeFrameRequest())
}

@Test
func scrollbarStyleRejectsNonFiniteOpacityGeometryAndWheelStep(): Unit {
    for (bad in [Float32(-1.0), Float32.NaN, Float32.Inf]) {
        var geometry = false
        try { let _ = ScrollBarStyle(width: bad) } catch (_: IllegalArgumentException) { geometry = true }
        @Expect(geometry)
        var opacity = false
        try { let _ = ScrollBarStyle(opacity: bad) } catch (_: IllegalArgumentException) { opacity = true }
        @Expect(opacity)
        var wheel = false
        try { let _ = ScrollOptions.web(wheelStep: bad) } catch (_: IllegalArgumentException) { wheel = true }
        @Expect(wheel)
    }
}

@Test
func scrollableModifierEmitsOneWrapperAndKeepsUnrelatedStoredSiblings(): Unit {
    let ctx = testContext()
    let child = ScrollStyleChild(Size(100.0, 300.0))
    let sibling = ScrollStyleChild(Size(40.0, 20.0))
    let root = buildRoot({=>
        emit(sibling)
        child.scrollable(key: "stored-style", options: ScrollOptions.immediate()).height(80.0)
    }, StateStore())
    root.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))
    root.draw(ctx)
    @Expect(child.draws, 1)
    @Expect(sibling.draws, 1)
}

@Test
func scrollableModifierReplacesAnAlreadyEmittedContainerExactlyOnce(): Unit {
    let ctx = testContext()
    let child = ScrollStyleChild(Size(100.0, 300.0))
    let root = buildRoot({=>
        VStack { emit(child) }.scrollable(key: "parent-style").height(80.0)
    }, StateStore())
    root.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    root.draw(ctx)
    @Expect(child.draws, 1)
}

@Test
func scrollbarTinyFrameDoesNotConsumeAPressOutsideItsBounds(): Unit {
    let ctx = testContext()
    @Expect(!ScrollBar("tiny-outside").press(ctx, Rect(0.0, 0.0, 100.0, 10.0),
        State<Float32>(0.0), 500.0, 10.0, 95.0, 15.0))
}

@Test
func scrollbarShrinkingContentReleasesAnOldDrag(): Unit {
    let ctx = testContext()
    ctx.leftMouseDown = true
    let bar = ScrollBar("shrink-drag")
    let offset = State<Float32>(0.0)
    @Expect(bar.press(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 95.0, 8.0))
    @Expect(!bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 50.0, 100.0, 60.0))
    @Expect(ctx.dragId.isEmpty())
}

@Test
func scrollableModifierRetainsOneChildKeyboardOwner(): Unit {
    let root = buildRoot({=>
        VStack { Button("Child", {=> ()}).key("scroll-child") }.scrollable(key: "focus-wrapper")
    }, StateStore())
    @Expect(root.focusableIds().size, 1)
}

@Test
func hiddenScrollbarKeepsExplicitContentPanning(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "hidden-pan") {emit(ScrollStyleChild(Size(100.0, 500.0)))}
        .scrollState(offset).dragToScroll()
        .scrollOptions(ScrollOptions.immediate(bar: ScrollBarStyle(visibility: ScrollBarVisibility.Hidden)))
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    ctx.leftMouseDown = true
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 50.0, 70.0))
    @Expect(view.handle(ctx, UiEvent.MouseMove(50.0, 30.0)))
    @Expect(offset.value, Float32(40.0))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 50.0, 30.0)))
}

@Test
func scrollbarExplicitTransparentColorsDoNotOwnAnInvisibleHitLane(): Unit {
    let clear = Color.rgba(10, 20, 30, 0)
    let style = ScrollBarStyle(thumbColor: Some(clear), trackColor: Some(clear))
    @Expect(!style.interactive())
    @Expect(ScrollBarStyle(thumbColor: Some(clear), hoverColor: Some(Color.rgb(1, 2, 3))).interactive())
}

@Test
func scrollbarHoverPaintRespectsTheWinningInputOwner(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let bar = ScrollBar("hover-owner")
    bar.configure(ScrollBarStyle(thumbColor: Some(Color.rgb(10, 20, 30)),
        hoverColor: Some(Color.rgb(200, 100, 50))))
    let offset = State<Float32>(0.0)
    ctx.mouseX = 95.0; ctx.mouseY = 8.0
    ctx.beginHoverTest()
    ctx.claimHover("overlay", CursorShape.Default)
    let _ = bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 8.0)
    ctx.settleHover()
    bar.draw(ctx, Rect(0.0, 0.0, 100.0, 100.0), 0.0, 500.0, 100.0)
    let before = ctx.renderer.drawIr()
    @Expect(before[1].toJson().contains("\"r\":10,\"g\":20,\"b\":30"))
    ctx.beginHoverTest()
    let _ = bar.drag(ctx, Rect(0.0, 0.0, 100.0, 100.0), offset, 500.0, 100.0, 8.0)
    ctx.settleHover()
    bar.draw(ctx, Rect(0.0, 0.0, 100.0, 100.0), 0.0, 500.0, 100.0)
    let after = ctx.renderer.drawIr()
    @Expect(after[3].toJson().contains("\"r\":200,\"g\":100,\"b\":50"))
}

@Test
func scrollbarCompositeCanShareItsExistingHoverOwner(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let bar = ScrollBar("composite-thumb")
    bar.configure(ScrollBarStyle(hoverColor: Some(Color.rgb(200, 100, 50))), hoverOwner: "composite")
    ctx.mouseX = 95.0; ctx.mouseY = 8.0
    ctx.beginHoverTest(); ctx.claimHover("composite", CursorShape.Text); ctx.settleHover()
    bar.draw(ctx, Rect(0.0, 0.0, 100.0, 100.0), 0.0, 500.0, 100.0)
    @Expect(ctx.renderer.drawIr()[1].toJson().contains("\"r\":200,\"g\":100,\"b\":50"))
}

@Test
func scrollbarDefaultThemeAlphaPreservesTheExistingChromeContract(): Unit {
    let base = Theme.light()
    let theme = Theme(bg: base.bg, panel: base.panel, panelEdge: base.panelEdge.withAlpha(45),
        text: base.text, mutedText: base.mutedText, accent: base.accent.withAlpha(90),
        accentText: base.accentText, danger: base.danger, field: base.field, fieldActive: base.fieldActive)
    let ctx = UiContext(Renderer.recordingHeadless(), theme)
    ScrollBar("legacy-theme-alpha").draw(ctx, Rect(0.0, 0.0, 100.0, 100.0), 0.0, 500.0, 100.0)
    @Expect(ctx.renderer.drawIr()[0].toJson().contains("\"a\":80"))
    @Expect(ctx.renderer.drawIr()[1].toJson().contains("\"a\":180"))
}

@Test
func scrollMetricsSnapshotDoesNotMixPendingOffsetsWithOldGeometry(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "metrics-snapshot") {emit(ScrollStyleChild(Size(100.0, 500.0)))}
        .scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    offset.value = 80.0
    @Expect(view.metrics().offsetY, Float32(0.0))
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.metrics().offsetY, Float32(80.0))
}
