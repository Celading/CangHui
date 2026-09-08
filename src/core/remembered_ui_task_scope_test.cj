package chui.core

import std.sync.AtomicBool

private func mountRememberedTask(store: StateStore, queue: UiOwnerQueue): UiTaskScope {
    let result = State<?UiTaskScope>(None)
    let _ = buildRoot({=>
        result.value = Some(rememberUiTaskScope("load", queue))
        Spacer()
    }, store)
    result.value.getOrThrow()
}

@Test
func rememberedTaskUnmountClosesScopeButNotSharedQueue(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let first = mountRememberedTask(store, queue)
    let same = mountRememberedTask(store, queue)
    @Expect(refEq((first as Object).getOrThrow(), (same as Object).getOrThrow()))
    let _ = buildRoot({=> Spacer()}, store)
    @Expect(first.isClosed())
    let rejected = first.submit({=> Int64(1)}, {_ => ()})
    @Expect(rejected.status(), UiTaskSubmissionStatus.RejectedClosed)
    let applied = State<Int64>(0)
    let ticket = queue.post({=> applied.value = 1})
    let _ = queue.drain()
    @Expect(applied.value, 1)
    @Expect(ticket.receipt().isSome())
    let remounted = mountRememberedTask(store, queue)
    @Expect(!remounted.isClosed())
    @Expect(!refEq((first as Object).getOrThrow(), (remounted as Object).getOrThrow()))
    store.clear()
    @Expect(remounted.isClosed())
}

@Test
func rememberedTaskUnmountCancelsAlreadyQueuedApply(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let scope = mountRememberedTask(store, queue)
    let applied = State<Int64>(0)
    let task = scope.submit({=> Int64(7)}, {value => applied.value = value})
    var attempts = 5000
    while (!queue.hasPending() && attempts > 0) { sleep(Duration.millisecond); attempts -= 1 }
    @Expect(queue.hasPending())
    let _ = buildRoot({=> Spacer()}, store)
    let _ = queue.drain()
    @Expect(applied.value, 0)
    @Expect(task.status(), UiTaskSubmissionStatus.Cancelled)
}

@Test
func rememberedTaskUnmountCancelsPreparingWorker(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let scope = mountRememberedTask(store, queue)
    let release = AtomicBool(false)
    let finished = AtomicBool(false)
    let started = AtomicBool(false)
    let applied = State<Int64>(0)
    let task = scope.submit({=>
        started.store(true)
        while (!release.load()) { sleep(Duration.millisecond) }
        finished.store(true)
        Int64(9)
    }, {value => applied.value = value})
    try {
        var attempts = 5000
        while (!started.load() && attempts > 0) { sleep(Duration.millisecond); attempts -= 1 }
        @Expect(started.load())
        let _ = buildRoot({=> Spacer()}, store)
    } finally { release.store(true) }
    var attempts = 5000
    while (!finished.load() && attempts > 0) { sleep(Duration.millisecond); attempts -= 1 }
    @Expect(finished.load())
    let _ = queue.drain()
    @Expect(applied.value, 0)
    @Expect(task.status(), UiTaskSubmissionStatus.Cancelled)
}

@Test
func rememberedTaskRetainedOmissionCommitsOnlyAfterPresent(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let scope = mountRememberedTask(store, queue)
    let _ = buildRetainedRoot({=> Spacer()}, store, 1)
    @Expect(!scope.isClosed())
    store.cancelRetainedFrame()
    @Expect(!scope.isClosed())
    let same = mountRememberedTask(store, queue)
    @Expect(refEq((scope as Object).getOrThrow(), (same as Object).getOrThrow()))
    let _ = buildRetainedRoot({=> Spacer()}, store, 1)
    let _ = store.finishRetainedFrame()
    @Expect(scope.isClosed())
}

@Test
func rememberedTaskRollbackClosesOnlyNewEntries(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let old = mountRememberedTask(store, queue)
    let fresh = State<?UiTaskScope>(None)
    var threw = false
    try {
        let _ = buildRoot({=>
            fresh.value = Some(rememberUiTaskScope("new", queue))
            throw IllegalStateException("failed build")
        }, store)
    } catch (_: IllegalStateException) { threw = true }
    @Expect(threw)
    @Expect(fresh.value.getOrThrow().isClosed())
    @Expect(!old.isClosed())
    let _ = buildRetainedRoot({=>
        fresh.value = Some(rememberUiTaskScope("new", queue))
        Spacer()
    }, store, 1)
    @Expect(!fresh.value.getOrThrow().isClosed())
    store.cancelRetainedFrame()
    @Expect(fresh.value.getOrThrow().isClosed())
    @Expect(!old.isClosed())
    store.clear()
    @Expect(old.isClosed())
}

@Test
func rememberedTaskRejectsOwnerPolicyAndKeyCollisions(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let original = mountRememberedTask(store, queue)
    var failures = 0
    try { let _ = mountRememberedTask(store, UiOwnerQueue()) }
    catch (_: IllegalStateException) { failures += 1 }
    try { let _ = buildRoot({=>
        let _ = rememberUiTaskScope("load", queue, policy: UiTaskPolicy.SingleFlight)
    }, store) } catch (_: IllegalStateException) { failures += 1 }
    try { let _ = buildRoot({=>
        let _ = rememberUiTaskScope("load", queue)
        let _ = rememberUiTaskScope("load", queue)
    }, store) } catch (_: IllegalStateException) { failures += 1 }
    try { let _ = buildRoot({=>
        let _ = rememberState<Int64>("load") {0}
    }, store) } catch (_: IllegalStateException) { failures += 1 }
    try { let _ = rememberUiTaskScope("outside", queue) }
    catch (_: IllegalStateException) { failures += 1 }
    @Expect(failures, 5)
    @Expect(!original.isClosed())
    store.clear()
}

@Test
func rememberedTaskDoesNotDisposeBorrowedStateValues(): Unit {
    let store = StateStore()
    let queue = UiOwnerQueue()
    let borrowed = UiTaskScope("shared", queue)
    let _ = buildRoot({=>
        let _ = rememberState<UiTaskScope>("borrowed") {borrowed}
    }, store)
    store.clear()
    @Expect(!borrowed.isClosed())
    borrowed.close()
}
