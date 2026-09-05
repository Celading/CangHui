package canghui_kit

import chui.*

@Test
func kitHasExplicitDensityAndCommonSourceDescriptor(): Unit {
    @Expect(KitDensity.Compact.controlHeight(), Float32(32.0))
    @Expect(KitDensity.Comfortable.controlHeight(), Float32(38.0))
    @Expect(KitDensity.Touch.controlHeight(), Float32(44.0))
    @Expect(CangHuiKitPackage().descriptor().supportsPlatform(HostPlatform.HarmonyOS), true)
    @Expect(CangHuiKitPackage().descriptor().id, "canghui.kit")
}

@Test
func kitIntroProfilesChangeCompositionNotPalette(): Unit {
    @Expect(kitIntroLayout(KitIntroProfile.Editorial, 1000.0), "editorial-split")
    @Expect(kitIntroLayout(KitIntroProfile.Focused, 1000.0), "focused-stack")
    @Expect(kitIntroLayout(KitIntroProfile.Guided, 1000.0), "guided-split")
    @Expect(kitIntroLayout(KitIntroProfile.Editorial, 390.0), "editorial-stack")
    @Expect(kitIntroLayout(KitIntroProfile.Guided, 390.0), "guided-stack")
}

@Test
func kitChoiceHasOneActionAndReleaseKeyboardParity(): Unit {
    let selected = State<Bool>(false)
    let report = ComponentProbe("kit-choice", width: 360.0, height: 120.0).run(
        "press 30 30\nrelease 30 30\nfocus choice\nkey Enter\nassert activation choose 2") {
        kitChoiceCard("choice", "Local library", "Keep files on this device", selected.value,
            probedAction("choose", {=> selected.value = !selected.value}))
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"actionOwner\":\"choice\""))
    @Expect(!report.contains("nested-interaction-owner"))
    @Expect(!selected.value)
}

@Test
func kitSettingsToggleKeepsTextDecorativeAndSwitchFocusable(): Unit {
    let checked = State<Bool>(false)
    let report = ComponentProbe("kit-settings", width: 360.0, height: 120.0).run(
        "press 20 20\nrelease 20 20\nfocus setting\nkey Space") {
        kitSettingsToggle("setting", "Reduce motion", "Keep transitions immediate", checked)
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(checked.value)
    @Expect(report.contains("\"actionOwner\":\"setting\""))
    @Expect(!report.contains("nested-interaction-owner"))
}

@Test
func kitIntroBuildsEachSlotOnceAcrossAllProfilesAndWidths(): Unit {
    for (profile in [KitIntroProfile.Editorial, KitIntroProfile.Focused, KitIntroProfile.Guided]) {
        for (width in [Float32(390.0), Float32(1000.0)]) {
            let calls = [0, 0, 0]
            let context = ComponentContext(HostProfile(HostPlatform.Desktop), ViewportSpec("test", "Test", width, 800.0))
            let report = ComponentProbe("intro-slots", width: width, height: 800.0).run("") {
                kitIntro("intro", context, profile, "EXAMPLE", "One model, different compositions", "Summary",
                    visual: {=> calls[0] += 1; Label("Visual").height(180.vp)},
                    actions: {=> calls[1] += 1; kitAction("start", "Start", {=> ()})},
                    steps: {=> calls[2] += 1; kitStep(1, "Choose", "Pick a source")})
            }
            @Expect(report.contains("\"ok\":true"))
            @Expect(calls[0], calls[1])
            @Expect(calls[1], calls[2])
            @Expect(calls[0], 1)
            @Expect(report.contains(kitIntroLayout(profile, width)))
        }
    }
}
