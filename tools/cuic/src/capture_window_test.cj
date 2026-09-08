package cuic

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
