package cuic

import std.fs.{Directory, File, exists, removeIfExists}

@Test
func prntWindowUsesSemanticIdentityAndPreservesApplicationArguments(): Unit {
    let options = parsePrntOptions(["linux", ".", "--window", "settings", "--", "--window", "app-value"], 0)
    @Expect(options.windowId, "settings")
    @Expect(options.appArgs.toArray(), ["--window", "app-value"])
    @Expect(parsePrntOptions(["."], 0).windowId, "")
    for (args in [[".", "--window"], [".", "--window", ""],
        [".", "--window", "--frames"], [".", "--window", "a", "--window", "b"],
        [".", "--window", "a", "--device", "device"], [".", "--app", "bundle", "--window", "a"]]) {
        var failed = false
        try { let _ = parsePrntOptions(args, 0) } catch (_: CuicError) { failed = true }
        @Expect(failed)
    }
}

@Test
func captureWindowEnvironmentIsScopedToCaptureAndNotOrdinaryRuns(): Unit {
    @Expect(applicationEnvironment("/tmp/framework", "out.bmp", UInt64(2),
        captureWindow: "settings").get("CANGHUI_CAPTURE_WINDOW").getOrThrow(), "settings")
    @Expect(applicationEnvironment("/tmp/framework", "", UInt64(0),
        captureWindow: "settings").get("CANGHUI_CAPTURE_WINDOW").getOrThrow(), "")
    @Expect(applicationEnvironment("/tmp/framework", "out.bmp", UInt64(2),
        captureWindowReceipt: "/tmp/receipt").get("CANGHUI_CAPTURE_WINDOW_RECEIPT").getOrThrow(), "/tmp/receipt")
    @Expect(applicationEnvironment("/tmp/framework", "", UInt64(0),
        captureWindowReceipt: "/tmp/receipt").get("CANGHUI_CAPTURE_WINDOW_RECEIPT").getOrThrow(), "")
}

@Test
func captureWindowRejectsUnsupportedAndWrongRuntimeAcknowledgments(): Unit {
    verifyCaptureWindowSelection("", None)
    verifyCaptureWindowSelection("settings", Some("settings"))
    for (actual in [None<String>, Some("main"), Some("settings\n")]) {
        var failed = false
        try { verifyCaptureWindowSelection("settings", actual) }
        catch (_: CuicError) { failed = true }
        @Expect(failed)
    }
}

@Test
func captureReceiptCleanupFailureStillReleasesTheBuildLease(): Unit {
    let root = joinPath(currentDirectory(), "target/capture-lease-cleanup-fixture")
    if (exists(root)) { throw CuicError("capture lease fixture already exists") }
    let context = ExecutionContext(root, root, targetDir: joinPath(root, "build"), stagingRoot: root)
    let receipt = joinPath(root, "receipt")
    Directory.create(receipt, recursive: true)
    let retained = joinPath(receipt, "must-not-delete.txt")
    File.writeTo(retained, "retain malformed receipt contents".toArray())
    let lease = context.acquireLease()
    try {
        var failed = false
        try { cleanupCaptureSelection(context, receipt, lease) } catch (_: Exception) { failed = true }
        @Expect(failed)
        @Expect(!exists(lease))
        @Expect(exists(retained))
    } finally {
        context.releaseLease(lease)
        removeIfExists(retained); removeIfExists(receipt); removeIfExists(root)
    }
}
