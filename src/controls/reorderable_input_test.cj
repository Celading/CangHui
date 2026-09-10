package chui.controls

import chui.core.{Button, Label, SemanticRuntime, State, StateStore, Theme, UiContext, Widget,
    buildRoot, withActiveSemanticRuntime}
import sdl.{GamepadButton, GamepadConnectionState, GamepadDevice, Key, MouseButton, Rect, Renderer, UiEvent}

@Test
func reorderGripKeyboardCommitsOnlyAfterConfirmation(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let moved = State<String>("")
    let root = buildRoot({=>
        ReorderableList.of(["a", "b", "c"], 40.0, {a, b => moved.value = "${a}->${b}"},
            id: "playlist", key: {v => v}) {v => Label(v)}
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    @Expect(store.focusRing().size, 3)
    ctx.focus("ReorderableList:playlist:item:a:grip", viaKeyboard: true)
    @Expect(root.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(root.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(moved.value, "")
    @Expect(root.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(moved.value, "0->1")
}

private func reorderKey(root: Widget, ctx: UiContext, key: Key): Unit {
    let _ = root.handle(ctx, UiEvent.KeyDown(key, false))
}

@Test
func reorderGripKeyboardTargetSurvivesRebuildAndParentRelocation(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let moved = State<String>("")
    let body = {=> ReorderableList(3, 40.0, {from, to => moved.value = "${from}->${to}"},
        id: "relayout") {_ => Label("Row")}; () }
    var root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 100.0, 200.0, 150.0))
    ctx.focus("ReorderableList:relayout:item:0:grip")
    reorderKey(root, ctx, Key.Space)
    reorderKey(root, ctx, Key.Down)
    root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 300.0, 200.0, 150.0))
    reorderKey(root, ctx, Key.Enter)
    @Expect(moved.value, "0->1")
}

@Test
func reorderGripRejectsDuplicateKeysAndClearsBeforeCallbackFailure(): Unit {
    var duplicate = false
    try {
        ReorderableList(2, 40.0, {_, _ => ()}, key: {_ => "duplicate"}) {_ => Label("Row")}
    } catch (_: IllegalArgumentException) { duplicate = true }
    @Expect(duplicate)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let list = ReorderableList(2, 40.0, {_, _ => throw IllegalStateException("move failed")},
        id: "throw") {_ => Label("Row")}
    list.layout(ctx, Rect(0.0, 0.0, 100.0, 100.0))
    ctx.focus("ReorderableList:throw:item:0:grip")
    reorderKey(list, ctx, Key.Enter)
    reorderKey(list, ctx, Key.Down)
    var failed = false
    try { reorderKey(list, ctx, Key.Enter) }
    catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    @Expect(ctx.dragId, "")
    reorderKey(list, ctx, Key.Space)
    reorderKey(list, ctx, Key.Escape)
    @Expect(ctx.dragId, "")
}

@Test
func reorderGripPointerCannotCommitAfterExternalReorder(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let data = State<Array<String>>(["a", "b", "c"])
    let moves = State<Int64>(0)
    let body = {=> ReorderableList.of(data.value, 40.0, {_, _ => moves.value += 1},
        id: "pointer", key: {v => v}) {v => Label(v)}; () }
    var root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 0.0, 100.0, 150.0))
    ctx.leftMouseDown = true
    root.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 15.0, 15.0))
    root.handle(ctx, UiEvent.MouseMove(15.0, 110.0))
    data.value = ["b", "a", "c"]
    root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 0.0, 100.0, 150.0))
    root.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 15.0, 110.0))
    @Expect(moves.value, 0)
    @Expect(ctx.dragId, "")
}

@Test
func reorderGripRetainsKeyFocusAndCancelsChangedData(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let data = State<Array<String>>(["a", "b", "c"])
    let moves = State<Int64>(0)
    let body = {=> ReorderableList.of(data.value, 40.0, {from, to =>
        @Expect(from, 0)
        @Expect(to, 2)
        moves.value += 1
        data.value = ["b", "c", "a"]
    }, id: "keys", key: {v => v}) {v => Label(v)}; () }
    var root = buildRoot(body, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    let grip = "ReorderableList:keys:item:a:grip"
    ctx.focus(grip, viaKeyboard: true)
    reorderKey(root, ctx, Key.Space)
    reorderKey(root, ctx, Key.End)
    // A normal rebuild must preserve the uncommitted transaction.
    root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    reorderKey(root, ctx, Key.Enter)
    @Expect(moves.value, 1)
    root = buildRoot(body, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    @Expect(ctx.hasFocus(grip))
    @Expect(store.focusRing()[2], grip)
    reorderKey(root, ctx, Key.Space)
    reorderKey(root, ctx, Key.Home)
    data.value = ["a", "c"]
    root = buildRoot(body, store)
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    @Expect(ctx.dragId, "")
    root.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 15.0, 20.0))
    @Expect(moves.value, 1)
}

