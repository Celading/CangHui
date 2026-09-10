package chui.core

import sdl.{Color, FrameInfo, MouseButton, Rect, Renderer, Size, UiEvent}

private class PropertyLayoutProbe <: Widget {
    var frame = Rect.zero()
    var presses: Int64 = 0
    init() { emit(this) }
    public func measure(_: UiContext, available: Size): Size { Size(min(20.0, available.w), min(20.0, available.h)) }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) where frame.contains(x, y) => presses += 1; true
            case _ => false
        }
    }
}

private class PropertyCapture {
    var leaf: ?PropertyLayoutProbe = None
    var styled: ?Widget = None
}

private func propertyFixture(store: StateStore, capture: PropertyCapture, width: Float32,
    padding!: Float32 = 0.0, key!: String = "property-fixture"): Widget {
    buildRoot({=>
        let leaf = PropertyLayoutProbe()
        capture.leaf = Some(leaf)
        leaf.padding(padding).width(width).height(60.0)
            .animateProperties(key, AnimationSpec(duration: UInt64(100), easing: Easing.Linear))
    }, store)
}

private func placePropertyFixture(ctx: UiContext, widget: Widget): Size {
    let size = widget.measure(ctx, Size(500.0, 200.0))
    widget.layout(ctx, Rect(0.0, 0.0, size.w, size.h))
    widget.draw(ctx)
    size
}

@Test
func propertyMotionStartsSettledAndIgnoresIdleDeltaOnRetarget(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let capture = PropertyCapture()
    ctx.frame = FrameInfo(UInt64(0), UInt64(0))
    let first = propertyFixture(store, capture, 100.0)
    @Expect(placePropertyFixture(ctx, first).w, Float32(100.0))
    @Expect(!ctx.takeFrameRequest())
    ctx.frame = FrameInfo(UInt64(5000), UInt64(5000))
    let changed = propertyFixture(store, capture, 200.0)
    @Expect(placePropertyFixture(ctx, changed).w, Float32(100.0))
    @Expect(ctx.takeFrameRequest())
    ctx.frame = FrameInfo(UInt64(5050), UInt64(50))
    @Expect(placePropertyFixture(ctx, changed).w, Float32(150.0))
    // A second measure, layout, draw and design inspection must not advance the clock again.
    changed.designComputedFacts(ctx)
    @Expect(placePropertyFixture(ctx, changed).w, Float32(150.0))
    @Expect(capture.leaf.getOrThrow().frame.w, Float32(150.0))
    @Expect(ctx.takeFrameRequest())
    ctx.frame = FrameInfo(UInt64(5100), UInt64(50))
    @Expect(placePropertyFixture(ctx, changed).w, Float32(200.0))
    @Expect(!ctx.takeFrameRequest())
}

@Test
func propertyMotionRetargetsFromVisibleValueAndHitTestingFollowsIt(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let capture = PropertyCapture()
    placePropertyFixture(ctx, propertyFixture(store, capture, 100.0))
    let expanded = propertyFixture(store, capture, 200.0)
    placePropertyFixture(ctx, expanded)
    ctx.frame = FrameInfo(UInt64(50), UInt64(50))
    @Expect(placePropertyFixture(ctx, expanded).w, Float32(150.0))
    @Expect(!expanded.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 180.0, 20.0)))
    @Expect(expanded.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 20.0)))
    let reversed = propertyFixture(store, capture, 50.0)
    @Expect(placePropertyFixture(ctx, reversed).w, Float32(150.0))
    ctx.frame = FrameInfo(UInt64(100), UInt64(50))
    @Expect(placePropertyFixture(ctx, reversed).w, Float32(100.0))
    @Expect(!reversed.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 20.0)))
}

@Test
func propertyPaddingSharesOneMeasuredAndPaintedGeometry(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let capture = PropertyCapture()
    placePropertyFixture(ctx, propertyFixture(store, capture, 200.0))
    let changed = propertyFixture(store, capture, 200.0, padding: 20.0)
    placePropertyFixture(ctx, changed)
    ctx.frame = FrameInfo(UInt64(50), UInt64(50))
    placePropertyFixture(ctx, changed)
    let rect = capture.leaf.getOrThrow().frame
    @Expect(rect.x, Float32(10.0))
    @Expect(rect.y, Float32(10.0))
    @Expect(rect.w, Float32(180.0))
    @Expect(rect.h, Float32(40.0))
    changed.designComputedFacts(ctx)
    @Expect(placePropertyFixture(ctx, changed).w, Float32(200.0))
    @Expect(capture.leaf.getOrThrow().frame.x, rect.x)
}

@Test
func propertyMotionSnapsReducedMotionEvenWithExplicitDelayAndPrunesOnUnmount(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    let motion = ModifierPropertyMotion()
    let spec = AnimationSpec(duration: UInt64(100), delay: UInt64(500))
    @Expect(motion.scalar(ctx, 0, 10.0, spec), Float32(10.0))
    @Expect(motion.scalar(ctx, 0, 90.0, spec), Float32(90.0))
    @Expect(!ctx.takeFrameRequest())
    let normal = testContext()
    let store = StateStore()
    let capture = PropertyCapture()
    placePropertyFixture(normal, propertyFixture(store, capture, 100.0))
    buildRoot({=> Label("Unmount")}, store)
    @Expect(placePropertyFixture(normal, propertyFixture(store, capture, 300.0)).w, Float32(300.0))
    @Expect(!normal.takeFrameRequest())
}

