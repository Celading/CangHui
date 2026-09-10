package chui.core

import sdl.{Key, Rect, Size, UiEvent}

private class KeyboardLeaf <: Widget {
    let id: String
    var ordinary: Int64 = 0
    init(id: String) { this.id = id }
    public func focusableId(): ?String { Some(id) }
    public func measure(_: UiContext, _: Size): Size { Size(100.0, 30.0) }
    public func layout(_: UiContext, _: Rect): Unit { () }
    public func draw(_: UiContext): Unit { () }
    public func handle(_: UiContext, _: UiEvent): Bool { ordinary += 1; true }
}

private func prepareKeyboard(ctx: UiContext, root: Widget, ids: Array<String>): Unit {
    ctx.adoptFocusRing(ids)
    ctx.beginFrameSurfaceRegistration()
    root.layout(ctx, Rect(0.0, 0.0, 100.0, 30.0))
}

@Test
func keyboardCaptureIsOptInAndEscapeCannotBeConsumed(): Unit {
    let ctx = testContext()
    let leaf = KeyboardLeaf("terminal")
    let calls = State<Int64>(0)
    let root = leaf.captureKeyboard({_, _ => calls.value += 1; true})
    prepareKeyboard(ctx, root, ["before", "terminal", "after"])
    ctx.focus("terminal")
    @Expect(ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false)))
    @Expect(ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, true)))
    @Expect(ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab)))
    @Expect(calls.value, 3)
    @Expect(leaf.ordinary, 0)
    @Expect(ctx.focusId, "terminal")
    let _ = ctx.withEventModifiers(Some(UInt16(65)), {=>
        ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    })
    @Expect(ctx.focusId, "before")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, true))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(ctx.focusId, "before")
    @Expect(calls.value, 3)
    prepareKeyboard(ctx, root, ["terminal"])
    ctx.focus("terminal")
    let _ = ctx.withEventModifiers(Some(UInt16(64)), {=>
        ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    })
    @Expect(ctx.focusId, "")
}

@Test
func keyboardCaptureDeclineAndNonPhysicalEventsPreserveOrdinaryPolicy(): Unit {
    let ctx = testContext()
    let leaf = KeyboardLeaf("terminal")
    let calls = State<Int64>(0)
    let mask = State<UInt16>(0)
    let root = leaf.captureKeyboard({context, _ =>
        calls.value += 1; mask.value = context.keyModifiers().raw; false
    })
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("terminal")
    let _ = ctx.withEventModifiers(Some(UInt16(64)), {=>
        ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Letter(UInt8(67)), false))
    })
    @Expect(mask.value, UInt16(64))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Left, false))
    @Expect(calls.value, 2)
    @Expect(leaf.ordinary, 2)
    @Expect(!ctx.dispatchKeyboardEvent(root, UiEvent.TextInput("中é")))
    @Expect(calls.value, 2)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    @Expect(ctx.focusId, "next")
    @Expect(leaf.ordinary, 2)
    let _ = ctx.withEventModifiers(Some(UInt16(1)), {=>
        ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    })
    @Expect(ctx.focusId, "terminal")
}

@Test
func keyboardCaptureRebuildUsesLatestCallbackAndRejectsAmbiguousBindings(): Unit {
    let ctx = testContext()
    let oldCalls = State<Int64>(0)
    let newCalls = State<Int64>(0)
    let first = KeyboardLeaf("terminal").captureKeyboard({_, _ => oldCalls.value += 1; true})
    let second = KeyboardLeaf("terminal").captureKeyboard({_, _ => newCalls.value += 1; true})
    prepareKeyboard(ctx, first, ["terminal", "next"])
    ctx.focus("terminal")
    let _ = ctx.dispatchKeyboardEvent(first, UiEvent.KeyDown(Key.Tab, false))
    prepareKeyboard(ctx, second, ["terminal", "next"])
    let _ = ctx.dispatchKeyboardEvent(second, UiEvent.KeyDown(Key.Tab, true))
    let _ = ctx.dispatchKeyboardEvent(second, UiEvent.KeyUp(Key.Tab))
    @Expect(oldCalls.value, 1)
    @Expect(newCalls.value, 2)
    first.layout(ctx, Rect(0.0, 0.0, 100.0, 30.0))
    let _ = ctx.dispatchKeyboardEvent(second, UiEvent.KeyDown(Key.Tab, false))
    @Expect(ctx.focusId, "next")
    @Expect(newCalls.value, 2)
}

