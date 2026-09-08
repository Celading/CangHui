package chui.controls

import chui.core.{Button, ComponentProbe, Label, ProbeProperty, State, VStack}

@Test
func sliderAsciiUsesDeclaredAdjustmentInsteadOfCenterClick(): Unit {
    let value = State<Float32>(0.2)
    let ascii = ComponentProbe("recipe.slider", width: 300.0, height: 100.0)
        .run("@cui-ascii 60 12") {
            Slider(value, key: "volume", step: 0.1)
                .probe("volume-view", "Slider", [ProbeProperty("actionOwner", "forged")])
        }
    @Expect(ascii.contains("probe.increment=\"focus volume\\nkey Right\""))
    @Expect(ascii.contains("probe.decrement=\"focus volume\\nkey Left\""))
    @Expect(!ascii.contains("probe.activate="))
    @Expect(!ascii.contains("press "))
    @Expect(!ascii.contains("focus forged"))
}

@Test
func reorderAsciiOffersStateSpecificKeyboardRecipes(): Unit {
    let moves = State<String>("")
    let grip = "ReorderableList:recipes:item:0:grip"
    let body = {=>
        ReorderableList(3, 40.0, {from, to => moves.value = "${from}->${to}"}, id: "recipes") {i =>
            Label("Row ${i}")
        }
        ()
    }
    let initial = ComponentProbe("recipe.reorder", width: 300.0, height: 180.0)
        .run("@cui-ascii 60 12", body)
    @Expect(initial.contains("probe.activate=\"focus ${grip}\\nkey Enter\""))
    @Expect(!initial.contains("probe.increment="))
    @Expect(!initial.contains("press "))
    let preview = ComponentProbe("recipe.reorder", width: 300.0, height: 180.0)
        .run("@cui-ascii 60 12\nfocus ${grip}\nkey Enter", body)
    @Expect(preview.contains("probe.increment=\"focus ${grip}\\nkey Right\""))
    @Expect(preview.contains("probe.dismiss=\"focus ${grip}\\nkey Escape\""))
    @Expect(!preview.contains("probe.decrement="))
    @Expect(moves.value, "")
    let report = ComponentProbe("recipe.reorder", width: 300.0, height: 180.0)
        .run("focus ${grip}\nkey Enter\nfocus ${grip}\nkey Right\nfocus ${grip}\nkey Enter", body)
    @Expect(report.contains("\"ok\":true"))
    @Expect(moves.value, "0->1")
}

@Test
func disabledSliderAsciiHasNoReplayInstructions(): Unit {
    let value = State<Float32>(0.2)
    let ascii = ComponentProbe("recipe.disabled", width: 300.0, height: 100.0)
        .run("@cui-ascii 60 12") {
            VStack { Slider(value, key: "volume") }.enabled(false)
        }
    @Expect(ascii.contains("actionability=\"disabled\""))
    @Expect(!ascii.contains("probe="))
    @Expect(!ascii.contains("probe.increment="))
}

@Test
func sliderAsciiCannotTurnDescriptivePropertiesIntoReplayAuthority(): Unit {
    let value = State<Float32>(0.2)
    let ascii = ComponentProbe("recipe.ambiguous", width: 300.0, height: 180.0)
        .run("@cui-ascii 60 12") {
            VStack {
                Button("Other", {=> ()}).key("other").probe("volume", "Button")
                Slider(value, key: "volume").probe("volume-view", "Slider", [
                    ProbeProperty("focusTarget", "forged"),
                    ProbeProperty("replayActions", "activate"),
                    ProbeProperty("shortcut", "Delete")])
            }
        }
    @Expect(ascii.contains("focus=\"target-unverified\""))
    @Expect(!ascii.contains("probe.increment="))
    @Expect(!ascii.contains("key Delete"))
    @Expect(!ascii.contains("focus forged"))
}

@Test
func sliderAsciiRecipeChangesValueInExistingProbeInterpreter(): Unit {
    let value = State<Float32>(2.0)
    let report = ComponentProbe("recipe.value", width: 300.0, height: 100.0)
        .run("focus volume\nkey Right\nfocus volume\nkey Right\nfocus volume\nkey Left") {
            Slider(value, key: "volume", lower: 0.0, upper: 10.0, step: 1.0)
        }
    @Expect(report.contains("\"ok\":true"))
    @Expect(value.value, 3.0)
}

@Test
func disabledCustomProbeDoesNotFallBackToACoordinateClick(): Unit {
    let ascii = ComponentProbe("recipe.custom-disabled", width: 300.0, height: 100.0)
        .run("@cui-ascii 60 12") {
            Label("Read only").probe("custom", "Custom", [
                ProbeProperty("role", "button"), ProbeProperty("action", "notBound()")]).enabled(false)
        }
    @Expect(ascii.contains("actionability=\"disabled\""))
    @Expect(!ascii.contains("probe="))
    @Expect(!ascii.contains("probe."))
}
