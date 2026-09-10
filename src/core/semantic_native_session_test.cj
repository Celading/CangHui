package chui.core

import sdl.Rect

private func nativeTestNode(id: String, parent!: String = "", role!: String = "button"): SemanticNode {
    SemanticNode(id, Rect.zero(), "NativeTest", role, parentId: parent,
        actions: [SemanticActionKind.Focus, SemanticActionKind.Activate])
}

@Test
func nativeSemanticIdentitySurvivesReorderButNotRemovalOrRoleReplacement(): Unit {
    let session = SemanticNativeSession("main")
    session.publish(SemanticTreeSnapshot("main", UInt64(1), [nativeTestNode("a"), nativeTestNode("b", parent: "a")]))
    let first = session.snapshot().getOrThrow()
    let a = first.binding("a").getOrThrow().nativeId
    let b = first.binding("b").getOrThrow().nativeId
    @Expect(a > 1 && b > a)
    @Expect(first.binding("b").getOrThrow().parentNativeId, a)
    session.publish(SemanticTreeSnapshot("main", UInt64(2), [nativeTestNode("b"), nativeTestNode("a")]))
    @Expect(session.snapshot().getOrThrow().binding("b").getOrThrow().nativeId, b)
    session.publish(SemanticTreeSnapshot("main", UInt64(3), [nativeTestNode("a")]))
    session.publish(SemanticTreeSnapshot("main", UInt64(4), [nativeTestNode("a"), nativeTestNode("b")]))
    @Expect(session.snapshot().getOrThrow().binding("b").getOrThrow().nativeId > b)
    session.publish(SemanticTreeSnapshot("main", UInt64(5), [nativeTestNode("a", role: "checkbox")]))
    @Expect(session.snapshot().getOrThrow().binding("a").getOrThrow().nativeId > b)
}

@Test
func nativeSemanticPublicationIsDetachedAndRejectsMalformedFramesAtomically(): Unit {
    let session = SemanticNativeSession("main")
    let input = SemanticTreeSnapshot("main", UInt64(1), [nativeTestNode("a")])
    session.publish(input)
    input.nodes[0] = nativeTestNode("changed")
    let detached = session.snapshot().getOrThrow()
    detached.tree.nodes[0].actions[0] = SemanticActionKind.Dismiss
    detached.bindings[0] = SemanticNativeBinding("changed", UInt64(99), UInt64(1))
    let reread = session.snapshot().getOrThrow()
    @Expect(reread.tree.nodes[0].id, "a")
    @Expect(semanticActionName(reread.tree.nodes[0].actions[0]), "focus")
    @Expect(reread.binding("a").getOrThrow().nativeId, UInt64(2))
    var rejected: Int64 = 0
    for (bad in [
        SemanticTreeSnapshot("wrong", UInt64(2), []),
        SemanticTreeSnapshot("main", UInt64(1), []),
        SemanticTreeSnapshot("main", UInt64(2), [nativeTestNode("a", parent: "missing")]),
        SemanticTreeSnapshot("main", UInt64(2), [nativeTestNode("a", parent: "b"), nativeTestNode("b", parent: "a")])
    ]) {
        try { session.publish(bad) } catch (_: IllegalArgumentException) { rejected += 1 }
    }
    @Expect(rejected, 4)
    @Expect(session.snapshot().getOrThrow().tree.revision, UInt64(1))
    session.publish(SemanticTreeSnapshot("main", UInt64(2), [nativeTestNode("a"), nativeTestNode("b")]))
    @Expect(session.snapshot().getOrThrow().binding("b").getOrThrow().nativeId, UInt64(3))
}

private class NativeSemanticCounter { var count: Int64 = 0 }

@Test
func nativeSemanticActionsWaitForOwnerAndCannotCrossRevisionOrClose(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    let counter = NativeSemanticCounter()
    session.publish(SemanticTreeSnapshot("main", UInt64(1), [nativeTestNode("a")]))
    let id = session.snapshot().getOrThrow().binding("a").getOrThrow().nativeId
    let first = session.postAction(queue, id, UInt64(1), SemanticActionKind.Activate, {request =>
        @Expect(request.nodeId, "a")
        @Expect(semanticActionSourceName(request.source), "accessibility")
        counter.count += 1
    })
    @Expect(counter.count, 0)
    queue.drain()
    @Expect(first.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    @Expect(counter.count, 1)
    let stale = session.postAction(queue, id, UInt64(1), SemanticActionKind.Activate, {_ => counter.count += 1})
    session.publish(SemanticTreeSnapshot("main", UInt64(2), [nativeTestNode("a")]))
    queue.drain()
    @Expect(stale.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    let closed = session.postAction(queue, id, UInt64(2), SemanticActionKind.Activate, {_ => counter.count += 1})
    session.close()
    queue.drain()
    @Expect(closed.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(counter.count, 1)
    @Expect(session.snapshot().isNone())
    var rejected = false
    try { session.publish(SemanticTreeSnapshot("main", UInt64(3), [])) }
    catch (_: IllegalStateException) { rejected = true }
    @Expect(rejected)
}

@Test
func nativeSemanticActionsRejectOldIdentityUnsupportedAndDisabledTargets(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    let counter = NativeSemanticCounter()
    session.publish(SemanticTreeSnapshot("main", UInt64(1), [nativeTestNode("a")]))
    session.publish(SemanticTreeSnapshot("main", UInt64(2), []))
    session.publish(SemanticTreeSnapshot("main", UInt64(3), [nativeTestNode("a"),
        SemanticNode("disabled", Rect.zero(), "Button", "button", enabled: false,
            actions: [SemanticActionKind.Activate])]))
    let view = session.snapshot().getOrThrow()
    let old = session.postAction(queue, UInt64(2), UInt64(3), SemanticActionKind.Activate, {_ => counter.count += 1})
    let unsupported = session.postAction(queue, view.binding("a").getOrThrow().nativeId,
        UInt64(3), SemanticActionKind.Dismiss, {_ => counter.count += 1})
    let disabled = session.postAction(queue, view.binding("disabled").getOrThrow().nativeId,
        UInt64(3), SemanticActionKind.Activate, {_ => counter.count += 1})
    queue.drain()
    @Expect(old.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(unsupported.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(disabled.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(counter.count, 0)
}

@Test
func nativeSemanticOwnerHandlerCanCloseWithoutHoldingTheProjectionLock(): Unit {
    let session = SemanticNativeSession("main")
    let queue = UiOwnerQueue()
    session.publish(SemanticTreeSnapshot("main", UInt64(1), [nativeTestNode("a")]))
    let ticket = session.postAction(queue, UInt64(2), UInt64(1), SemanticActionKind.Activate, {_ => session.close()})
    queue.drain()
    @Expect(ticket.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    @Expect(session.snapshot().isNone())
}
