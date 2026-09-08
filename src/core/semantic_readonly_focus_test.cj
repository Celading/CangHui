package chui.core

import sdl.Rect

private class ReadonlySemanticCounter { var count: Int64 = 0 }

@Test
func readonlySemanticFocusRemainsDeclaredWithoutEnablingMutation(): Unit {
    let counter = ReadonlySemanticCounter()
    let runtime = SemanticRuntime("readonly", handler: {_ => counter.count += 1; true})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", ControlSemantics("textfield",
        actionOwner: "field", readOnly: Some(true),
        typedActions: [SemanticActionKind.Focus, SemanticActionKind.Activate,
            SemanticActionKind.Increment, SemanticActionKind.Decrement, SemanticActionKind.Dismiss]))
    let tree = runtime.commitFrame()
    @Expect(tree.node("field").getOrThrow().actions.size, 1)
    let focus = runtime.dispatch(SemanticActionRequest("readonly", tree.revision,
        "field", SemanticActionKind.Focus, SemanticActionSource.Accessibility))
    @Expect(focus.ok)
    for (action in [SemanticActionKind.Activate, SemanticActionKind.Increment,
        SemanticActionKind.Decrement, SemanticActionKind.Dismiss]) {
        @Expect(runtime.dispatch(SemanticActionRequest("readonly", tree.revision,
            "field", action, SemanticActionSource.Accessibility)).code, "node-readonly")
    }
    @Expect(runtime.dispatch(SemanticActionRequest("readonly", tree.revision,
        "field", SemanticActionKind.Focus, SemanticActionSource.Agent)).code, "source-not-allowed")
    @Expect(counter.count, 1)
}

@Test
func readonlyNativeFocusUsesTheOwnerQueueAndFinalRuntimePolicy(): Unit {
    let counter = ReadonlySemanticCounter()
    let runtime = SemanticRuntime("readonly", handler: {_ => counter.count += 1; true})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", ControlSemantics("textfield",
        actionOwner: "field", readOnly: Some(true), typedActions: [SemanticActionKind.Focus]))
    let tree = runtime.commitFrame()
    let session = SemanticNativeSession("readonly")
    session.publish(tree)
    let queue = UiOwnerQueue()
    let id = session.snapshot().getOrThrow().binding("field").getOrThrow().nativeId
    let focused = session.postAction(queue, id, tree.revision, SemanticActionKind.Focus,
        {request => if (!runtime.dispatch(request).ok) { throw IllegalStateException("focus rejected") }})
    let mutation = session.postAction(queue, id, tree.revision, SemanticActionKind.Activate,
        {_ => counter.count += 10})
    @Expect(counter.count, 0)
    queue.drain()
    @Expect(focused.receipt().getOrThrow().status == UiOwnerTaskStatus.Committed)
    @Expect(mutation.receipt().getOrThrow().status == UiOwnerTaskStatus.Failed)
    @Expect(counter.count, 1)
}

@Test
func readonlyFocusDoesNotInventActionsOrEnableDisabledNodes(): Unit {
    let disabled = SemanticNode("off", Rect.zero(), "TextField", "textfield",
        enabled: false, readOnly: true, actions: [SemanticActionKind.Focus])
    let passive = SemanticNode("passive", Rect.zero(), "TextArea", "textarea",
        readOnly: true, actions: [])
    @Expect(disabled.actions.isEmpty())
    @Expect(passive.actions.isEmpty())
}
