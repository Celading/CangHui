package chui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import chui.core.{ComponentProbe, State, Theme, UiContext}

@Test
func sliderRangeEndpointSurvivesSnappingAndKeyboardReturnsToAdjacentTick(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(10.0)
    let slider = Slider(value, key: "endpoint", lower: 0.0, upper: 10.0, step: 3.0)
    @Expect(value.value, Float32(10.0))
    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 108.0, 19.0)))
    @Expect(value.value, Float32(10.0))
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(9.0))
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(value.value, Float32(10.0))
    slider.step(3.0).range(0.0, 10.0)
    @Expect(value.value, Float32(10.0))
}

@Test
func sliderRangeConstructorMatchesReversedRangeSetter(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let directValue = State<Float32>(4.0)
    let chainedValue = State<Float32>(4.0)
    let direct = Slider(directValue, key: "direct", lower: 10.0, upper: -2.0, step: 3.0)
    let chained = Slider(chainedValue, key: "chained").range(10.0, -2.0).step(3.0)
    @Expect(directValue.value, chainedValue.value)
    direct.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    chained.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    direct.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0))
    chained.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0))
    @Expect(directValue.value, Float32(4.0))
    @Expect(directValue.value, chainedValue.value)
}

@Test
func sliderRangeHomeEndRequireFocusAndProbeRetainsEndpointAcrossRebuilds(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(3.0)
    let slider = Slider(value, key: "seek", lower: 0.0, upper: 10.0, step: 3.0)
    @Expect(!slider.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(value.value, Float32(3.0))
    ctx.focus("seek")
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(value.value, Float32(10.0))
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(value.value, Float32(0.0))
    let report = ComponentProbe("slider.endpoint", width: 300.0, height: 100.0)
        .run("focus seek\nkey End\nkey Left\nkey Right") {
            Slider(value, key: "seek", lower: 0.0, upper: 10.0, step: 3.0)
        }
    @Expect(!report.contains("\"ok\":false"))
    @Expect(value.value, Float32(10.0))
}

@Test
func sliderRangeOversizedStepAndZeroSpanKeepExactEndpoints(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(10.0)
    let slider = Slider(value, key: "large-step", lower: 0.0, upper: 10.0, step: 30.0)
    @Expect(value.value, Float32(10.0))
    ctx.focus("large-step")
    slider.handle(ctx, UiEvent.KeyDown(Key.Left, false))
    @Expect(value.value, Float32(0.0))
    slider.handle(ctx, UiEvent.KeyDown(Key.Right, false))
    @Expect(value.value, Float32(10.0))
    slider.range(2.0, 2.0)
    for (key in [Key.Left, Key.Right, Key.Home, Key.End]) {
        @Expect(slider.handle(ctx, UiEvent.KeyDown(key, false)))
        @Expect(value.value, Float32(2.0))
    }
}

@Test
func sliderRangeFractionalTicksAndContinuousReversedBounds(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<Float32>(1.5)
    let slider = Slider(value, key: "fraction", lower: -1.0, upper: 1.5, step: 0.75)
    ctx.focus("fraction")
    slider.handle(ctx, UiEvent.KeyDown(Key.Left, false))
    @Expect(value.value, Float32(1.25))
    slider.handle(ctx, UiEvent.KeyDown(Key.Right, false))
    @Expect(value.value, Float32(1.5))
    let continuous = Slider(value, key: "continuous", lower: 10.0, upper: -2.0)
    @Expect(value.value, Float32(1.5))
    continuous.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    continuous.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0))
    @Expect(value.value, Float32(4.0))
    ctx.leftMouseDown = true
    continuous.handle(ctx, UiEvent.MouseMove(208.0, 80.0))
    @Expect(value.value, Float32(10.0))
    continuous.handle(ctx, UiEvent.MouseUp(MouseButton.Left, -20.0, 80.0))
    @Expect(value.value, Float32(-2.0))
}

@Test
func sliderRangeDisabledOrHiddenCannotConsumeEndpointKeys(): Unit {
    for (disabled in [true, false]) {
        let value = State<Float32>(3.0)
        let report = ComponentProbe("slider.unavailable", width: 300.0, height: 100.0)
            .run("focus seek\nkey End\nkey Home") {
                let slider = Slider(value, key: "seek", lower: 0.0, upper: 10.0, step: 3.0)
                if (disabled) { slider.enabled(false) } else { slider.visible(false) }
            }
        @Expect(value.value, Float32(3.0))
        @Expect(report.contains("\"ok\":false"))
    }
}
