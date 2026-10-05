package chui.core

import sdl.{Rect, Size, UiEvent, MouseButton, FrameInfo}

@Test
func nestedScrollViewGivesInnerFirstThenChainsAtBoundary(): Unit {
    let ctx = testContext()
    let innerOffset = State<Float32>(0.0)
    let outerOffset = State<Float32>(0.0)
    let inner = ScrollView(key: "nested.inner") {
        emit(SizedLayoutProbe(Size(100.0, 300.0)))
    }.scrollState(innerOffset).scrollOptions(ScrollOptions.immediate())
    let outer = ScrollView(key: "nested.outer") {
        VStack {
            inner.height(100.0)
            emit(SizedLayoutProbe(Size(100.0, 400.0)))
        }
    }.scrollState(outerOffset).scrollOptions(ScrollOptions.immediate())
    outer.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))
    @Expect(outer.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    @Expect(innerOffset.value, Float32(72.0))
    @Expect(outerOffset.value, Float32(0.0))
    innerOffset.value = 200.0
    outer.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))
    @Expect(outer.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    @Expect(innerOffset.value, Float32(200.0))
    @Expect(outerOffset.value, Float32(72.0))
}

@Test
func verticalScrollViewDoesNotStealHorizontalZeroOrExhaustedWheel(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "direction") {
        emit(SizedLayoutProbe(Size(100.0, 300.0)))
    }.scrollState(offset).scrollOptions(ScrollOptions.immediate())
    view.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(1.0, 0.0, 30.0, 30.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, 0.0, 30.0, 30.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, 1.0, 30.0, 30.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(5.0, -1.0, 30.0, 30.0)))
    @Expect(offset.value, Float32(0.0))
}

@Test
func adaptiveScrollUsesBothGuttersAndClampsOnResize(): Unit {
    let ctx = testContext()
    let x = State<Float32>(0.0)
    let y = State<Float32>(0.0)
    let child = SizedLayoutProbe(Size(400.0, 95.0))
    let view = ScrollView(key: "adaptive") { emit(child) }.horizontalContent(400.0)
        .horizontalScrollState(x).scrollState(y).scrollOptions(ScrollOptions.immediate())
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(-1.0, 0.0, 30.0, 30.0)))
    @Expect(x.value, Float32(72.0))
    @Expect(y.value, Float32(0.0))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    @Expect(y.value, Float32(5.0))
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(child.rect.x, Float32(-72.0))
    @Expect(child.rect.y, Float32(-5.0))
    @Expect(child.rect.w, Float32(400.0))
    view.layout(ctx, Rect(0.0, 0.0, 500.0, 300.0))
    @Expect(x.value, Float32(0.0))
    @Expect(y.value, Float32(0.0))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(-1.0, 0.0, 30.0, 30.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
}

@Test
func adaptiveScrollKeepsVerticalDisabledWhenContentFits(): Unit {
    let ctx = testContext()
    let x = State<Float32>(0.0)
    let view = ScrollView(key: "short-horizontal") { emit(SizedLayoutProbe(Size(400.0, 40.0))) }
        .horizontalContent(400.0).horizontalScrollState(x).scrollOptions(ScrollOptions.immediate())
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(-1.0, -0.2, 20.0, 20.0)))
    @Expect(x.value, Float32(72.0))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(-1.0, 0.0, 220.0, 20.0)))
}

@Test
func adaptiveScrollPanLocksAxisSurvivesRebuildAndCancelsClick(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let x = State<Float32>(0.0)
    let y = State<Float32>(0.0)
    let clicks = State<Int64>(0)
    let body: () -> Unit = {=>
        ScrollView(key: "pan") {
            InteractionSurface(action: {=> clicks.value += 1}, key: Some("pan.button")) {
                emit(SizedLayoutProbe(Size(400.0, 300.0)))
            }
        }.horizontalContent(400.0).horizontalScrollState(x).scrollState(y).dragToScroll()
    }
    let first = buildRoot(body, store)
    first.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    ctx.leftMouseDown = true
    let _ = first.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 100.0, 80.0))
    @Expect(first.handle(ctx, UiEvent.MouseMove(60.0, 75.0)))
    @Expect(x.value, Float32(40.0))
    @Expect(y.value, Float32(0.0))
    let second = buildRoot(body, store)
    second.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    @Expect(second.handle(ctx, UiEvent.MouseMove(50.0, -20.0)))
    @Expect(x.value, Float32(50.0))
    @Expect(y.value, Float32(0.0))
    @Expect(second.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 50.0, -20.0)))
    @Expect(clicks.value, Int64(0))
    @Expect(ctx.pointerCaptureOwner().isEmpty())
    @Expect(ctx.dragId.isEmpty())
    // A later tap still reaches the child normally.
    let _ = second.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0))
    let _ = second.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0))
    @Expect(clicks.value, Int64(1))
}

@Test
func adaptiveScrollPanCancelReleasesCaptureAndStopsMoving(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "cancel-pan") { emit(SizedLayoutProbe(Size(100.0, 300.0))) }
        .scrollState(offset).dragToScroll()
    view.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))
    ctx.leftMouseDown = true
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 60.0, 80.0))
    @Expect(view.handle(ctx, UiEvent.MouseMove(58.0, 40.0)))
    @Expect(offset.value, Float32(40.0))
    let _ = view.handle(ctx, UiEvent.PointerCancelled)
    let _ = view.handle(ctx, UiEvent.MouseMove(58.0, 10.0))
    @Expect(offset.value, Float32(40.0))
    @Expect(ctx.pointerCaptureOwner().isEmpty())
    @Expect(ctx.dragId.isEmpty())
}

@Test
func smoothScrollAccumulatesWheelTargetsAndChainsWhenExhausted(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "smooth-target") { emit(SizedLayoutProbe(Size(100.0, 244.0))) }
        .scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    @Expect(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)))
    ctx.frame = FrameInfo(UInt64(1000), UInt64(1000))
    view.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))
    @Expect(offset.value, Float32(144.0))
}

@Test
func adaptiveScrollHorizontalThumbUsesTheSameLogicalOffset(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "h-thumb") { emit(SizedLayoutProbe(Size(400.0, 40.0))) }
        .horizontalContent(400.0).horizontalScrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 95.0)))
    ctx.leftMouseDown = true
    @Expect(view.handle(ctx, UiEvent.MouseMove(69.0, 95.0)))
    @Expect(offset.value, Float32(100.0))
}

@Test
func adaptiveScrollRejectsInvalidCanvasWidth(): Unit {
    let view = ScrollView(key: "invalid-canvas") {}
    for (width in [Float32(0.0), Float32(-1.0), Float32.NaN, Float32.Inf]) {
        var rejected = false
        try { view.horizontalContent(width) } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}
