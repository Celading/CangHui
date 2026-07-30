package cui.core

func buttonProbeReport(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("test.button", width: 240.0, height: 100.0).run(script) {
        ProbeNode("root", widgetType: "VStack") {
            VStack(padding: LengthInsets(12.vp)) {
                Button("Probe", probedAction("button.click", { => clicks.value += 1 }), role: ButtonRole.Primary)
                    .key("button")
                    .probe("button", "Button", [ProbeProperty("label", "Probe")], { => [
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
