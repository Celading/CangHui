package chui.core

import sdl.{DrawIrCommand, Rect}

private let DESIGN_TEST_SHA = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

private func designSnapshotV2Fixture(): DesignSnapshotV2 {
    let base = DesignSnapshot("explorer.files",
        DesignSnapshotEnvironment("headless", 1440.0, 900.0, scale: 2.0, theme: "dark"), [
            DesignSnapshotNode("screen:main", DesignSnapshotNodeKind.Screen,
                Rect(0.0, 0.0, 1440.0, 900.0)),
            DesignSnapshotNode("toolbar.open", DesignSnapshotNodeKind.Component,
                Rect(16.0, 12.0, 44.0, 36.0), parentId: "screen:main", widgetType: "IconButton",
                role: "button", label: "Open")
        ], inputDigest: "fixture:v2")
    let source = DesignSourceBinding("explorerx.ui", "FileToolbar",
        "src/ui/file_toolbar.cj", line: 28, column: 5,
        sourceDigest: DESIGN_TEST_SHA, resourceDigest: DESIGN_TEST_SHA)
    DesignSnapshotV2(base,
        componentBindings: [
            DesignComponentBinding("toolbar.open", "IconButton", source,
                publicProperties: ["tooltip", "icon", "variant"],
                variants: ["quiet", "primary"], slots: ["icon"])
        ],
        interactions: [
            DesignInteractionBinding("open.activate", "toolbar.open", DesignInteractionTrigger.Click,
                DesignInteractionTargetKind.Action, "file.open",
                handlerPackage: "explorerx.ui", handlerSymbol: "openSelectedFile",
                handlerRelativePath: "src/ui/file_toolbar.cj", handlerSourceDigest: DESIGN_TEST_SHA,
                shortcut: "CmdOrCtrl+O"),
            DesignInteractionBinding("open.gamepad", "toolbar.open",
                DesignInteractionTrigger.GamepadActivate, DesignInteractionTargetKind.Action, "file.open")
        ],
        scenes: cangHuiRecommendedDesignScenes())
}

@Test
func designSnapshotV2IsCanonicalAndKeepsV1Envelope(): Unit {
    let first = designSnapshotV2Fixture()
    let second = designSnapshotV2Fixture()
    @Expect(first.toJson(), second.toJson())
    @Expect(first.contentDigest, second.contentDigest)
    @Expect(first.toJson().contains("\"protocol\":\"canghui.design-snapshot/v2\""))
    @Expect(first.toJson().contains("\"protocol\":\"canghui.design-snapshot/v1\""))
    @Expect(first.toJson().contains("\"handlerSymbol\":\"openSelectedFile\""))
    @Expect(first.toJson().contains("\"id\":\"desktop-expanded-2x\""))
    @Expect(first.toJson().contains("\"inputClasses\":[\"gamepad\",\"keyboard\",\"pointer\"]"))
}

@Test
func designSnapshotV2RejectsUnknownNodesAndUnsafeSourcePaths(): Unit {
    let base = DesignSnapshot("safe", DesignSnapshotEnvironment("headless", 100.0, 100.0), [
        DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, 100.0, 100.0))
    ], states: [DesignSnapshotProperty("dialog.open", "false")])
    var pathRejected = false
    try {
        let _ = DesignSourceBinding("pkg", "Widget", "/Users/private/widget.cj")
    } catch (_: IllegalArgumentException) { pathRejected = true }
    @Expect(pathRejected)

    var terminalTraversalRejected = false
    try {
        let _ = DesignSourceBinding("pkg", "Widget", "src/..")
    } catch (_: IllegalArgumentException) { terminalTraversalRejected = true }
    @Expect(terminalTraversalRejected)

    var nodeRejected = false
    try {
        let source = DesignSourceBinding("pkg", "Widget", "src/widget.cj")
        let _ = DesignSnapshotV2(base,
            componentBindings: [DesignComponentBinding("missing", "Widget", source)])
    } catch (_: IllegalArgumentException) { nodeRejected = true }
    @Expect(nodeRejected)


    let validStateTarget = DesignSnapshotV2(base,
        interactions: [DesignInteractionBinding("dialog.open", "screen",
            DesignInteractionTrigger.Click, DesignInteractionTargetKind.State, "dialog.open")])
    @Expect(validStateTarget.toJson().contains("\"targetKind\":\"state\""))

    var stateRejected = false
    try {
        let _ = DesignSnapshotV2(base,
            interactions: [DesignInteractionBinding("dialog.missing", "screen",
                DesignInteractionTrigger.Click, DesignInteractionTargetKind.State, "dialog.missing")])
    } catch (_: IllegalArgumentException) { stateRejected = true }
    @Expect(stateRejected)
}