@Test
func keyboardCaptureBlurRemovalAndTransientOverlayRevokeHeldTab(): Unit {
    let ctx = testContext()
    let calls = State<Int64>(0)
    let root = KeyboardLeaf("terminal").captureKeyboard({_, _ => calls.value += 1; true})
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("terminal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    ctx.setKeyboardWindowActive(false)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Left, false))
    ctx.setKeyboardWindowActive(true)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, true))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 1)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    ctx.setOverlay(Overlay(handleEvent: {_, _ => true}, render: {_ => ()}, owner: "modal"))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Left, false))
    ctx.removeOverlay("modal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 2)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    prepareKeyboard(ctx, root, ["next"])
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("terminal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 3)
}

@Test
func keyboardCaptureRejectsHiddenDisabledOffViewportAndForeignFocus(): Unit {
    let ctx = testContext()
    let calls = State<Int64>(0)
    let leaf = KeyboardLeaf("terminal")
    let root = leaf.captureKeyboard({_, _ => calls.value += 1; true})
    for (widget in [leaf.visible(false).captureKeyboard({_, _ => calls.value += 1; true}),
        leaf.enabled(false).captureKeyboard({_, _ => calls.value += 1; true}),
        root.visible(false), root.enabled(false)]) {
        prepareKeyboard(ctx, widget, [])
        ctx.focus("terminal")
        let _ = ctx.dispatchKeyboardEvent(widget, UiEvent.KeyDown(Key.Tab, false))
    }
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("next")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Left, false))
    ctx.viewportWidth = 100.0; ctx.viewportHeight = 50.0
    ctx.beginFrameSurfaceRegistration()
    root.layout(ctx, Rect(150.0, 0.0, 100.0, 30.0))
    ctx.focus("terminal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    @Expect(calls.value, 0)
}

@Test
func keyboardCaptureAltGrDoesNotTriggerEscapeAndFocusChangeDropsHeldRepeat(): Unit {
    let ctx = testContext()
    let calls = State<Int64>(0)
    let root = KeyboardLeaf("terminal").captureKeyboard({context, _ =>
        calls.value += 1
        @Expect(context.keyModifiers().alt)
        true
    })
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("terminal")
    let _ = ctx.withEventModifiers(Some(UInt16(320)), {=>
        ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    })
    @Expect(ctx.focusId, "terminal")
    ctx.focus("next"); ctx.focus("terminal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, true))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 1)
}

@Test
func keyboardCaptureCannotReviveOwnershipInsideCallbackOrReceiveTraversalRelease(): Unit {
    let ctx = testContext()
    let calls = State<Int64>(0)
    let root = KeyboardLeaf("terminal").captureKeyboard({context, _ =>
        calls.value += 1
        context.focus("next")
        context.focus("terminal")
        context.setOverlay(Overlay(handleEvent: {_, _ => true}, render: {_ => ()}, owner: "transient"))
        context.removeOverlay("transient")
        true
    })
    prepareKeyboard(ctx, root, ["terminal", "next"])
    ctx.focus("next")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    @Expect(ctx.focusId, "terminal")
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 0)
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, false))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyDown(Key.Tab, true))
    let _ = ctx.dispatchKeyboardEvent(root, UiEvent.KeyUp(Key.Tab))
    @Expect(calls.value, 1)
}
