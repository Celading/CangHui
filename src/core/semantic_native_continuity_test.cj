package chui.core

import sdl.Rect

private func continuityNode(label!: String = "Save", enabled!: Bool = true): SemanticNode {
    SemanticNode("save", Rect(0.0, 0.0, 40.0, 20.0), "Button", "button",
        label: label, enabled: enabled, actions: [SemanticActionKind.Activate])
}

private class ContinuityCounter { var count: Int64 = 0; var revision = UInt64(0) }

@Test
func nativeUnchangedActionCrossesOnlyContinuousIdenticalFrames(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    let counter = ContinuityCounter()
    session.publish(SemanticTreeSnapshot("main", UInt64(1), [continuityNode()]))
    let id = session.snapshot().getOrThrow().binding("save").getOrThrow().nativeId
    session.publish(SemanticTreeSnapshot("main", UInt64(2), [continuityNode()]))
    let ticket = session.postUnchangedAction(queue, id, UInt64(1), SemanticActionKind.Activate, {request =>
        counter.count += 1
        counter.revision = request.expectedRevision
        @Expect(semanticActionSourceName(request.source), "accessibility")
    })
    session.publish(SemanticTreeSnapshot("main", UInt64(3), [continuityNode()]))
    @Expect(counter.count, 0)
    queue.drain()
    @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    @Expect(counter.count, 1)
    @Expect(counter.revision, UInt64(3))
    let strict = session.postAction(queue, id, UInt64(1), SemanticActionKind.Activate, {_ => counter.count += 1})
    queue.drain()
    @Expect(strict.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(counter.count, 1)
}

@Test
func nativeUnchangedActionCannotCrossChangesRestorationOrUnobservedFrames(): Unit {
    for (middle in ["change", "disabled", "remount", "gap"]) {
        let session = SemanticNativeSession("main")
        let queue = UiOwnerQueue()
        let counter = ContinuityCounter()
        session.publish(SemanticTreeSnapshot("main", UInt64(1), [continuityNode()]))
        let id = session.snapshot().getOrThrow().binding("save").getOrThrow().nativeId
        let ticket = session.postUnchangedAction(queue, id, UInt64(1), SemanticActionKind.Activate, {_ => counter.count += 1})
        if (middle == "change") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), [continuityNode(label: "Delete")]))
        } else if (middle == "disabled") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), [continuityNode(enabled: false)]))
        } else if (middle == "remount") {
            session.publish(SemanticTreeSnapshot("main", UInt64(2), []))
        }
        session.publish(SemanticTreeSnapshot("main", UInt64(3), [continuityNode()]))
        queue.drain()
        @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
        @Expect(counter.count, 0)
    }
}

@Test
func nativeUnchangedActionRetainsFutureUnsupportedClosedAndWindowGuards(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    let counter = ContinuityCounter()
    session.publish(SemanticTreeSnapshot("main", UInt64(10), [continuityNode()]))
    let id = session.snapshot().getOrThrow().binding("save").getOrThrow().nativeId
    for (revision in [UInt64(0), UInt64(9), UInt64(11)]) {
        let ticket = session.postUnchangedAction(queue, id, revision, SemanticActionKind.Activate, {_ => counter.count += 1})
        queue.drain()
        @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    }
    let unsupported = session.postUnchangedAction(queue, id, UInt64(10), SemanticActionKind.Dismiss, {_ => counter.count += 1})
    queue.drain()
    @Expect(unsupported.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    let closed = session.postUnchangedAction(queue, id, UInt64(10), SemanticActionKind.Activate, {_ => counter.count += 1})
    session.close()
    queue.drain()
    @Expect(closed.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(counter.count, 0)
}

@Test
func nativeUnchangedActionStillUsesCurrentRuntimePolicy(): Unit {
    let counter = ContinuityCounter()
    let runtime = SemanticRuntime("main", policy: SemanticInteractionPolicy(accessibility: false),
        handler: {_ => counter.count += 1; true})
    let session = SemanticNativeSession("main")
    for (_ in 0..2) {
        runtime.beginFrame()
        runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "save"))
        session.publish(runtime.commitFrame())
    }
    let queue = UiOwnerQueue()
    let id = session.snapshot().getOrThrow().binding("save").getOrThrow().nativeId
    let ticket = session.postUnchangedAction(queue, id, UInt64(1), SemanticActionKind.Activate, {request =>
        @Expect(request.expectedRevision, UInt64(2))
        let receipt = runtime.dispatch(request)
        @Expect(receipt.code, "source-not-allowed")
        counter.revision = request.expectedRevision
    })
    queue.drain()
    @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    @Expect(counter.revision, UInt64(2))
    @Expect(counter.count, 0)
}
