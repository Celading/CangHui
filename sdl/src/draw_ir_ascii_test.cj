package sdl

@Test
func asciiTypedRecipesWhitelistActionsAndUseActualFocusTarget(): Unit {
    let output = renderDrawIrAscii([], 100.0, 50.0, annotations: [
        DrawIrAsciiAnnotation("observer", DrawIrAsciiAnnotationKind.Interactive,
            Rect(0.0, 0.0, 80.0, 20.0), focusTarget: "volume", shortcut: "Delete",
            replayActions: Some(["increment", "focus", "increment", "arbitrary-command", "decrement"]))
    ])
    @Expect(output.contains("probe.focus=\"focus volume\""))
    @Expect(output.contains("probe.increment=\"focus volume\\nkey Right\""))
    @Expect(output.contains("probe.decrement=\"focus volume\\nkey Left\""))
    @Expect(output.split("probe.increment=").size, 2)
    @Expect(!output.contains("key Delete"))
    @Expect(!output.contains("arbitrary-command"))
    @Expect(!output.contains("press "))
}

@Test
func asciiRecipesRejectUnreplayableAndTruncatedFocusTargets(): Unit {
    let longTarget = StringBuilder()
    for (_ in 0..225) { longTarget.append("x") }
    let actionSets: Array<?Array<String>> = [None, Some(["focus", "activate", "increment", "decrement", "dismiss"])]
    for (target in ["", "two words", "x\nkey Enter", "x\tkey", "x;key", "x\"", "x\\", longTarget.toString()]) {
        for (actions in actionSets) {
            let output = renderDrawIrAscii([], 100.0, 50.0, annotations: [
                DrawIrAsciiAnnotation("observer", DrawIrAsciiAnnotationKind.Focus,
                    Rect(0.0, 0.0, 80.0, 20.0), focusTarget: target, replayActions: actions)
            ])
            @Expect(output.contains("focus=\"target-unverified\""))
            @Expect(!output.contains("probe="))
            @Expect(!output.contains("probe."))
        }
    }
}

@Test
func asciiTypedRecipesStillRespectViewportOverlayAndDisabledGuards(): Unit {
    for (rect in [Rect(0.0, 60.0, 80.0, 20.0), Rect(80.0, 0.0, 40.0, 20.0)]) {
        let output = renderDrawIrAscii([], 100.0, 50.0, annotations: [
            DrawIrAsciiAnnotation("observer", DrawIrAsciiAnnotationKind.Interactive, rect,
                focusTarget: "owner", replayActions: Some(["focus", "activate"]))
        ])
        @Expect(!output.contains("probe."))
    }
    for (overlay in [true, false]) {
        let output = renderDrawIrAscii([], 100.0, 50.0,
            options: DrawIrAsciiOptions(overlayActive: overlay), annotations: [
                DrawIrAsciiAnnotation("observer", DrawIrAsciiAnnotationKind.Interactive,
                    Rect(0.0, 0.0, 80.0, 20.0), focusTarget: "owner", enabled: false,
                    replayActions: Some(["focus", "activate"]))
            ])
        @Expect(!output.contains("probe."))
        @Expect(!output.contains("probe="))
    }
}

@Test
func asciiCapsLegendAndDoesNotClampOffscreenTextOntoBottomEdge(): Unit {
    let text = StringBuilder()
    for (_ in 0..300) { text.append("界") }
    let annotations = Array<DrawIrAsciiAnnotation>(140, {i =>
        DrawIrAsciiAnnotation("node-${i}", DrawIrAsciiAnnotationKind.Visual,
            Rect(0.0, 0.0, 20.0, 20.0), label: text.toString())
    })
    let output = renderDrawIrAscii([
        DrawIrCommand("text", "", data: "\"text\":\"SHOULD_NOT_APPEAR\",\"x\":0,\"y\":80,\"pointSize\":12")
    ], 100.0, 50.0, annotations: annotations)
    @Expect(output.contains("annotations omitted=12"))
    @Expect(output.contains("…[truncated]"))
    @Expect(!output.contains("node-139"))
    @Expect(!output.contains("SHOULD_NOT_APPEAR"))
}

@Test
func asciiOffscreenTargetsStayInLegendWithoutClickInstructions(): Unit {
    let output = renderDrawIrAscii([], 100.0, 50.0, annotations: [
        DrawIrAsciiAnnotation("below", DrawIrAsciiAnnotationKind.Interactive, Rect(10.0, 80.0, 60.0, 20.0)),
        DrawIrAsciiAnnotation("left", DrawIrAsciiAnnotationKind.Focus, Rect(-40.0, 5.0, 20.0, 20.0)),
        DrawIrAsciiAnnotation("partial", DrawIrAsciiAnnotationKind.Interactive, Rect(80.0, 5.0, 40.0, 20.0))
    ])
    @Expect(output.contains("visibility=\"offscreen\""))
    @Expect(output.contains("visibility=\"partial\""))
    @Expect(!output.contains("probe=\""))
    @Expect(!output.contains("[$i1]"))
}

