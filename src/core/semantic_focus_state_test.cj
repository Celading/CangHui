package chui.core

import sdl.{Rect, Renderer}

private func drawSemanticFocusFrame(runtime: SemanticRuntime, root: Widget, ctx: UiContext): SemanticTreeSnapshot {
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    runtime.commitFrame()
}

@Test
func semanticStockFocusFollowsTheActualContextAcrossFrames(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=> VStack {
        Button("First", {=> ()}).key("first")
        Button("Second", {=> ()}).key("second")
    }}, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))
    let runtime = SemanticRuntime("focus")
    let initial = drawSemanticFocusFrame(runtime, root, ctx)
    @Expect(initial.node("first").getOrThrow().focused == Some(false))
    @Expect(initial.node("second").getOrThrow().focused == Some(false))

    @Expect(ctx.focusRegistered("first"))
    let first = drawSemanticFocusFrame(runtime, root, ctx)
    @Expect(first.node("first").getOrThrow().focused == Some(true))
    @Expect(first.node("second").getOrThrow().focused == Some(false))
    @Expect(runtime.diff(initial).changed.size, 1)

    @Expect(ctx.focusRegistered("second"))
    let second = drawSemanticFocusFrame(runtime, root, ctx)
    @Expect(second.node("first").getOrThrow().focused == Some(false))
    @Expect(second.node("second").getOrThrow().focused == Some(true))
    @Expect(runtime.diff(first).changed.size, 2)
}

@Test
func semanticFocusPreservesExplicitAndContextlessContracts(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.adoptFocusRing(["explicit", "legacy"])
    @Expect(ctx.focusRegistered("explicit"))
    let runtime = SemanticRuntime("custom")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=>
        recordControlSemantics(ctx, Rect.zero(), "Custom", ControlSemantics(
            "button", actionOwner: "explicit", focused: Some(false)))
        recordControlSemantics(ctx, Rect.zero(), "Custom", ControlSemantics(
            "label", actionOwner: "not-registered"))
        recordControlSemantics(Rect.zero(), "Custom", ControlSemantics(
            "button", actionOwner: "legacy"))
    })
    let tree = runtime.commitFrame()
    @Expect(tree.node("explicit").getOrThrow().focused == Some(false))
    @Expect(tree.node("not-registered").getOrThrow().focused.isNone())
    @Expect(tree.node("legacy").getOrThrow().focused.isNone())
}
