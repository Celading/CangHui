package cui.core

@Test
func themeInterpolationKeepsExactEndpoints(): Unit {
    let light = Theme.light()
    let dark = Theme.dark()
    @Expect(light.lerp(dark, 0.0).bg.r, light.bg.r)
    @Expect(light.lerp(dark, 1.0).bg.r, dark.bg.r)
    @Expect(light.lerp(dark, 1.0).text.b, dark.text.b)
}

@Test
func themeTransitionAdvancesAndCompletesDeterministically(): Unit {
    let transition = ThemeTransition(Theme.dark(), Theme.light(), 40.0, 40.0, durationMs: UInt64(100))
    let halfway = transition.advance(UInt64(50))
    @Expect(transition.progress(), Float32(0.5))
    @Expect(!transition.isComplete())
    @Expect(halfway.bg.r > Theme.dark().bg.r)

    let complete = transition.advance(UInt64(80))
    @Expect(transition.isComplete())
    @Expect(complete.bg.r, Theme.light().bg.r)
}
