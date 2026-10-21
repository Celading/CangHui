package canghui_kit

import chui.*

@Test
func visualFamiliesHaveDifferentPaintAndSurviveNarrowDarkReducedMatrices(): Unit {
    for (width in [Float32(240.0), Float32(390.0), Float32(1060.0), Float32(1600.0)]) {
        for (dark in [false, true]) {
            for (reduced in [false, true]) {
                for (family in [KitMotionFamily.Bounce, KitMotionFamily.Digital, KitMotionFamily.FocusLight,
                    KitMotionFamily.Choreography, KitMotionFamily.Archive]) {
                    let report = ComponentProbe("motion-${family.name()}", width: width, height: 340.0,
                        theme: if (dark) {Theme.dark().withReduceMotion(reduced)} else {Theme.light().withReduceMotion(reduced)})
                        .run("advance 16\nadvance 1000\ndraw") {
                            kitMotionStudy("study", family, kitMotionPalette(family, dark: dark))
                        }
                    if (!report.contains("\"ok\":true")) { println("KIT_REPORT ${family.name()} ${width} ${dark} ${reduced}: " + report) }
                    @Expect(report.contains("\"ok\":true"))
                    @Expect(!report.contains("NaN"))
                    @Expect(!report.contains("nested-interaction-owner"))
                }
            }
        }
    }
}

@Test
func rollingNumberPreservesEveryInt64DigitWithoutFloatConversion(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    let motion = KitNumberMotion()
    for (value in [Int64(0), Int64(9), Int64(10), Int64(99), Int64(100), Int64(-7),
        Int64(9007199254740993), Int64.Min, Int64.Max]) {
        let text = value.toString()
        motion.prepare(text)
        @Expect(motion.semanticValue(), text)
        let count = text.size - if (text.startsWith("-")) {1} else {0}
        for (i in 0..count) {
            @Expect(Int64(motion.sample(ctx, i)) % 10, Int64(text[text.size - 1 - i]) - 48)
        }
    }
}

@Test
func rollingNumberRapidUpdatesContinueWithoutAQueuedIntermediateValue(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let motion = KitNumberMotion()
    motion.prepare("9")
    motion.sample(ctx, 0)
    ctx.frame = FrameInfo(80, 80)
    let before = motion.sample(ctx, 0)
    motion.prepare("4")
    @Expect(motion.sample(ctx, 0), before)
    motion.prepare("3")
    motion.sample(ctx, 0)
    @Expect(motion.semanticValue(), "3")
    ctx.frame = FrameInfo(1000, 920)
    @Expect(Int64(motion.sample(ctx, 0)) % 10, Int64(3))
}

@Test
func focusLightingNeverSwallowsAnExistingButtonsPointerOrKeyboard(): Unit {
    let count = State<Int64>(0)
    let report = ComponentProbe("passive-light", width: 320.0, height: 200.0).run(
        "press 120 90\nrelease 120 90\nfocus primary\nkey Enter\nadvance 500\nassert activation primary 2") {
        ZStack {
            Button("Open", probedAction("primary", {=> count.value += 1})).key("primary")
                .fillWidth().fillHeight()
            kitFocusLight("light", kitMotionPalette(KitMotionFamily.FocusLight), focusKey: "primary")
        }.fillWidth().fillHeight()
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(count.value, Int64(2))
    @Expect(!report.contains("nested-interaction-owner"))
}

@Test
func numberSemanticValueIsTheFinalExactTextDuringAnimation(): Unit {
    let report = ComponentProbe("number-semantics", width: 240.0, height: 100.0).run("advance 80") {
        kitRollingNumber("number", Int64.Min, kitMotionPalette(KitMotionFamily.Digital))
            .fontSize(32.fp).bold()
    }
    if (!report.contains("-9223372036854775808")) { println("NUMBER_REPORT " + report) }
    @Expect(report.contains("-9223372036854775808"))
    @Expect(report.contains("\"role\":\"text\""))
    @Expect(!report.contains("\"action\":\"control.activate()\""))
}

@Test
func cascadeKeepsOneFocusableActionOwnerAcrossExpandedStates(): Unit {
    for (expanded in [false, true]) {
        let report = ComponentProbe("cascade", width: 240.0, height: 100.0).run(
            "focus cascade-action\nkey Enter\nassert activation cascade-action 1") {
            kitCascade("cascade-track", 2, expanded) {
                Button("Continue", probedAction("cascade-action", {=> ()})).key("cascade-action")
            }
        }
        @Expect(report.contains("\"ok\":true"))
    }
}

@Test
func focusLightUsesLocalCoordinatesAndSleepsAfterLeaveOrWindowBlur(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let light = KitFocusMotion()
    let rect = Rect(50.0, 100.0, 200.0, 100.0)
    ctx.mouseX = 200.0; ctx.mouseY = 125.0
    light.update(ctx, rect, false)
    ctx.frame = FrameInfo(500, 500)
    light.update(ctx, rect, false)
    @Expect(light.x.value, Float32(0.75))
    @Expect(light.y.value, Float32(0.25))
    @Expect(light.strength.value, Float32(1.0))
    ctx.mouseX = -1.0; ctx.mouseY = -1.0
    light.update(ctx, rect, false)
    ctx.frame = FrameInfo(1000, 500)
    light.update(ctx, rect, false)
    @Expect(light.strength.value, Float32(0.0))
    @Expect(light.x.settled() && light.y.settled() && light.strength.settled())
    @Expect(!light.observe(UiEvent.WindowFocusChanged(false)))
    light.update(ctx, rect, true)
    ctx.frame = FrameInfo(1500, 500)
    light.update(ctx, rect, true)
    @Expect(light.strength.value, Float32(0.0))
    @Expect(!light.observe(UiEvent.WindowFocusChanged(true)))
    ctx.theme = Theme.light(reduceMotion: true)
    ctx.mouseX = 150.0; ctx.mouseY = 120.0
    light.update(ctx, Rect(100.0, 100.0, 100.0, 100.0), false)
    @Expect(light.x.value, Float32(0.5))
    @Expect(light.y.value, Float32(0.2))
    @Expect(light.strength.value, Float32(1.0))
    @Expect(light.x.settled() && light.y.settled() && light.strength.settled())
}
