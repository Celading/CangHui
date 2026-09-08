package chui.core

import sdl.Rect

private func nativeMotionTree(revision: UInt64, offset: Float32): SemanticTreeSnapshot {
    SemanticTreeSnapshot("main", revision, [
        SemanticNode("root", Rect(0.0, 0.0, 240.0, 120.0), "VStack", "group"),
        SemanticNode("animated", Rect(0.0, offset, 80.0, 24.0), "Button", "button",
            parentId: "root", label: "Hover", actions: [SemanticActionKind.Activate]),
        SemanticNode("field", Rect(0.0, 30.0, 240.0, 32.0), "TextField", "textfield",
            parentId: "root", label: "Reference", readOnly: true, actions: [SemanticActionKind.Focus])
    ])
}

@Test
func nativeStableFocusSurvivesUnrelatedHoverGeometry(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    session.publish(nativeMotionTree(UInt64(1), -0.8))
    let id = session.snapshot().getOrThrow().binding("field").getOrThrow().nativeId
    let ticket = session.postUnchangedTargetAction(queue, id, UInt64(1), SemanticActionKind.Focus, {_ => ()})
    session.publish(nativeMotionTree(UInt64(2), -0.9))
    session.publish(nativeMotionTree(UInt64(3), -1.0))
    queue.drain()
    @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    let full = session.postUnchangedAction(queue, id, UInt64(1), SemanticActionKind.Focus, {_ => ()})
    let strict = session.postAction(queue, id, UInt64(1), SemanticActionKind.Focus, {_ => ()})
    queue.drain()
    @Expect(full.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(strict.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
}

private func motionChangedNode(node: SemanticNode, field: String): SemanticNode {
    SemanticNode(node.id, if (field == "geometry") { Rect(1.0, 2.0, 3.0, 4.0) } else { node.frame },
        if (field == "widget") { "Replacement" } else { node.widgetType },
        if (field == "role") { "group" } else { node.role },
        parentId: if (field == "parent") { "" } else { node.parentId },
        order: if (field == "order") { 99 } else { node.order },
        label: if (field == "label") { "Changed intent" } else { node.label },
        value: if (field == "value") { "Changed value" } else { node.value },
        placeholder: if (field == "placeholder") { "Changed hint" } else { node.placeholder },
        selected: if (field == "selected") { Some(true) } else { node.selected },
        expanded: if (field == "expanded") { Some(false) } else { node.expanded },
        enabled: field != "disabled", readOnly: field == "readonly" || node.readOnly,
        focused: if (field == "focused") { Some(true) } else { node.focused },
        editable: if (field == "editable") { Some(true) } else { node.editable },
        selectionStart: if (field == "selection-start") { Some(Int64(1)) } else { node.selectionStart },
        selectionEnd: if (field == "selection-end") { Some(Int64(2)) } else { node.selectionEnd },
        actions: if (field == "actions") { [] } else { node.actions })
}

@Test
func nativeTargetContinuityRejectsUnrelatedSemanticChangesEvenAfterRestoration(): Unit {
    for (field in ["widget", "role", "parent", "order", "label", "value", "placeholder",
        "selected", "expanded", "disabled", "readonly", "focused", "editable",
        "selection-start", "selection-end", "actions"]) {
        let session = SemanticNativeSession("main")
        let queue = UiOwnerQueue()
        let original = nativeMotionTree(UInt64(1), 0.0)
        session.publish(original)
        let id = session.snapshot().getOrThrow().binding("field").getOrThrow().nativeId
        let ticket = session.postUnchangedTargetAction(queue, id, UInt64(1), SemanticActionKind.Focus, {_ => ()})
        session.publish(SemanticTreeSnapshot("main", UInt64(2), [original.nodes[0],
            motionChangedNode(original.nodes[1], field), original.nodes[2]]))
        session.publish(nativeMotionTree(UInt64(3), 0.0))
        queue.drain()
        @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    }
}

@Test
func nativeTargetContinuityRejectsTargetOrAncestorMovementAndMissingFrames(): Unit {
    for (change in ["target", "ancestor", "gap", "remount", "reorder", "overlay"]) {
        let session = SemanticNativeSession("main")
        let queue = UiOwnerQueue()
        let tree = nativeMotionTree(UInt64(1), 0.0)
        session.publish(tree)
        let id = session.snapshot().getOrThrow().binding("field").getOrThrow().nativeId
        let ticket = session.postUnchangedTargetAction(queue, id, UInt64(1), SemanticActionKind.Focus, {_ => ()})
        let nodes = tree.nodes.clone()
        if (change == "target") { nodes[2] = motionChangedNode(nodes[2], "geometry") }
        if (change == "ancestor") { nodes[0] = motionChangedNode(nodes[0], "geometry") }
        if (change == "reorder") { nodes[1] = tree.nodes[2]; nodes[2] = tree.nodes[1] }
        if (change == "remount") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), [nodes[0], nodes[1]]))
        } else if (change == "overlay") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), [nodes[0], nodes[1], nodes[2],
                SemanticNode("modal", Rect.zero(), "Modal", "group")]))
        } else if (change != "gap") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), nodes))
        }
        session.publish(nativeMotionTree(UInt64(3), 0.0))
        queue.drain()
        @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    }
}

@Test
func nativeTargetContinuityKeepsRevisionReadonlyActionAndCloseGates(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    session.publish(nativeMotionTree(UInt64(10), 0.0))
    let id = session.snapshot().getOrThrow().binding("field").getOrThrow().nativeId
    for (revision in [UInt64(0), UInt64(9), UInt64(11)]) {
        let ticket = session.postUnchangedTargetAction(queue, id, revision, SemanticActionKind.Focus, {_ => ()})
        queue.drain()
        @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    }
    let mutation = session.postUnchangedTargetAction(queue, id, UInt64(10), SemanticActionKind.Activate, {_ => ()})
    let foreignTarget = session.postUnchangedTargetAction(queue, UInt64(999), UInt64(10), SemanticActionKind.Focus, {_ => ()})
    queue.drain()
    @Expect(mutation.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(foreignTarget.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    let closed = session.postUnchangedTargetAction(queue, id, UInt64(10), SemanticActionKind.Focus, {_ => ()})
    session.close()
    queue.drain()
    @Expect(closed.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
}

@Test
func nativeTargetContinuityStillChecksFinalRuntimeSourcePolicy(): Unit {
    let runtime = SemanticRuntime("main", policy: SemanticInteractionPolicy(accessibility: false),
        handler: {_ => true})
    let session = SemanticNativeSession("main")
    for (offset in [Float32(0.0), Float32(-1.0)]) {
        runtime.beginFrame()
        runtime.record(Rect(0.0, offset, 80.0, 24.0), "Button", ControlSemantics("button", actionOwner: "animated"))
        runtime.record(Rect(0.0, 30.0, 80.0, 24.0), "Button", ControlSemantics("button", actionOwner: "target"))
        session.publish(runtime.commitFrame())
    }
    let queue = UiOwnerQueue()
    let id = session.snapshot().getOrThrow().binding("target").getOrThrow().nativeId
    let ticket = session.postUnchangedTargetAction(queue, id, UInt64(1), SemanticActionKind.Activate, {request =>
        @Expect(request.expectedRevision, UInt64(2))
        @Expect(runtime.dispatch(request).code, "source-not-allowed")
    })
    queue.drain()
    @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
}
