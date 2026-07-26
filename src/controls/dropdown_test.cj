package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func dropdownOpensThenSelectsAnItemViaTheOverlay(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(["浅色", "深色", "跟随系统"], selected, key: "theme")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    // A click opens it; drawing registers the popup as the interactive overlay.
    @Expect(dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    dropdown.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The popup sits below the box; y=120 lands on the second row. The overlay consumes the
    // click, selects it and closes.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 120.0)))
    @Expect(selected.value, Int64(1))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownDismissesOnOutsideClickAndEscape(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(1)
    let dropdown = Dropdown(["A", "B", "C"], selected, key: "d2")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0))) // outside the popup
    @Expect(selected.value, Int64(1)) // unchanged
    @Expect(!ctx.hasOverlay())

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownArrowsMoveHighlightWhileOpen(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(["A", "B", "C"], selected, key: "d3")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))
    @Expect(ctx.hasOverlay()) // arrows do not close the popup
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)) // clamps at the last item
    @Expect(selected.value, Int64(2))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))
    @Expect(selected.value, Int64(1))
}

// A dropdown inside a modal dialog — the nesting the overlay stack exists for. The popup
// registers above the dialog and wins its clicks; selecting closes only the popup, and the
// dialog dismisses on a later Escape.
@Test
func dropdownInsideModalSelectsWithoutClosingDialog(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 400.0
    let presented = State<Bool>(true)
    let selected = State<Int64>(0)
    let modal = Modal(presented) {
        Dropdown(["北京", "上海", "广州"], selected, key: "city")
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.overlayCount(), Int64(1))

    // The dropdown measures 190x34, so the dialog centres at (83,161,234,78) and the control
    // sits at (105,183,190,34). A press inside, routed through the dialog, opens the popup;
    // drawing the stack registers it above the dialog within the same frame.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 110.0, 190.0)))
    ctx.drawActiveOverlay()
    @Expect(ctx.overlayCount(), Int64(2))

    // The popup opens below the box at (105,221); rows start at y=226, 28px each, so y=260
    // lands on the second item. Selecting closes the popup only — the dialog stays open.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 120.0, 260.0)))
    @Expect(selected.value, Int64(1))
    @Expect(ctx.overlayCount(), Int64(1))
    @Expect(presented.value)

    // With the popup gone, Escape reaches the dialog and dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!presented.value)
    @Expect(!ctx.hasOverlay())
}

// A long list scrolls inside the popup: the wheel moves the window, hit-testing follows the
// offset, keyboard navigation keeps the highlight visible, and the padding strips hit nothing.
@Test
func dropdownLongListScrollsInsidePopup(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 300.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(Array<String>(30, {i => "项 ${i}"}), selected, key: "long")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    // Below the control there are 218px, above only 32px: the popup opens below at 218px
    // (20,78,180,218) and the 840px list scrolls inside a 208px window.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.hasOverlay())

    // One wheel notch scrolls 72px; a click at y=88 then lands on row (88-83+72)/28 = 2.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseWheel(0.0, -1.0, 100.0, 150.0)))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 88.0)))
    @Expect(selected.value, Int64(2))
    @Expect(!ctx.hasOverlay())

    // Reopen (row 2 reveals near the top, unscrolled); a press in the top padding strip
    // (y=80 < 83) hits nothing — the popup dismisses without changing the selection.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 80.0)))
    @Expect(selected.value, Int64(2))
    @Expect(!ctx.hasOverlay())

    // Reopen and walk down with the keyboard: the window scrolls to keep the highlight
    // visible. After reaching row 12 the offset is 12*28+28-208 = 156, so a click near the
    // top of the list (y=84) lands on row (84-83+156)/28 = 5 — not row 0.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    var presses = 0
    while (presses < 10) {
        let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
        presses += 1
    }
    @Expect(selected.value, Int64(12))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 84.0)))
    @Expect(selected.value, Int64(5))
    @Expect(!ctx.hasOverlay())
}

// The popup scrollbar rides in the standard right-edge lane: grabbing the thumb neither
// selects nor closes, and dragging it scrolls the window.
@Test
func dropdownPopupScrollbarDragsAndStaysOpen(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 300.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(Array<String>(30, {i => "row ${i}"}), selected, key: "bar")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)

    // The bar lane hugs the popup's right edge (x in 192..198); the thumb starts at the top.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 195.0, 90.0)))
    @Expect(ctx.hasOverlay()) // grabbing the bar neither selects nor closes
    ctx.leftMouseDown = true
    @Expect(ctx.dispatchOverlay(UiEvent.MouseMove(195.0, 200.0)))
    ctx.leftMouseDown = false
    ctx.clearDrag()

    // After the drag a click near the top of the list lands deep in the list, proving the
    // window scrolled (offset ≈ 453 → row 16); an unscrolled window would select row 0.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 90.0)))
    @Expect(selected.value > Int64(5))
    @Expect(!ctx.hasOverlay())
}

// A column's custom cell painter replaces its text rendering: it runs once per visible row
// inside the cell clip, receives the original row index paired with that row's value, and
// sorting still reorders by the string value under the column's numeric rule.
