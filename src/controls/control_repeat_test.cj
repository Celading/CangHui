package chui.controls

import sdl.{IconName, Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{Button, IconButton, InteractionSurface, Label, State, Theme, UiContext, Widget}

@Test
func controlRepeatSliderNotifiesOnlyWhenItsValueChanges(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(6.0)
    let calls = State<Int64>(0)
    let observation = value.observe({_, _ => calls.value += 1})
    let slider = Slider(value, key: "volume", lower: 0.0, upper: 10.0, step: 3.0)
    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 68.0, 19.0))
    ctx.leftMouseDown = true
    for (x in [Float32(69.0), Float32(70.0), Float32(71.0)]) {
        slider.handle(ctx, UiEvent.MouseMove(x, 19.0))
    }
    slider.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 71.0, 19.0))
    @Expect(value.value, Float32(6.0))
    @Expect(value.revision, UInt64(0))
    @Expect(calls.value, Int64(0))
    slider.handle(ctx, UiEvent.KeyDown(Key.End, false))
    slider.handle(ctx, UiEvent.KeyDown(Key.End, true))
    slider.handle(ctx, UiEvent.KeyDown(Key.Right, true))
    @Expect(value.value, Float32(10.0))
    @Expect(calls.value, Int64(1))
    slider.handle(ctx, UiEvent.KeyDown(Key.Left, true))
    slider.handle(ctx, UiEvent.KeyDown(Key.Left, true))
    @Expect(value.value, Float32(6.0))
    @Expect(calls.value, Int64(3))
    observation.close()
}

@Test
func controlRepeatRadioDoesNotRewriteAnAlreadySelectedValue(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Int64>(2)
    let radio = RadioButton("Selected", value, 2).key("choice")
    radio.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))
    ctx.focus("choice")
    radio.handle(ctx, UiEvent.KeyDown(Key.Enter, false))
    radio.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 19.0))
    radio.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 19.0))
    @Expect(value.revision, UInt64(0))
}

@Test
func controlRepeatBooleanControlsToggleOncePerPress(): Unit {
    for (key in [Key.Enter, Key.Space]) {
        for (useSwitch in [true, false]) {
            let ctx = UiContext(Renderer.headless(), Theme.light())
            let value = State<Bool>(false)
            let control: Widget = if (useSwitch) {
                Switch("Option", value).key("option")
            } else {
                Checkbox("Option", value).key("option")
            }
            control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))
            @Expect(!control.handle(ctx, UiEvent.KeyDown(key, true)))
            ctx.focus("option")
            @Expect(control.handle(ctx, UiEvent.KeyDown(key, false)))
            for (_ in 0..4) { @Expect(control.handle(ctx, UiEvent.KeyDown(key, true))) }
            @Expect(value.value)
            @Expect(value.revision, UInt64(1))
            control.handle(ctx, UiEvent.KeyUp(key))
            @Expect(control.handle(ctx, UiEvent.KeyDown(key, false)))
            @Expect(!value.value)
            @Expect(value.revision, UInt64(2))
        }
    }
}

@Test
func controlRepeatButtonsDoNotRepeatActionsOrActivateAfterFocusMoves(): Unit {
    for (key in [Key.Enter, Key.Space]) {
        for (icon in [true, false]) {
            let ctx = UiContext(Renderer.headless(), Theme.light())
            let calls = State<Int64>(0)
            let control: Widget = if (icon) {
                IconButton(IconName.Save, onClick: {=> calls.value += 1}).key("save")
            } else {
                Button("Save", {=> calls.value += 1}).key("save")
            }
            control.layout(ctx, Rect(0.0, 0.0, 100.0, 38.0))
            ctx.focus("save")
            @Expect(control.handle(ctx, UiEvent.KeyDown(key, false)))
            for (_ in 0..4) { @Expect(control.handle(ctx, UiEvent.KeyDown(key, true))) }
            @Expect(calls.value, Int64(1))
            ctx.focus("other")
            @Expect(!control.handle(ctx, UiEvent.KeyDown(key, true)))
            ctx.focus("save")
            @Expect(control.handle(ctx, UiEvent.KeyDown(key, true)))
            @Expect(calls.value, Int64(1))
            @Expect(control.handle(ctx, UiEvent.KeyDown(key, false)))
            @Expect(calls.value, Int64(2))
        }
    }
}

@Test
func controlRepeatSurfaceGuardsAndDirectionalAdjustmentRemainDistinct(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let calls = State<Int64>(0)
    let surface = InteractionSurface(action: {=> calls.value += 1}, key: Some("surface")) {
        Label("Action")
    }
    ctx.focus("surface")
    @Expect(surface.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(surface.handle(ctx, UiEvent.KeyDown(Key.Enter, true)))
    @Expect(calls.value, Int64(1))
    let disabled = surface.enabled(false)
    @Expect(!disabled.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(!disabled.handle(ctx, UiEvent.KeyDown(Key.Enter, true)))
    @Expect(calls.value, Int64(1))
    let readonlySurface = InteractionSurface(action: {=> calls.value += 1},
        key: Some("readonly"), readOnly: true) { Label("Read only") }
    ctx.focus("readonly")
    @Expect(!readonlySurface.handle(ctx, UiEvent.KeyDown(Key.Space, true)))
    @Expect(calls.value, Int64(1))
    let amount = State<Int64>(0)
    let stepper = Stepper(amount, key: "stepper", lower: 0, upper: 3)
    ctx.focus("stepper")
    for (_ in 0..4) { @Expect(stepper.handle(ctx, UiEvent.KeyDown(Key.Right, true))) }
    @Expect(amount.value, Int64(3))
    @Expect(amount.revision, UInt64(3))
    // The State contract itself still permits explicit equal-value notifications.
    amount.value = 3
    @Expect(amount.revision, UInt64(4))
}
