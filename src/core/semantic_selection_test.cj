package chui.core

import sdl.Rect

private func selectionControl(focus: Int64): ControlSemantics {
    ControlSemantics("textfield", actionOwner: "field", value: "a你b",
        selectionStart: Some(Int64(1)), selectionEnd: Some(Int64(4)), selectionFocus: Some(focus))
}

@Test
func semanticSelectionDirectionSurvivesSnapshotsAndChangesDiff(): Unit {
    let runtime = SemanticRuntime("main")
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", selectionControl(4))
    let first = runtime.commitFrame()
    @Expect(first.nodes[0].selectionFocus, Some(Int64(4)))
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", selectionControl(1))
    let second = runtime.commitFrame()
    @Expect(second.nodes[0].selectionFocus, Some(Int64(1)))
    @Expect(runtime.diff(first).changed, ["field"])
    let native = SemanticNativeSession("main")
    native.publish(second)
    @Expect(native.snapshot().getOrThrow().tree.nodes[0].selectionFocus, Some(Int64(1)))
    let design = DesignSnapshot.fromSemantics("selection", DesignSnapshotEnvironment("headless", 10.0, 10.0), second)
    @Expect(design.toJson().contains("selectionFocus"))
}

@Test
func passwordSelectionMetadataIsRedactedAtBothSemanticBoundaries(): Unit {
    let control = ControlSemantics("password", actionOwner: "password",
        selectionStart: Some(Int64(1)), selectionEnd: Some(Int64(99)), selectionFocus: Some(Int64(1)))
    @Expect(control.selectionStart.isNone() && control.selectionEnd.isNone() && control.selectionFocus.isNone())
    let node = SemanticNode("password", Rect.zero(), "TextField", "password", value: "secret",
        selectionStart: Some(Int64(1)), selectionEnd: Some(Int64(99)), selectionFocus: Some(Int64(1)))
    @Expect(node.value == "")
    @Expect(node.selectionStart.isNone() && node.selectionEnd.isNone() && node.selectionFocus.isNone())
}
