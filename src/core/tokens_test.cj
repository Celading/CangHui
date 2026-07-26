package cui.core

@Test
func spacingScaleAscendsOnAGrid(): Unit {
    @Expect(Spacing.none.value, Float32(0.0))
    // Strictly ascending steps.
    @Expect(Spacing.xs.value < Spacing.sm.value)
    @Expect(Spacing.sm.value < Spacing.md.value)
    @Expect(Spacing.md.value < Spacing.lg.value)
    @Expect(Spacing.lg.value < Spacing.xl.value)
    @Expect(Spacing.xl.value < Spacing.xxl.value)
    // Known 4px-grid values, expressed in virtual pixels.
    @Expect(Spacing.md.value, Float32(12.0))
    @Expect(Spacing.lg.value, Float32(16.0))
    match (Spacing.md.unit) {
        case LengthUnit.Vp => ()
        case _ => @Fail("Spacing steps should be in virtual pixels")
    }
}

@Test
func radiiScaleAscendsAndPillIsLarge(): Unit {
    @Expect(Radii.none, Float32(0.0))
    @Expect(Radii.sm < Radii.md)
    @Expect(Radii.md < Radii.lg)
    @Expect(Radii.lg < Radii.xl)
    // pill is large enough that the renderer's clamp to half the shorter side fully rounds the ends.
    @Expect(Radii.pill > Radii.xl)
    @Expect(Radii.pill > Float32(1000.0))
}

@Test
func motionDurationsAscend(): Unit {
    @Expect(Motion.fast < Motion.normal)
    @Expect(Motion.normal < Motion.slow)
    @Expect(Motion.fast, UInt64(120))
    @Expect(Motion.normal, UInt64(220))
}

@Test
func motionEasingsAreUsableCurves(): Unit {
    // Each motion easing is a real curve anchored at the endpoints (emphasized overshoots in between).
    for (curve in [Motion.standard, Motion.decelerate, Motion.accelerate, Motion.emphasized]) {
        @Expect(curve.ease(0.0) < 0.01)
        @Expect(curve.ease(1.0) > 0.99)
    }
    // The emphasized curve overshoots past 1 before settling.
    @Expect(Motion.emphasized.ease(0.7) > 1.0)
}
