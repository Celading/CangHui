package canghui_kit_parity

import chui.*

@Test
func sameWorkflowSurvivesAllRecipesAndAccessibilityPreferences(): Unit {
    for (style in [0, 1, 2]) {
        for (width in [Float32(360.0), Float32(960.0)]) {
            for (dark in [false, true]) {
                for (reduced in [false, true]) {
                    let model = LibraryFlow()
                    model.style.value = style
                    model.width.value = width
                    model.dark = dark
                    model.reduced = reduced
                    let report = ComponentProbe("parity-flow", width: width, height: 760.0,
                        theme: flowTheme(model)).run(
                        "focus continue\nkey Enter\nfocus choose\nkey Enter\nfocus continue\nkey Enter\n" +
                        "focus back\nkey Enter\nassert activation continue 2\nassert activation choose 1\nassert activation back 1") {
                        flowView(model)
                    }
                    @Expect(!report.contains("\"ok\":false"))
                    @Expect(model.chosen.value)
                    @Expect(!model.review.value)
                    @Expect(!model.error.value)
                    @Expect(flowTheme(model).reduceMotion, reduced)
                    @Expect(!report.contains("nested-interaction-owner"))
                }
            }
        }
    }
}

@Test
func recipesDoNotOwnStateOrReorderTheActionFocusRing(): Unit {
    let model = LibraryFlow()
    model.choose()
    for (style in [0, 1, 2, 0]) {
        model.style.value = style
        let report = ComponentProbe("parity-focus", width: 960.0, height: 760.0,
            theme: flowTheme(model)).run(
            "assert property choose focusOrder 0\n" +
            "assert property continue focusOrder 1") { flowView(model) }
        @Expect(!report.contains("\"ok\":false"))
        @Expect(model.chosen.value)
    }
}

@Test
func scaledLogicalClicksShareTheSameActionAcrossKits(): Unit {
    // This checks the shared coordinate transform, not physical touch or a second monitor.
    for (style in [0, 1, 2]) {
        for (zoom in [Float32(1.0), Float32(1.25), Float32(1.5), Float32(2.0)]) {
            for (density in [Float32(1.0), Float32(2.0)]) {
                let model = LibraryFlow()
                model.style.value = style
                let transform = WindowCoordinateTransform(zoom * density, density)
                let windowPoint = transform.logicalToWindow(Rect(30.0, 20.0, 1.0, 1.0))
                let point = transform.windowToLogical(Point(windowPoint.x, windowPoint.y))
                let xy = "${point.x} ${point.y}"
                let report = ComponentProbe("parity-coordinates", width: 360.0, height: 150.0,
                    theme: flowTheme(model)).run(
                    "press ${xy}\nrelease ${xy}\nassert activation choose 1") { controls(model) }
                @Expect(!report.contains("\"ok\":false"))
                @Expect(model.chosen.value)
            }
        }
    }
}

@Test
func validationIsRealAndReturnPreservesSelection(): Unit {
    let model = LibraryFlow()
    model.proceed()
    @Expect(model.error.value)
    @Expect(!model.review.value)
    model.choose()
    model.proceed()
    @Expect(model.review.value)
    model.back()
    @Expect(model.chosen.value)
    @Expect(!model.error.value)
}
