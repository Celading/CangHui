package chui.desktop

import std.collection.ArrayList
import std.env.getVariable
import chui.core.{Button, ControlSemantics, FrameHandler, SemanticActionKind, SemanticInteractionPolicy,
    SemanticNativeSnapshot, SemanticNode, SemanticRuntime, SemanticTreeSnapshot,
    UiOwnerQueue, UiOwnerTaskStatus}
import sdl.{Rect, WindowSpec, WindowScaleSettings, UiEvent, MouseButton, Key}

private class AccessibilityTestAdapter <: DesktopAccessibilityAdapter {
    var latest: ?SemanticNativeSnapshot = None
    let inbox = ArrayList<DesktopAccessibilityAction>()
    let focus = ArrayList<Bool>()
    var closes: Int64 = 0
    var failPublish = false
    var failPoll = false
    var failClose = false
    var onPoll: () -> Unit = {=> ()}

    public func publish(snapshot: SemanticNativeSnapshot): Unit {
        if (failPublish) { throw IllegalStateException("publish-origin") }
        latest = Some(snapshot)
    }
    public func setWindowFocused(value: Bool): Unit { focus.add(value) }
    public func poll(): ?DesktopAccessibilityAction {
        if (failPoll) { throw IllegalStateException("poll-origin") }
        onPoll()
        if (inbox.isEmpty()) { return None }
        let action = inbox[0]
        inbox.remove(at: 0)
        Some(action)
    }
    func click(): Unit {
        let frame = latest.getOrThrow()
        inbox.add(DesktopAccessibilityAction(frame.binding("save").getOrThrow().nativeId,
            frame.tree.revision, SemanticActionKind.Activate))
    }
    public func close(): Unit {
        closes += 1
        if (failClose) { throw IllegalStateException("close-secondary") }
    }
    public func isClosed(): Bool { closes > 0 }
}

private class AccessibilityCount { var calls: Int64 = 0 }

private class AccessibilityGeometryRecorder <: DesktopAccessibilityAdapter & DesktopAccessibilityGeometryAdapter {
    var geometry: ?DesktopAccessibilityGeometry = None
    var logicalWidth: Float32 = -1.0
    var expectedWidth: Float32 = -1.0
    var closed = false
    var published: () -> Unit = {=> ()}

    public func setWindowGeometry(value: DesktopAccessibilityGeometry): Unit { geometry = Some(value) }
    public func publish(snapshot: SemanticNativeSnapshot): Unit {
        logicalWidth = snapshot.tree.node("stretch").getOrThrow().frame.w
        expectedWidth = Float32(geometry.getOrThrow().metrics.logicalWidth)
        published()
    }
    public func setWindowFocused(_: Bool): Unit { () }
    public func poll(): ?DesktopAccessibilityAction { None }
    public func close(): Unit { closed = true }
    public func isClosed(): Bool { closed }
}

@Test
func accessibilitySingleWindowOwnerScalePublishesMatchingLayoutAndGeometry(): Unit {
    if (accessibilityWindowTestSkipped()) { return }
    let backend = AccessibilityGeometryRecorder()
    let app = DesktopApp(WindowSpec("Accessibility owner scale", 240, 120, vsync: false,
        highDpi: false, supersample: 1), accessibility: Some({_, _ => backend}))
    backend.published = {=> app.requestWindowClose() }
    let activations = AccessibilityCount()
    app.queuePointerClick(20.0, 10.0)
    let _ = app.postToUi({=> app.setScaling(WindowScaleSettings(followSystem: false, zoom: 2.0)) })
    app.run({=> Button("Stretch", {=> activations.calls += 1 }).key("stretch") })
    @Expect(backend.logicalWidth, backend.expectedWidth)
    @Expect(backend.expectedWidth, 120.0)
    @Expect(backend.closed)
    @Expect(activations.calls, 0)
}

@Test
func accessibilitySingleWindowFrameScalePublishesMatchingLayoutAndGeometry(): Unit {
    if (accessibilityWindowTestSkipped()) { return }
    let backend = AccessibilityGeometryRecorder()
    let app = DesktopApp(WindowSpec("Accessibility frame scale", 240, 120, vsync: false,
        highDpi: false, supersample: 1), accessibility: Some({_, _ => backend}))
    backend.published = {=> app.requestWindowClose() }
    app.run({=> FrameHandler(onFrame: {_ =>
        app.setScaling(WindowScaleSettings(followSystem: false, zoom: 2.0))
    }) { Button("Stretch", {=> ()}).key("stretch") } })
    @Expect(backend.logicalWidth, backend.expectedWidth)
    @Expect(backend.expectedWidth, 120.0)
}

