package chui.core

import sdl.Rect

@Test
func observationDiagnosticsRetainSeverityAndEvidenceInsteadOfOnlyAnAlarmCount(): Unit {
    let snapshot = DesignSnapshot("health", DesignSnapshotEnvironment("headless", 80.0, 60.0), [
        DesignSnapshotNode("tiny", DesignSnapshotNodeKind.Component, Rect(0.0, 0.0, 20.0, 20.0),
            widgetType: "IconButton", role: "button")
    ])
    let json = renderProbeObservation(snapshot, snapshot, "json", 8, "", false, true, 1)
    @Expect(json.contains("\"severity\":\"error\""))
    @Expect(json.contains("\"severity\":\"warning\""))
    @Expect(json.contains("\"evidenceSource\":\"semantic\""))
    @Expect(json.contains("\"suggestion\":"))
    let text = renderProbeObservation(snapshot, snapshot, "summary", 8, "", false, true, 1)
    @Expect(text.contains("! error "))
    @Expect(text.contains("! warning "))
}

@Test
func observationTreeOrdersParentsBeforeLexicallyEarlierChildren(): Unit {
    let snapshot = DesignSnapshot("tree", DesignSnapshotEnvironment("headless", 100.0, 80.0), [
        DesignSnapshotNode("a-child", DesignSnapshotNodeKind.Component, Rect(0.0, 0.0, 20.0, 20.0), parentId: "z-parent"),
        DesignSnapshotNode("z-parent", DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, 100.0, 80.0))
    ])
    let output = renderProbeObservation(snapshot, snapshot, "tree", 8, "", false, true, 1)
    var parentSeen = false
    for (line in output.split("\n")) {
        if (line.startsWith("\"z-parent\" <-")) { parentSeen = true }
        if (line.startsWith("  \"a-child\" <-")) { @Expect(parentSeen) }
    }
    @Expect(parentSeen)
    @Expect(output.contains("  \"a-child\" <-"))
}

@Test
func probeFrameRetainsItsCallbackEvidenceWithoutDoubleDispatch(): Unit {
    let report = ComponentProbe("frame.evidence").run("advance 40\nassert activation tick 1") {
        FrameHandler(onFrame: {info =>
            if (info.deltaMs > 0) { probedAction("tick", {=> ()})() }
        }) { Label("clock") }
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("\"activations\":[\"tick\"]"))
}

@Test
func observationIsBoundedAndDoesNotExposePasswordOrRawValues(): Unit {
    let snapshot = DesignSnapshot("test", DesignSnapshotEnvironment("headless", 100.0, 80.0), [
        DesignSnapshotNode("a", DesignSnapshotNodeKind.Component, Rect(0.0, 0.0, 40.0, 30.0),
            role: "password", label: "private-label", value: "private-value"),
        DesignSnapshotNode("b", DesignSnapshotNodeKind.Component, Rect(0.0, 100.0, 40.0, 30.0))
    ])
    let output = renderProbeObservation(snapshot, snapshot, "json", 1, "", false, true, 7)
    @Expect(output.contains("\"omittedNodes\":1"))
    @Expect(output.contains("\"inputRevision\":7"))
    @Expect(output.contains("[redacted]"))
    @Expect(!output.contains("private-"))
    @Expect(!output.contains("\"drawIr\""))
    let below = renderProbeObservation(snapshot, snapshot, "summary", 5, "b", false, true, 7)
    @Expect(below.contains("offscreen"))
    @Expect(below.contains("unavailable-viewport"))
    let missing = renderProbeObservation(snapshot, snapshot, "summary", 5, "missing", false, true, 7)
    @Expect(missing.startsWith("CangHui prntx | ok=false"))
    @Expect(missing.contains("node-not-found"))
}

@Test
func observationDiffReusesDesignLayersAndReportsTruncation(): Unit {
    let before = DesignSnapshot("test", DesignSnapshotEnvironment("headless", 100.0, 80.0), [
        DesignSnapshotNode("move", DesignSnapshotNodeKind.Component, Rect(0.0, 0.0, 20.0, 20.0))
    ])
    let after = DesignSnapshot("test", before.environment, [
        DesignSnapshotNode("move", DesignSnapshotNodeKind.Component, Rect(10.0, 0.0, 20.0, 20.0))
    ])
    let output = renderProbeObservation(after, before, "diff", 2, "", true, true, 2)
    @Expect(output.contains("\"geometry\":{\"count\":1,\"omitted\":0,\"ids\":[\"move\"]}"))
    @Expect(output.contains(before.contentDigest))
    @Expect(output.contains(after.contentDigest))
}

@Test
func componentProbeObservationUsesInitialFrameAsDiffBaseline(): Unit {
    let changed = State<Bool>(false)
    let output = ComponentProbe("observe").run("@cui-prntx diff 16 -\nfocus save\nkey Enter") {
        Button("save", {=> changed.value = true}).key("save").probe("save", "Button", [],
            {=> [ProbeProperty("selected", changed.value.toString())] })
    }
    @Expect(changed.value)
    @Expect(output.contains("\"protocol\":\"canghui.observation/v1\""))
    @Expect(output.contains("\"state\":{"))
    @Expect(output.contains("save"))
    @Expect(!output.contains("\"ok\":false"))
}
