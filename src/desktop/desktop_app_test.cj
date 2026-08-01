package cui.desktop

@Test
func tickDeltaGuardsAgainstClockReset(): Unit {
    @Expect(tickDelta(UInt64(10), UInt64(25)), UInt64(15))
    @Expect(tickDelta(UInt64(25), UInt64(10)), UInt64(0))
}

@Test
func devicePacingUsesPresentForRenderedFramesAndLightIdlePolling(): Unit {
    let pacing = resolveFramePacing(None, true, UInt32(16), false)
    @Expect(framePacingUsesVSync(pacing))
    @Expect(resolvedFramePacingName(pacing), "device")
    @Expect(framePacingDelay(pacing, UInt64(0), true), UInt32(0))
    @Expect(framePacingDelay(pacing, UInt64(0), false), UInt32(1))
}

@Test
func kmodeDefaultsToUnboundedUnlessTheApplicationChoosesAPolicy(): Unit {
    let automatic = resolveFramePacing(None, true, UInt32(16), true)
    @Expect(resolvedFramePacingName(automatic), "unbounded")
    @Expect(!framePacingUsesVSync(automatic))
    @Expect(framePacingDelay(automatic, UInt64(0), true), UInt32(0))
    @Expect(framePacingDelay(automatic, UInt64(0), false), UInt32(1))

    let explicit = resolveFramePacing(Some(FramePacing.Fixed(UInt32(120))), true, UInt32(16), true)
    @Expect(resolvedFramePacingName(explicit), "fixed-120fps")
    @Expect(framePacingDelay(explicit, UInt64(3), true), UInt32(5))
    @Expect(framePacingDelay(explicit, UInt64(9), true), UInt32(0))
}

@Test
func disabledVsyncKeepsTheLegacyDelayWhenNoPolicyWasAdded(): Unit {
    let pacing = resolveFramePacing(None, false, UInt32(16), false)
    @Expect(resolvedFramePacingName(pacing), "legacy-delay-16ms")
    @Expect(framePacingDelay(pacing, UInt64(30), true), UInt32(16))
}

@Test
func invalidFixedFrameRatesFailClosed(): Unit {
    var zeroRejected = false
    try {
        let _ = resolveFramePacing(Some(FramePacing.Fixed(UInt32(0))), true, UInt32(16), false)
    } catch (_: IllegalArgumentException) {
        zeroRejected = true
    }
    @Expect(zeroRejected)

    var excessiveRejected = false
    try {
        let _ = resolveFramePacing(Some(FramePacing.Fixed(UInt32(1001))), true, UInt32(16), false)
    } catch (_: IllegalArgumentException) {
        excessiveRejected = true
    }
    @Expect(excessiveRejected)
}