@Test
func accessibilityManagedWindowFrameScalePublishesMatchingLayoutAndGeometry(): Unit {
    if (accessibilityWindowTestSkipped()) { return }
    let backend = AccessibilityGeometryRecorder()
    let app = DesktopApplication(accessibility: Some({_, _ => backend}))
    try {
        let _ = app.openWindow(WindowSpec("Accessibility managed frame scale", 240, 120,
            vsync: false, highDpi: false, supersample: 1), {=>
            FrameHandler(onFrame: {_ =>
                let _ = app.setWindowScaling(app.activeWindow().getOrThrow(),
                    WindowScaleSettings(followSystem: false, zoom: 2.0))
            }) { Button("Stretch", {=> ()}).key("stretch") }
        })
        @Expect(backend.logicalWidth, backend.expectedWidth)
        @Expect(backend.expectedWidth, 120.0)
    } finally { app.close() }
    @Expect(backend.closed)
}

@Test
func collectedCoordinatesCannotCrossAnOwnerTransformReplacement(): Unit {
    for (event in [UiEvent.MouseMove(20.0, 12.0), UiEvent.MouseDown(MouseButton.Left, 20.0, 12.0),
        UiEvent.MouseUp(MouseButton.Left, 20.0, 12.0), UiEvent.MouseWheel(0.0, 1.0, 20.0, 12.0)]) {
        let collected = DesktopCollectedEvent(event, UInt64(3))
        @Expect(collected.validAt(UInt64(3)))
        @Expect(!collected.validAt(UInt64(4)))
    }
    for (event in [UiEvent.KeyDown(Key.Enter, false), UiEvent.PointerCancelled, UiEvent.Quit]) {
        @Expect(DesktopCollectedEvent(event, UInt64(3)).validAt(UInt64(4)))
    }
}

private func accessibilityTree(revision: UInt64): SemanticTreeSnapshot {
    SemanticTreeSnapshot("main", revision, [SemanticNode("save", Rect.zero(), "Button", "button",
        actions: [SemanticActionKind.Activate])])
}

@Test
func accessibilityHostUsesCurrentRuntimeAndExistingQueueAfterUnchangedFrames(): Unit {
    let backend = AccessibilityTestAdapter()
    let queue = UiOwnerQueue()
    let count = AccessibilityCount()
    let runtime = SemanticRuntime("main", handler: {_ => count.calls += 1; true})
    let host = DesktopSemanticAccessibility("main", backend, queue, {request => runtime.dispatch(request)})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "save"))
    host.publish(runtime.commitFrame())
    backend.click()
    host.service(false)
    @Expect(count.calls, 0)
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "save"))
    host.publish(runtime.commitFrame())
    let receipts = queue.drain()
    @Expect(receipts.size, 1)
    @Expect(receipts[0].status == UiOwnerTaskStatus.Committed)
    @Expect(count.calls, 1)
    host.service(true)
    @Expect(backend.focus.toArray(), [false, true])
    host.close()
    host.close()
    @Expect(backend.closes, 1)
}

@Test
func accessibilityHostPollingIsBoundedAndCloseRevokesAlreadyQueuedActions(): Unit {
    let backend = AccessibilityTestAdapter()
    let queue = UiOwnerQueue()
    let runtime = SemanticRuntime("main")
    let host = DesktopSemanticAccessibility("main", backend, queue, {request => runtime.dispatch(request)})
    host.publish(accessibilityTree(UInt64(1)))
    for (_ in 0..130) { backend.click() }
    host.service(false)
    @Expect(backend.inbox.size, 2)
    host.close()
    host.service(true)
    host.publish(accessibilityTree(UInt64(2)))
    @Expect(backend.latest.getOrThrow().tree.revision, UInt64(1))
    @Expect(backend.focus.size, 1)
    let receipts = queue.drain()
    @Expect(receipts.size, 128)
    for (receipt in receipts) { @Expect(receipt.status == UiOwnerTaskStatus.Failed) }
    @Expect(backend.closes, 1)
}

@Test
func accessibilityHostFailureRevokesWorkAndPreservesOriginalBackendError(): Unit {
    for (failure in ["publish", "poll"]) {
        let backend = AccessibilityTestAdapter()
        let queue = UiOwnerQueue()
        let runtime = SemanticRuntime("main")
        let host = DesktopSemanticAccessibility("main", backend, queue, {request => runtime.dispatch(request)})
        host.publish(accessibilityTree(UInt64(1)))
        backend.click()
        host.service(false)
        backend.failClose = true
        backend.failPublish = failure == "publish"
        backend.failPoll = failure == "poll"
        var message = "missing-error"
        try {
            if (failure == "publish") { host.publish(accessibilityTree(UInt64(2))) }
            else { host.service(true) }
        } catch (error: Exception) { message = error.message }
        @Expect(message, failure + "-origin")
        @Expect(backend.closes, 1)
        @Expect(queue.drain()[0].status == UiOwnerTaskStatus.Failed)
        host.close()
        @Expect(backend.closes, 1)
    }
}

