package cui.core

import sdl.{Color, DrawIrAsciiAnnotationKind, Rect, Size, UiEvent}

func buttonProbeReport(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("test.button", width: 240.0, height: 100.0).run(script) {
        ProbeNode("root", widgetType: "VStack") {
            VStack(padding: LengthInsets(12.vp)) {
                Button("Probe", probedAction("button.click", { => clicks.value += 1 }), role: ButtonRole.Primary)
                    .key("button")
                    .probe("button", "Button", [
                        ProbeProperty("role", "button"),
                        ProbeProperty("label", "Probe"),
                        ProbeProperty("action", "button.click()"),
                        ProbeProperty("shortcut", "Enter|Space")
                    ], { => [
                        ProbeProperty("clicks", clicks.value.toString()),
                        ProbeProperty("selected", (clicks.value > 0).toString())
                    ] })
            }
        }
    }
}

@Test
func componentProbeIsDeterministicAndCapturesBehavior(): Unit {
    let script = "move-in 60 30\n" +
        "assert state button hover true\n" +
        "press 60 30\n" +
        "advance 60\n" +
        "assert animation button animator between 0.8 0.9\n" +
        "release 60 30\n" +
        "assert activation button.click 1\n" +
        "assert property button clicks 1\n" +
        "assert draw text 1"
    let first = buttonProbeReport(script)
    let second = buttonProbeReport(script)
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"cui.probe.v0\""))
    @Expect(first.contains("\"ok\":true"))
    @Expect(first.contains("\"scope\":\"button\""))
    @Expect(first.contains("\"activations\":[\"button.click\"]"))
}

@Test
func componentProbePreservesMoveOutCancellation(): Unit {
    let report = buttonProbeReport(
        "move-in 60 30\npress 60 30\nmove-out 230 90\nrelease 230 90\n" +
        "assert activation button.click 0\nassert property button clicks 0"
    )
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"command\":\"release 230 90\",\"consumed\":false"))
}

@Test
func componentProbeRejectsDuplicateNodeIds(): Unit {
    let report = ComponentProbe("test.duplicate", width: 100.0, height: 100.0).run("") {
        VStack {
            ProbeNode("same") { Label("one") }
            ProbeNode("same") { Label("two") }
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("duplicate component probe node id"))
}

@Test
func componentProbeCanRenderTheLatestDrawIrAsAscii(): Unit {
    let report = ComponentProbe("test.ascii", width: 200.0, height: 80.0).run("@cui-ascii 40 10") {
        Button("ASCII", { => }).key("ascii-button").probe("button", "Button", [
            ProbeProperty("role", "button"),
            ProbeProperty("label", "ASCII"),
            ProbeProperty("action", "button.click()")
        ])
    }
    @Expect(report.contains("CangHui headless Draw IR 200.000000x80.000000 -> 40x10"))
    @Expect(report.contains("ASCII"))
    @Expect(report.contains("[$i1]"))
    @Expect(report.contains("$i1 - \"Button#button\""))
    @Expect(report.contains("action=\"button.click()\""))
    @Expect(!report.contains("\"drawIr\""))
}

private class SemanticRegionProbe <: Widget {
    private var frame = Rect.zero()

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(frame, Color.rgb(20, 20, 20))
        probeSemanticRegions { => [
            ProbeSemanticRegion(
                "custom.play",
                DrawIrAsciiAnnotationKind.Interactive,
                Rect(frame.x + 10.0, frame.y + 10.0, 40.0, 30.0),
                widgetType: "IconButton",
                properties: [
                    ProbeProperty("role", "button"),
                    ProbeProperty("icon", "Icons.Play"),
                    ProbeProperty("label", "Play"),
                    ProbeProperty("action", "player.play()"),
                    ProbeProperty("shortcut", "Space")
                ]
            )
        ] }
    }

    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

@Test
func componentProbeCapturesCustomDrawnSemanticRegions(): Unit {
    let json = ComponentProbe("test.regions", width: 120.0, height: 60.0).run("") {
        let widget = SemanticRegionProbe()
        emit(widget)
    }
    @Expect(json.contains("\"regions\":[{\"id\":\"custom.play\""))
    @Expect(json.contains("\"kind\":\"interactive\""))

    let ascii = ComponentProbe("test.regions", width: 120.0, height: 60.0).run("@cui-ascii 40 10") {
        let widget = SemanticRegionProbe()
        emit(widget)
    }
    @Expect(ascii.contains("[$i1]"))
    @Expect(ascii.contains("Icons.Play"))
    @Expect(ascii.contains("player.play()"))
    @Expect(ascii.contains("probe=\"press 30 25; release 30 25\""))
}

@Test
func componentProbeKeepsInputNodesInTheFocusMarkerFamily(): Unit {
    let ascii = ComponentProbe("test.focus", width: 200.0, height: 60.0).run("@cui-ascii 40 10") {
        ProbeNode("search", widgetType: "TextField", properties: [
            ProbeProperty("role", "searchbox"),
            ProbeProperty("label", "Search"),
            ProbeProperty("action", "search.submit()"),
            ProbeProperty("shortcut", "Enter")
        ]) {
            Label("Search")
        }
    }
    @Expect(ascii.contains("<$f1>"))
    @Expect(ascii.contains("$f1 - \"TextField#search\""))
    @Expect(!ascii.contains("$i1 - \"TextField#search\""))
}

@Test
func componentProbeRejectsSemanticRegionIdsThatCollideWithNodes(): Unit {
    let report = ComponentProbe("test.region-collision", width: 120.0, height: 60.0).run("") {
        ProbeNode("custom.play") {
            let widget = SemanticRegionProbe()
            emit(widget)
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("duplicate component probe semantic region id: custom.play"))
}
