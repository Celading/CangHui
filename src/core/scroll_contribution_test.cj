package chui.core

import sdl.{Rect, Renderer, Size, UiEvent}

private class InsetChild <: Widget {
    var rect = Rect.zero()
    public func measure(_: UiContext, size: Size): Size { Size(size.w, 300.0) }
    public func layout(_: UiContext, value: Rect): Unit { rect = value }
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func scrollbarInsetIsOptInAndOnlyReservesOverflowLane(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let child = InsetChild()
    let view = ScrollView(key: "inset") {emit(child)}
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(child.rect.w, Float32(110.0))
    let _ = view.scrollOptions(ScrollOptions.immediate(contentInset: 12.0))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(child.rect.w, Float32(98.0))
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 400.0))
    @Expect(child.rect.w, Float32(120.0))
    @Expect(ScrollOptions.web().contentInset, Float32(0.0))
    @Expect(ScrollOptions.web(contentInset: 12.0).contentInset, Float32(12.0))
}

@Test
func lazyScrollInsetsUseTheCrossAxis(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let child = InsetChild()
    let column = LazyColumn(20, 40.0, id: "column-inset") {_ => emit(child)}
        .scrollOptions(ScrollOptions(contentInset: 12.0))
    column.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(child.rect.w, Float32(98.0))
    let row = LazyRow(20, 40.0, id: "row-inset") {_ => emit(child)}
        .scrollOptions(ScrollOptions(contentInset: 12.0))
    row.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(child.rect.h, Float32(78.0))
}

@Test
func reachEndCoalescesAndRearmsOnlyForNewDemand(): Unit {
    let gate = LazyReachEndGate()
    @Expect(gate.schedule(0, 0, true, false, true))
    @Expect(gate.take(0, 0, false, true))
    @Expect(!gate.take(0, 0, false, true))
    @Expect(!gate.schedule(0, 0, true, false, true))
    @Expect(gate.schedule(10, 0, true, false, true))
    @Expect(gate.take(10, 0, false, true))
    @Expect(gate.schedule(10, 1, true, false, true))
    @Expect(gate.take(10, 1, false, true))
    @Expect(!gate.schedule(10, 1, false, false, true))
    @Expect(gate.schedule(10, 1, true, false, true))
}

@Test
func reachEndRespectsLoadingExhaustionAndStaleFrames(): Unit {
    let gate = LazyReachEndGate()
    @Expect(!gate.schedule(0, 0, true, true, true))
    @Expect(!gate.schedule(0, 0, true, false, false))
    @Expect(gate.schedule(0, 0, true, false, true))
    @Expect(!gate.take(0, 0, true, true))
    @Expect(gate.schedule(0, 0, true, false, true))
    @Expect(!gate.take(1, 0, false, true))
    @Expect(gate.schedule(1, 0, true, false, true))
    @Expect(!gate.take(1, 0, false, false))
}

@Test
func reachEndRunsOnFrameNotLayoutAndDoesNotSpin(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let calls = State<Int64>(0)
    let list = LazyColumn(0, 40.0, id: "load-more") {_ => ()}.onReachEnd {=> calls.value += 1}
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(calls.value, Int64(0))
    @Expect(ctx.takeFrameRequest())
    let _ = list.handle(ctx, UiEvent.Frame(ctx.frame))
    @Expect(calls.value, Int64(1))
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    let _ = list.handle(ctx, UiEvent.Frame(ctx.frame))
    @Expect(calls.value, Int64(1))
    @Expect(!ctx.takeFrameRequest())
}

@Test
func reachEndRetainsClaimAcrossRebuildAndUsesLatestCallback(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let store = StateStore()
    let calls = State<Int64>(0)
    let count = State<Int64>(0)
    let revision = State<Int64>(0)
    let body: () -> Unit = {=>
        LazyColumn(count.value, 40.0, id: "retained-load") {_ => ()}
            .onReachEnd(revision: revision.value) {=> calls.value += 1}
    }
    for (_ in 0..3) {
        let root = buildRoot(body, store)
        root.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
        let _ = root.handle(ctx, UiEvent.Frame(ctx.frame))
    }
    @Expect(calls.value, Int64(1))
    revision.value += 1
    let root = buildRoot({=>
        LazyColumn(0, 40.0, id: "retained-load") {_ => ()}
            .onReachEnd(revision: revision.value) {=> calls.value += 10}
    }, store)
    root.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    let _ = root.handle(ctx, UiEvent.Frame(ctx.frame))
    @Expect(calls.value, Int64(11))
}

@Test
func scrollContributionRejectsInvalidInputAndZeroViewport(): Unit {
    var insetRejected = false
    try { let _ = ScrollOptions(contentInset: -1.0) }
    catch (_: IllegalArgumentException) { insetRejected = true }
    @Expect(insetRejected)
    var thresholdRejected = false
    try { let _ = LazyColumn(0, 40.0, id: "invalid-end") {_ => ()}.onReachEnd(threshold: -1.0) {=> ()} }
    catch (_: IllegalArgumentException) { thresholdRejected = true }
    @Expect(thresholdRejected)
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let calls = State<Int64>(0)
    let list = LazyColumn(0, 40.0, id: "zero-end") {_ => ()}.onReachEnd {=> calls.value += 1}
    list.layout(ctx, Rect.zero())
    let _ = list.handle(ctx, UiEvent.Frame(ctx.frame))
    @Expect(calls.value, Int64(0))
}