@Test
func accessibilityHostDoesNotBypassRuntimeSourcePolicy(): Unit {
    let backend = AccessibilityTestAdapter()
    let queue = UiOwnerQueue()
    let count = AccessibilityCount()
    let runtime = SemanticRuntime("main", policy: SemanticInteractionPolicy(accessibility: false),
        handler: {_ => count.calls += 1; true})
    let host = DesktopSemanticAccessibility("main", backend, queue, {request => runtime.dispatch(request)})
    runtime.beginFrame()
    runtime.record(Rect.zero(), "Button", ControlSemantics("button", actionOwner: "save"))
    host.publish(runtime.commitFrame())
    backend.click()
    host.service(true)
    let receipt = queue.drain()[0]
    @Expect(receipt.status == UiOwnerTaskStatus.Failed)
    @Expect(receipt.message.contains("source-not-allowed"))
    @Expect(count.calls, 0)
    host.close()
}

private func accessibilityWindowTestSkipped(): Bool {
    let value = getVariable("CANGHUI_SKIP_NATIVE_WINDOW_SMOKE") ?? ""
    if (value == "1" || value == "true") {
        println("[desktop-accessibility] native window test explicitly skipped")
        return true
    }
    false
}

@Test
func accessibilityManagedWindowsKeepAdaptersAndActionsIsolatedAndCloseAllOnFailure(): Unit {
    if (accessibilityWindowTestSkipped()) { return }
    let adapters = ArrayList<AccessibilityTestAdapter>()
    let ids = ArrayList<String>()
    let count = AccessibilityCount()
    let app = DesktopApplication(accessibility: Some({id, title =>
        ids.add(id)
        @Expect(title.startsWith("Accessibility "))
        let backend = AccessibilityTestAdapter()
        adapters.add(backend)
        backend
    }))
    try {
        let first = app.openWindow(WindowSpec("Accessibility first", 180, 100, vsync: false,
            highDpi: false, supersample: 1), {=> Button("Save", {=> count.calls += 1}).key("save") },
            semanticWindowId: "one")
        let second = app.openWindow(WindowSpec("Accessibility second", 180, 100, vsync: false,
            highDpi: false, supersample: 1), {=> Button("Save", {=> count.calls += 10}).key("save") },
            semanticWindowId: "two")
        @Expect(ids.toArray(), ["one", "two"])
        @Expect(adapters[0].latest.getOrThrow().tree.windowId, "one")
        @Expect(adapters[1].latest.getOrThrow().tree.windowId, "two")
        adapters[0].click()
        let _ = app.step()
        @Expect(count.calls, 1)
        adapters[1].click()
        let _ = app.step()
        @Expect(count.calls, 11)
        @Expect(app.windowState(first).isSome() && app.windowState(second).isSome())
        adapters[1].failClose = true
        var failure = "missing-error"
        try { app.close() } catch (error: Exception) { failure = error.message }
        @Expect(failure, "close-secondary")
        @Expect(app.isClosed())
        @Expect(app.sessionCount(), 0)
        @Expect(adapters[0].closes, 1)
        @Expect(adapters[1].closes, 1)
        println("[desktop-accessibility] two native windows: isolated actions and failing-adapter cleanup passed")
    } finally { app.close() }
}

@Test
func accessibilitySingleWindowPollWakesIdleOwnerAndClosesWithItsWindow(): Unit {
    if (accessibilityWindowTestSkipped()) { return }
    let backend = AccessibilityTestAdapter()
    let count = AccessibilityCount()
    let app = DesktopApp(WindowSpec("Accessibility idle", 180, 100, vsync: false,
        highDpi: false, supersample: 1), accessibility: Some({id, title =>
            @Expect(id, "main")
            @Expect(title, "Accessibility idle")
            backend
        }))
    // Leave several truly idle polls before inserting a copied native action.
    backend.onPoll = {=>
        count.calls += 1
        if (count.calls == 5) { backend.click() }
        if (count.calls > 20) { throw IllegalStateException("native action did not wake idle owner") }
    }
    let activations = AccessibilityCount()
    app.run({=> Button("Save", {=> activations.calls += 1; app.requestWindowClose()}).key("save") })
    @Expect(activations.calls, 1)
    @Expect(count.calls >= 5 && count.calls <= 20)
    @Expect(backend.closes, 1)
    println("[desktop-accessibility] single native window: idle owner wake and close passed")
}