@Test
func recommendedDesignScenesCoverMultiplatformDensityAndInput(): Unit {
    let scenes = cangHuiRecommendedDesignScenes()
    @Expect(scenes.size, 6)
    var hasPhone = false
    var hasTablet = false
    var hasDesktop1x = false
    var hasDesktop2x = false
    var hasFoldable = false
    var hasGamepad = false
    for (scene in scenes) {
        if (designDeviceClassName(scene.deviceClass) == "phone") { hasPhone = true }
        if (designDeviceClassName(scene.deviceClass) == "tablet") { hasTablet = true }
        if (scene.id == "desktop-expanded-1x") { hasDesktop1x = true }
        if (scene.id == "desktop-expanded-2x") { hasDesktop2x = true }
        if (designDeviceClassName(scene.deviceClass) == "foldable") { hasFoldable = true }
        for (input in scene.inputClasses) {
            if (designInputClassName(input) == "gamepad") { hasGamepad = true }
        }
    }
    @Expect(hasPhone && hasTablet && hasDesktop1x && hasDesktop2x && hasFoldable && hasGamepad)
}

@Test
func computedTruthIsOptionalTypedAndAccountsForExactDrawIr(): Unit {
    let commands = [
        DrawIrCommand("scene.begin", ""),
        DrawIrCommand("text", "title", data: "\"text\":\"Hello\",\"pointSize\":15")
    ]
    let base = DesignSnapshot("computed", DesignSnapshotEnvironment("headless", 200.0, 80.0), [
        DesignSnapshotNode("screen", DesignSnapshotNodeKind.Screen, Rect(0.0, 0.0, 200.0, 80.0)),
        DesignSnapshotNode("title", DesignSnapshotNodeKind.Component, Rect(8.0, 8.0, 80.0, 24.0),
            parentId: "screen")
    ], drawIr: commands)
    let value = DesignSnapshotV2(base, computedNodes: [
        DesignComputedNode("screen", facts: [DesignComputedFact(DesignComputedCategory.Layout,
            "frame.width", DesignComputedValueKind.Length, "200", unit: "logical-pixel",
            provenance: DesignComputedProvenance.RuntimeLayout)], drawIr: [commands[0]]),
        DesignComputedNode("title", facts: [DesignComputedFact(DesignComputedCategory.Typography,
            "font.family", DesignComputedValueKind.Token, "HarmonyOS Sans",
            provenance: DesignComputedProvenance.DrawIr)], drawIr: [commands[1]])
    ])
    @Expect(value.toJson().contains("\"computedNodes\":"))
    @Expect(value.toJson().contains("\"category\":\"typography\""))
    @Expect(value.toJson().contains("\"provenance\":\"draw-ir\""))
    @Expect(!designSnapshotV2Fixture().toJson().contains("\"computedNodes\":"))

    var changedCommandRejected = false
    try {
        let _ = DesignSnapshotV2(base, computedNodes: [
            DesignComputedNode("screen", drawIr: [commands[0]]),
            DesignComputedNode("title", drawIr: [DrawIrCommand("text", "title",
                data: "\"text\":\"Changed\",\"pointSize\":15")])
        ])
    } catch (_: IllegalArgumentException) { changedCommandRejected = true }
    @Expect(changedCommandRejected)
}
