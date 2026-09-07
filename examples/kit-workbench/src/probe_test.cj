package canghui_kit_workbench

import chui.*

@Test
func workbenchMotionAndPrimaryActionAreReplayable(): Unit {
    let report = editorialProbe("focus reshape\nkey Enter\nadvance 230\nassert activation reshape 1\nfocus start\nkey Enter\nassert activation start 1")
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("motion-card"))
    @Expect(report.contains("editorial-split"))
    @Expect(!report.contains("\"ok\":false"))
}

@Test
func workbenchWorkflowRetainsStateAcrossProfilesAndBreakpoints(): Unit {
    for (width in [Float32(320.0), Float32(390.0), Float32(759.0), Float32(760.0),
        Float32(839.0), Float32(840.0), Float32(1060.0)]) {
        for (profile in [0, 1, 2]) {
            for (dark in [false, true]) {
                let state = WorkbenchState()
                state.width.value = width
                state.profile.value = profile
                state.dark.value = dark
                let report = ComponentProbe("kit.full-flow", width: width, height: 900.0,
                    theme: workbenchTheme(state)).run(
                    "focus shared\nkey Enter\nfocus reshape\nkey Enter\nadvance 115\n" +
                    "focus reshape\nkey Enter\nadvance 460\nfocus profiles\n" +
                    (if (profile == 2) {"key Left\n"} else {"key Right\n"}) +
                    "focus start\nkey Enter\nassert activation reshape 2\nassert activation start 1") {
                    workbenchView(state)
                }
                @Expect(!report.contains("\"ok\":false"))
                @Expect(state.selected.value, 1)
                @Expect(state.starts.value, 1)
                @Expect(state.holds.value, 0)
                @Expect(!state.expanded.value)
                @Expect(state.profile.value != profile)
            }
        }
    }
}

@Test
func workbenchPointerHoldCancellationAndKeyboardShareOneActionModel(): Unit {
    let state = WorkbenchState()
    // Coordinates come from the 1060x900 editorial probe, not from a system screenshot.
    let report = ComponentProbe("kit.pointer-flow", width: 1060.0, height: 900.0,
        theme: workbenchTheme(state)).run(
        "press 200 390\nadvance 600\nrelease 200 390\nassert activation reshape 0\n" +
        "press 200 390\nmove-out 200 650\nrelease 200 650\nassert activation reshape 0\n" +
        "press 200 390\nrelease 200 390\nassert activation reshape 1\n" +
        "focus start\nkey Enter\nassert activation start 1") {
        workbenchView(state)
    }
    @Expect(!report.contains("\"ok\":false"))
    @Expect(state.holds.value, 1)
    @Expect(state.starts.value, 1)
    @Expect(state.expanded.value)
}