@Test
func reorderGripKeyboardCancelRepeatBlurAndDisabledRecover(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let moves = State<Int64>(0)
    let list = ReorderableList(3, 40.0, {_, _ => moves.value += 1}, id: "cancel") {_ => Label("Row")}
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    let grip = "ReorderableList:cancel:item:0:grip"
    ctx.focus(grip)
    reorderKey(list, ctx, Key.Space)
    list.handle(ctx, UiEvent.KeyDown(Key.Space, true))
    reorderKey(list, ctx, Key.Down)
    reorderKey(list, ctx, Key.Escape)
    @Expect(moves.value, 0)
    @Expect(ctx.dragId, "")
    reorderKey(list, ctx, Key.Space)
    reorderKey(list, ctx, Key.Down)
    ctx.focus("elsewhere")
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    @Expect(ctx.dragId, "")
    ctx.focus(grip)
    reorderKey(list, ctx, Key.Space)
    ctx.withInteractionsEnabled(false) {=> list.draw(ctx) }
    @Expect(ctx.dragId, "")
    @Expect(moves.value, 0)
    reorderKey(list, ctx, Key.Space)
    reorderKey(list, ctx, Key.Down)
    reorderKey(list, ctx, Key.Enter)
    @Expect(moves.value, 1)
}

@Test
func reorderGripGamepadHasOwnedCancelDisconnectAndRecovery(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let moves = State<Int64>(0)
    let list = ReorderableList(3, 40.0, {_, _ => moves.value += 1}, id: "pad") {_ => Label("Row")}
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    ctx.focus("ReorderableList:pad:item:0:grip")
    let press = {button: GamepadButton => list.handle(ctx, UiEvent.GamepadButtonDown(UInt32(7), button))}
    @Expect(press(GamepadButton.South))
    @Expect(press(GamepadButton.DPadDown))
    @Expect(!list.handle(ctx, UiEvent.GamepadButtonDown(UInt32(8), GamepadButton.South)))
    @Expect(press(GamepadButton.East))
    @Expect(moves.value, 0)
    press(GamepadButton.South)
    press(GamepadButton.DPadDown)
    list.handle(ctx, UiEvent.GamepadConnectionChanged(GamepadDevice(UInt32(7)), GamepadConnectionState.Disconnected))
    @Expect(ctx.dragId, "")
    @Expect(moves.value, 0)
    press(GamepadButton.South)
    press(GamepadButton.DPadDown)
    press(GamepadButton.South)
    @Expect(moves.value, 1)
}

@Test
func reorderGripSemanticsPublishActionableIdentityAndPreview(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let root = buildRoot({=>
        ReorderableList.of(["a", "b"], 40.0, {_, _ => ()}, id: "sem", key: {v => v}) {v =>
            Button(v, {=> ()}).key("content-${v}")
        }.accessibilityLabels({i => "Move track ${i + 1}"})
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))
    let grip = "ReorderableList:sem:item:a:grip"
    @Expect(store.focusRing()[0], grip)
    @Expect(store.focusRing()[1], "content-a")
    let runtime = SemanticRuntime("reorder")
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let initial = runtime.commitFrame().node(grip).getOrThrow()
    @Expect(initial.label, "Move track 1")
    @Expect(initial.actions.size, 2)
    ctx.focus(grip, viaKeyboard: true)
    reorderKey(root, ctx, Key.Enter)
    reorderKey(root, ctx, Key.Down)
    root.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))
    runtime.beginFrame()
    withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
    let preview = runtime.commitFrame().node(grip).getOrThrow()
    @Expect(preview.value, "2/2")
    @Expect(preview.selected.getOrThrow())
    @Expect(preview.frame.y, Float32(46.0))
    @Expect(preview.actions.size, 4)
}
