package canghui_motion_lab

import chui.*

@Test
func motionLabFamiliesAreReachableByKeyboardAndKeepReplayState(): Unit {
    for (index in 0..5) {
        let state = MotionLabState()
        let report = ComponentProbe("motion-navigation", width: 1060.0, height: 820.0,
            theme: motionLabTheme(state)).run("focus family-${index}\nkey Enter\nfocus replay\nkey Enter\nadvance 2000\nassert activation replay 1") {
            motionLabView(state)
        }
        @Expect(report.contains("\"ok\":true"))
        @Expect(state.family.value, index)
        @Expect(state.replay.value, UInt64(1))
    }
}

@Test
func motionLabBreakpointsThemesAndReducedMotionRemainReplayable(): Unit {
    for (width in [Float32(390.0), Float32(760.0), Float32(1060.0), Float32(1600.0)]) {
        for (index in 0..5) {
            for (dark in [false, true]) {
                let state = MotionLabState()
                state.width.value = width; state.family.value = index
                state.dark.value = dark; state.reduced.value = true
                let report = ComponentProbe("motion-layout", width: width, height: 900.0,
                    theme: motionLabTheme(state)).run("focus replay\nkey Enter\nadvance 2000") {
                    motionLabView(state)
                }
                @Expect(report.contains("\"ok\":true"))
                @Expect(!report.contains("nested-interaction-owner"))
                @Expect(!report.contains("NaN"))
            }
        }
    }
}

@Test
func motionLabDigitBoundaryAndIntegerLimitStayExact(): Unit {
    let state = MotionLabState()
    state.family.value = 1
    let report = ComponentProbe("motion-digits", width: 390.0, height: 900.0,
        theme: motionLabTheme(state)).run(
        "focus digits\nkey Enter\nadvance 80\nkey Enter\nadvance 80\nfocus integer-limit\nkey Enter\nadvance 2000") {
        motionLabView(state)
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(state.number.value, Int64.Max)
    @Expect(report.contains("9223372036854775807"))
}