@Test
func propertyColorRadiusAndBorderChannelsAreIndependent(): Unit {
    let ctx = testContext()
    let motion = ModifierPropertyMotion()
    let spec = AnimationSpec(duration: UInt64(100), easing: Easing.Linear)
    motion.color(ctx, Color(0, 40, 80, 0), spec)
    motion.scalar(ctx, 4, 0.0, spec)
    motion.scalar(ctx, 5, 0.0, spec)
    motion.color(ctx, Color(200, 140, 180, 200), spec)
    motion.scalar(ctx, 4, 20.0, spec)
    motion.scalar(ctx, 5, 4.0, spec)
    ctx.frame = FrameInfo(UInt64(50), UInt64(50))
    let color = motion.color(ctx, Color(200, 140, 180, 200), spec)
    @Expect(color.r, UInt8(100))
    @Expect(color.g, UInt8(90))
    @Expect(color.b, UInt8(130))
    @Expect(color.a, UInt8(100))
    @Expect(motion.scalar(ctx, 4, 20.0, spec), Float32(10.0))
    @Expect(motion.scalar(ctx, 5, 4.0, spec), Float32(2.0))
    @Expect(motion.color(ctx, Color(200, 140, 180, 200), spec).r, color.r)
}

@Test
func propertyAnimationOnlyTouchesPrecedingModifiersAndSeparateKeys(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let capture = PropertyCapture()
    placePropertyFixture(ctx, propertyFixture(store, capture, 100.0, key: "first"))
    @Expect(placePropertyFixture(ctx, propertyFixture(store, capture, 300.0, key: "other")).w, Float32(300.0))
    let root = buildRoot({=> Label("Immediate").animateProperties("leaf").width(400.0)}, store)
    @Expect(root.measure(ctx, Size(500.0, 100.0)).w, Float32(400.0))
}

@Test
func propertyMotionKeepsDelayAndParentConstraints(): Unit {
    let ctx = testContext()
    let motion = ModifierPropertyMotion()
    let spec = AnimationSpec(duration: UInt64(100), delay: UInt64(50), easing: Easing.Linear)
    motion.scalar(ctx, 0, 100.0, spec)
    motion.scalar(ctx, 0, 200.0, spec)
    ctx.frame = FrameInfo(UInt64(50), UInt64(50))
    @Expect(motion.scalar(ctx, 0, 200.0, spec), Float32(100.0))
    ctx.frame = FrameInfo(UInt64(100), UInt64(50))
    @Expect(motion.scalar(ctx, 0, 200.0, spec), Float32(150.0))
    let store = StateStore()
    let capture = PropertyCapture()
    let root = propertyFixture(store, capture, 300.0)
    @Expect(root.measure(ctx, Size(80.0, 100.0)).w, Float32(80.0))
}

@Test
func propertyMinAndMaxConstraintsInterpolateWithoutStretchingTheChild(): Unit {
    for (isMinimum in [true, false]) {
        let ctx = testContext()
        let store = StateStore()
        let limit = State<Float32>(if (isMinimum) {100.0} else {20.0})
        let body = {=>
            let leaf = PropertyLayoutProbe()
            let constrained: Widget = if (isMinimum) {leaf.minWidth(limit.value)} else {leaf.maxWidth(limit.value)}
            constrained.animateProperties("constraint", AnimationSpec(duration: UInt64(100), easing: Easing.Linear))
            ()
        }
        placePropertyFixture(ctx, buildRoot(body, store))
        limit.value = if (isMinimum) {200.0} else {10.0}
        let changed = buildRoot(body, store)
        placePropertyFixture(ctx, changed)
        ctx.frame = FrameInfo(UInt64(50), UInt64(50))
        @Expect(placePropertyFixture(ctx, changed).w, if (isMinimum) {Float32(150.0)} else {Float32(15.0)})
    }
}

@Test
func propertyBorderFactsDoNotResolveLogicalRadiusAsPhysicalPixelsAgain(): Unit {
    let ctx = testContext()
    ctx.displayScale = 2.0
    let store = StateStore()
    let capture = PropertyCapture()
    let root = buildRoot({=>
        let styled = Label("Retina").width(200.px).border(Color.rgb(20, 40, 60), width: 2.0, radius: 20.vp)
            .animateProperties("retina")
        capture.styled = Some(styled)
    }, store)
    @Expect(root.measure(ctx, Size(500.0, 100.0)).w, Float32(100.0))
    var found = false
    // buildRoot adds a semantic scope; inspect the modifier node, not that scope wrapper.
    for (fact in capture.styled.getOrThrow().designComputedFacts(ctx)) {
        if (fact.name == "border.corner-radius") {
            @Expect(fact.value, Float32(20.0).toString())
            found = true
        }
    }
    @Expect(found)
}
