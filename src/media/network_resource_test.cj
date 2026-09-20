package chui.media

import std.fs.{Directory, File, exists, removeIfExists}
import std.io.InputStream
import std.sync.AtomicBool
import chui.core.{UiOwnerQueue, UiTaskScope, UiTaskPolicy, UiTaskSubmissionStatus}
import chui.core.{UiContext, Theme}
import sdl.{Renderer, Rect}

private class ResourceTestStream <: InputStream {
    let bytes: Array<UInt8>
    var offset: Int64 = 0
    var reads: Int64 = 0
    var fail = false
    var negative = false
    var onRead: () -> Unit = { => () }
    init(bytes: Array<UInt8>) { this.bytes = bytes }
    public func read(buffer: Array<UInt8>): Int64 {
        reads += 1; onRead()
        if (fail) { throw Exception("SECRET provider URL") }
        if (negative) { return -1 }
        let n = min(buffer.size, bytes.size - offset)
        for (i in 0..n) { buffer[i] = bytes[offset + i] }
        offset += n; n
    }
}

private func expectResourceFailure(code: String, action: () -> Unit): Unit {
    var caught = false
    try { action() } catch (error: NetworkResourceException) {
        caught = true; @Expect(error.code, code); @Expect(!error.message.contains("SECRET"))
    }
    @Expect(caught)
}

private func resourceTestRoot(): String { Directory.createTemp("target").toString() }

@Test
func networkResourceFailureResultReachesOwnerQueueRatherThanStrandingLoadingState(): Unit {
    let root = resourceTestRoot()
    let queue = UiOwnerQueue(); let scope = UiTaskScope("failure-result", queue)
    let applied = AtomicBool(false)
    try {
        try (loader = NetworkResourceLoader(CallbackResourceTransport({_, _ => throw Exception("SECRET")}), root, ["https://a.test"])) {
            let task = scope.submit({=> loader.fetchResult(NetworkResourceRequest("https://a.test/x"))}, {result =>
                match (result) {
                    case NetworkResourceResult.Failed(code) => @Expect(code, "transport-or-storage")
                    case NetworkResourceResult.Ready(_) => @Expect(false)
                }
                applied.store(true)
            })
            for (_ in 0..5000) { if (queue.hasPending()) { break }; sleep(Duration.millisecond) }
            @Expect(!applied.load()); let _ = queue.drain()
            @Expect(applied.load()); @Expect(task.status() == UiTaskSubmissionStatus.Committed)
        }
    } finally { scope.close(); let _ = removeIfExists(root) }
}

