package chui.core

import sdl.{Renderer, Size}

@Test
func baseStyleRemainsIndependentAndIntrinsicInTallContainers(): Unit {
    for (theme in [Theme.light(), Theme.dark()]) {
        let ctx = UiContext(Renderer.headless(), theme)
        let button = Button("Continue", {=> ()})
        let size = button.measure(ctx, Size(600.0, 700.0))
        @Expect(size.h, Float32(38.0))
        @Expect(size.w < Float32(600.0))
        @Expect(theme.components.buttonStyle.isNone())
        @Expect(theme.components.buttonLayout.minHeight, Float32(38.0))
        @Expect(theme.components.buttonLayout.minWidth, Float32(72.0))
        @Expect(theme.withReduceMotion(true).reduceMotion)
        @Expect(theme.withReduceMotion(true).components.buttonStyle.isNone())
        @Expect(theme.withReduceMotion(true).text.r, theme.text.r)
    }
}

@Test
func controlDensityRecipesKeepStableInteractionBounds(): Unit {
    let compact = ControlDensity.Compact.buttonLayout()
    let comfortable = ControlDensity.Comfortable.buttonLayout()
    let touch = ControlDensity.Touch.buttonLayout()

    @Expect(ControlDensity.Compact.minimumHitTarget(), Float32(32.0))
    @Expect(ControlDensity.Comfortable.minimumHitTarget(), Float32(38.0))
    @Expect(ControlDensity.Touch.minimumHitTarget(), Float32(44.0))
    @Expect(compact.minWidth, Float32(64.0))
    @Expect(compact.minHeight, Float32(32.0))
    @Expect(compact.iconOnlySize, Float32(32.0))
    @Expect(comfortable.minWidth, Float32(72.0))
    @Expect(comfortable.minHeight, Float32(38.0))
    @Expect(touch.minWidth, Float32(80.0))
    @Expect(touch.minHeight, Float32(44.0))
    @Expect(touch.iconOnlySize, Float32(44.0))
}

@Test
func baseDisabledCommandCannotActivateAcrossThemes(): Unit {
    for (theme in [Theme.light(), Theme.dark()]) {
        let calls = State<Int64>(0)
        let report = ComponentProbe("base-disabled", width: 320.0, height: 80.0, theme: theme).run(
            "press 30 20\nrelease 30 20\nassert activation save 0") {
            Button("Saving...", probedAction("save", {=> calls.value += 1})).key("save").enabled(false)
        }
        @Expect(report.contains("\"ok\":true"))
        @Expect(calls.value, Int64(0))
        @Expect(report.contains("\"disabled\":\"true\""))
    }
}