@Test
func asciiFocusHintsRequireAnExplicitTarget(): Unit {
    let output = renderDrawIrAscii([], 100.0, 50.0, annotations: [
        DrawIrAsciiAnnotation("observer", DrawIrAsciiAnnotationKind.Focus, Rect(0.0, 0.0, 20.0, 20.0),
            focusTarget: "actual-key"),
        DrawIrAsciiAnnotation("unknown", DrawIrAsciiAnnotationKind.Focus, Rect(30.0, 0.0, 20.0, 20.0))
    ])
    @Expect(output.contains("probe=\"focus actual-key\""))
    @Expect(!output.contains("probe=\"focus observer\""))
    @Expect(!output.contains("probe=\"focus unknown\""))
    @Expect(output.contains("focus=\"target-unverified\""))
}

@Test
func asciiMarkersDoNotOverwriteText(): Unit {
    let output = renderDrawIrAscii([
        DrawIrCommand("text", "", data: "\"text\":\"KEEP_THIS_TEXT\",\"x\":0,\"y\":20,\"pointSize\":12")
    ], 100.0, 50.0, options: DrawIrAsciiOptions(columns: 20, rows: 8), annotations: [
        DrawIrAsciiAnnotation("button", DrawIrAsciiAnnotationKind.Interactive, Rect(0.0, 20.0, 100.0, 6.0))
    ])
    @Expect(output.contains("KEEP_THIS_TEXT"))
}

@Test
func drawIrAsciiProjectsGeometryTextAndSymbolsDeterministically(): Unit {
    let commands = [
        DrawIrCommand("paint.fill", "", data: "\"x\":0,\"y\":0,\"width\":100,\"height\":50,\"color\":{\"r\":20,\"g\":20,\"b\":20,\"a\":255}"),
        DrawIrCommand("paint.stroke-line", "", data: "\"x1\":0,\"y1\":25,\"x2\":100,\"y2\":25,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("paint.stroke-circle", "", data: "\"cx\":20,\"cy\":15,\"radius\":8,\"width\":1,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("text", "", data: "\"text\":\"HELLO\",\"x\":40,\"y\":10,\"pointSize\":12,\"color\":{\"r\":255,\"g\":255,\"b\":255,\"a\":255}"),
        DrawIrCommand("symbol", "", data: "\"x\":60,\"y\":30,\"width\":30,\"height\":12,\"name\":\"play\"")
    ]
    let first = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    let second = renderDrawIrAscii(commands, 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 40, rows: 12))
    @Expect(first, second)
    @Expect(first.contains("HELLO"))
    @Expect(first.contains("o"))
    @Expect(first.contains("[play]"))
    @Expect(first.contains("----------------------------------------"))
}

@Test
func drawIrAsciiOverlaysStableSemanticMarkersAndFunctionLegend(): Unit {
    let annotations = [
        DrawIrAsciiAnnotation(
            "toolbar.back",
            DrawIrAsciiAnnotationKind.Interactive,
            Rect(4.0, 4.0, 30.0, 18.0),
            component: "IconButton",
            role: "button",
            label: "Back",
            icon: "Icons.Back",
            action: "window.back()",
            shortcut: "Escape",
            state: "enabled"
        ),
        DrawIrAsciiAnnotation(
            "search",
            DrawIrAsciiAnnotationKind.Focus,
            Rect(40.0, 4.0, 50.0, 18.0),
            component: "TextField",
            role: "searchbox",
            label: "Search"
        ),
        DrawIrAsciiAnnotation(
            "preview",
            DrawIrAsciiAnnotationKind.Visual,
            Rect(4.0, 28.0, 86.0, 18.0),
            component: "Preview",
            label: "A \"quoted\"\nvalue"
        )
    ]
    let first = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 50, rows: 12), annotations: annotations)
    let second = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 50, rows: 12), annotations: annotations)
    @Expect(first, second)
    @Expect(first.contains("[$i1]"))
    @Expect(first.contains("<$f1>"))
    @Expect(first.contains("($v1)"))
    @Expect(first.contains("$i1 - \"IconButton#toolbar.back\""))
    @Expect(first.contains("action=\"window.back()\""))
    @Expect(first.contains("probe=\"press 19 13; release 19 13\""))
    @Expect(first.contains("label=\"A \\\"quoted\\\"\\nvalue\""))
}

@Test
func drawIrAsciiKeepsOverlappingTinyAnnotationsInTheLegend(): Unit {
    let annotations = [
        DrawIrAsciiAnnotation("first", DrawIrAsciiAnnotationKind.Interactive,
            Rect(0.0, 0.0, 2.0, 2.0), component: "Button"),
        DrawIrAsciiAnnotation("second", DrawIrAsciiAnnotationKind.Interactive,
            Rect(0.0, 0.0, 2.0, 2.0), component: "Button")
    ]
    let output = renderDrawIrAscii([], 100.0, 50.0,
        options: DrawIrAsciiOptions(columns: 20, rows: 8), annotations: annotations)
    @Expect(output.contains("$i1 - \"Button#first\""))
    @Expect(output.contains("$i2 - \"Button#second\""))
    @Expect(output.contains("Compact markers: [$N] action"))
    @Expect(output.contains("marker=legend-only"))
}