@Test
func networkResourceValidatesRequestsAndExactOriginBeforeTransport(): Unit {
    expectResourceFailure("invalid-scheme", {=> let _ = NetworkResourceRequest("file:///private/key")})
    expectResourceFailure("invalid-origin", {=> let _ = NetworkResourceRequest("https://user:pass@a.test/x")})
    expectResourceFailure("invalid-url", {=> let _ = NetworkResourceRequest("https://a.test/x\r\nsecret")})
    expectResourceFailure("reserved-header", {=> let _ = NetworkResourceRequest("https://a.test/x", headers: [("Host", "evil")])})
    expectResourceFailure("invalid-header", {=> let _ = NetworkResourceRequest("https://a.test/x", headers: [("X-Test", "a\r\nb")])})
    let root = resourceTestRoot()
    let transport = CallbackResourceTransport({_, _ => throw Exception("must not run")})
    try {
        expectResourceFailure("invalid-origin", {=> let _ = NetworkResourceLoader(transport, root, ["http://a.test"])})
        try (loader = NetworkResourceLoader(transport, root, ["https://a.test"])) {
            expectResourceFailure("origin-denied", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test.evil/x"))})
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceWritesOnlyCompletedBytesAndReleasesOwnedFile(): Unit {
    let root = resourceTestRoot()
    let stream = ResourceTestStream([1, 2, 3, 4])
    let closed = AtomicBool(false)
    let transport = CallbackResourceTransport({_, _ =>
        NetworkResourceResponse(200, stream, {=> closed.store(true)}, contentLength: Some(4))})
    try {
        try (loader = NetworkResourceLoader(transport, root, ["https://a.test"])) {
            let file = loader.fetch(NetworkResourceRequest("https://a.test/download?secret=hidden"))
            let path = file.path()
            @Expect(File.readFrom(path), [UInt8(1), 2, 3, 4])
            @Expect(file.sizeBytes(), 4); @Expect(closed.load()); @Expect(exists(path))
            file.close(); file.close(); @Expect(!exists(path))
            expectResourceFailure("file-unavailable", {=> let _ = file.path()})
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceRejectsStatusEncodingMimeAndDeclaredOverflowWithoutReads(): Unit {
    let root = resourceTestRoot()
    let stream = ResourceTestStream([1, 2])
    let responses = [
        ("http-status", NetworkResourceResponse(302, stream, {=> ()})),
        ("content-encoding", NetworkResourceResponse(200, stream, {=> ()}, contentEncoding: "gzip")),
        ("content-type", NetworkResourceResponse(200, stream, {=> ()}, mediaType: "text/html")),
        ("too-large", NetworkResourceResponse(200, stream, {=> ()}, contentLength: Some(9)))
    ]
    try {
        for ((code, response) in responses) {
            let transport = CallbackResourceTransport({_, _ => response})
            try (loader = NetworkResourceLoader(transport, root, ["https://a.test"],
                options: NetworkResourceOptions(maxResponseBytes: 4))) {
                expectResourceFailure(code, {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x", kind: NetworkResourceKind.Png))})
                @Expect(response.isClosed()); @Expect(stream.reads, 0)
            }
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceEnforcesActualSizeUnknownLengthAndEarlyEof(): Unit {
    let root = resourceTestRoot()
    try {
        let cases: Array<(?Int64, Int64, String)> = [(None, 6, "too-large"), (Some(4), 2, "length-mismatch"),
            (Some(1), 2, "length-mismatch"), (None, 0, "empty-body")]
        for ((length, count, code) in cases) {
            let response = NetworkResourceResponse(200, ResourceTestStream(Array<UInt8>(count, repeat: 3)), {=> ()}, contentLength: length)
            try (loader = NetworkResourceLoader(CallbackResourceTransport({_, _ => response}), root,
                ["https://a.test"], options: NetworkResourceOptions(maxResponseBytes: 4))) {
                expectResourceFailure(code, {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"))})
                @Expect(response.isClosed())
            }
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceRetainedBudgetAndEntryCapacityRequireRelease(): Unit {
    let root = resourceTestRoot()
    let transport = CallbackResourceTransport({_, _ => NetworkResourceResponse(200, ResourceTestStream([1, 2, 3]), {=> ()})})
    try {
        try (loader = NetworkResourceLoader(transport, root, ["https://a.test"],
            options: NetworkResourceOptions(maxResponseBytes: 4, maxRetainedBytes: 6, maxFiles: 1, maxConcurrent: 1))) {
            let file = loader.fetch(NetworkResourceRequest("https://a.test/one"))
            expectResourceFailure("capacity", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/two"))})
            file.close()
            let replacement = loader.fetch(NetworkResourceRequest("https://a.test/two"))
            let path = replacement.path()
            loader.close(); @Expect(!exists(path))
            expectResourceFailure("closed", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"))})
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceCancelsDuringReadAndRedactsProviderErrors(): Unit {
    let root = resourceTestRoot()
    let control = NetworkResourceControl()
    let stream = ResourceTestStream([1, 2, 3]); stream.onRead = {=> control.cancel()}
    let response = NetworkResourceResponse(200, stream, {=> ()})
    try {
        try (loader = NetworkResourceLoader(CallbackResourceTransport({_, _ => response}), root, ["https://a.test"])) {
            expectResourceFailure("cancelled", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"), control: control)})
            @Expect(response.isClosed())
        }
        let bad = ResourceTestStream([1]); bad.fail = true
        try (loader = NetworkResourceLoader(CallbackResourceTransport({_, _ => NetworkResourceResponse(200, bad, {=> ()})}), root, ["https://a.test"])) {
            expectResourceFailure("transport-or-storage", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"))})
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceDeadlineAndInvalidReadFailWithCleanup(): Unit {
    let root = resourceTestRoot()
    try {
        let delayed = CallbackResourceTransport({_, _ =>
            sleep(Duration.millisecond * 10)
            NetworkResourceResponse(200, ResourceTestStream([1]), {=> ()})
        })
        try (loader = NetworkResourceLoader(delayed, root, ["https://a.test"])) {
            expectResourceFailure("timeout", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x", timeoutMs: 1))})
        }
        let bad = ResourceTestStream([1]); bad.negative = true
        try (loader = NetworkResourceLoader(CallbackResourceTransport({_, _ => NetworkResourceResponse(200, bad, {=> ()})}), root, ["https://a.test"])) {
            expectResourceFailure("invalid-read", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"))})
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceUsesExistingUiScopeAndClosesInFlightWithoutStateMutation(): Unit {
    let root = resourceTestRoot()
    let entered = AtomicBool(false); let proceed = AtomicBool(false); let applied = AtomicBool(false)
    let transport = CallbackResourceTransport({_, _ =>
        entered.store(true)
        while (!proceed.load()) { sleep(Duration.millisecond) }
        NetworkResourceResponse(200, ResourceTestStream([1]), {=> ()})
    })
    let queue = UiOwnerQueue(); let scope = UiTaskScope("resource", queue, policy: UiTaskPolicy.SingleFlight)
    let loader = NetworkResourceLoader(transport, root, ["https://a.test"],
        options: NetworkResourceOptions(maxFiles: 1, maxConcurrent: 1))
    try {
        let task = scope.submit({=> loader.fetch(NetworkResourceRequest("https://a.test/x"))}, {_ => applied.store(true)})
        for (_ in 0..5000) { if (entered.load()) { break }; sleep(Duration.millisecond) }
        @Expect(entered.load())
        expectResourceFailure("capacity", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/y"))})
        loader.close(); proceed.store(true)
        for (_ in 0..5000) { if (task.status() == UiTaskSubmissionStatus.FailedPreparation) { break }; sleep(Duration.millisecond) }
        @Expect(task.status() == UiTaskSubmissionStatus.FailedPreparation)
        @Expect(!applied.load()); @Expect(!queue.hasPending())
    } finally { proceed.store(true); scope.close(); loader.close(); let _ = removeIfExists(root) }
}

@Test
func networkResourceByteReservationAndCancellationBeforeOpenAreBounded(): Unit {
    let root = resourceTestRoot()
    let transport = CallbackResourceTransport({_, _ => NetworkResourceResponse(200, ResourceTestStream([1, 2, 3]), {=> ()})})
    try {
        try (loader = NetworkResourceLoader(transport, root, ["https://a.test"],
            options: NetworkResourceOptions(maxResponseBytes: 4, maxRetainedBytes: 6))) {
            let first = loader.fetch(NetworkResourceRequest("https://a.test/x"))
            // File count permits another; actual bytes plus its reservation do not.
            expectResourceFailure("capacity", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/y"))})
            first.close()
            let control = NetworkResourceControl(); control.cancel()
            expectResourceFailure("cancelled", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/y"), control: control)})
            let next = loader.fetch(NetworkResourceRequest("https://a.test/y")); @Expect(next.sizeBytes(), 3)
        }
    } finally { let _ = removeIfExists(root) }
}

@Test
func networkResourceRetriesFailuresWithoutRetainingSlotsOrLeakingUrlIntoImageFacts(): Unit {
    let root = resourceTestRoot()
    let failing = CallbackResourceTransport({_, _ => throw Exception("SECRET header/URL")})
    try {
        try (loader = NetworkResourceLoader(failing, root, ["https://a.test"],
            options: NetworkResourceOptions(maxFiles: 1, maxConcurrent: 1))) {
            for (_ in 0..20) {
                expectResourceFailure("transport-or-storage", {=> let _ = loader.fetch(NetworkResourceRequest("https://a.test/x"))})
            }
        }
        let provider = CallbackResourceTransport({_, _ => NetworkResourceResponse(200,
            ResourceTestStream([1, 2, 3]), {=> ()}, mediaType: "image/png")})
        try (loader = NetworkResourceLoader(provider, root, ["https://a.test"])) {
            let file = loader.fetch(NetworkResourceRequest("https://a.test/x?SECRET=token", kind: NetworkResourceKind.Png))
            let view = ImageView.fromNetworkResource(file)
            let renderer = Renderer.recordingHeadless(); let ctx = UiContext(renderer, Theme.light())
            for (fact in view.designComputedFacts(ctx)) {
                @Expect(!fact.toJson().contains("SECRET")); @Expect(!fact.toJson().contains(root))
            }
            file.close(); view.layout(ctx, Rect(0.0, 0.0, 16.0, 16.0)); view.draw(ctx)
            @Expect(renderer.drawIr().size, 0)
        }
    } finally { let _ = removeIfExists(root) }
}
