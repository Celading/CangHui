package cuic

@Test
func shellWindowSelectionIsExplicitAndDoesNotConsumeScriptText(): Unit {
    let selection = parseUiShellRun([".", "--window", "settings", "--events", "text --window"], 0)
    @Expect(selection.windowId, "settings")
    @Expect(selection.script, "text --window")
    for (args in [["--window"], ["--window", ""], ["--window", "--events", "snapshot"],
        ["--window", "a", "--window", "b", "--events", "snapshot"]]) {
        var rejected = false
        try { let _ = parseUiShellRun(args, 0) } catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func shellWindowRequiresSourceSupportAndActualRuntimeAcknowledgment(): Unit {
    requireUiShellWindowSource("missing-source", "")
    var rejected = false
    try { requireUiShellWindowSource("missing-source", "target") }
    catch (_: CuicError) { rejected = true }
    @Expect(rejected)
    requireUiShellWindowSource(integratedFrameworkRoot(), "target")
    verifyUiShellWindowSelection("target", Some("target"))
    for (actual in [None<String>, Some("primary")]) {
        var failed = false
        try { verifyUiShellWindowSelection("target", actual) }
        catch (_: CuicError) { failed = true }
        @Expect(failed)
    }
}

@When[debug]
@Test
func shellWindowEnvironmentDoesNotInheritAmbientSelector(): Unit {
    let context = ExecutionContext("/tmp/consumer", "/tmp/framework")
    let explicit = uiShellEnvironment(context, "snapshot", windowId: "target", selectionReceipt: "/tmp/receipt")
    @Expect(explicit.get("CANGHUI_DEBUG_UI_WINDOW").getOrThrow(), "target")
    @Expect(explicit.get("CANGHUI_DEBUG_UI_WINDOW_RECEIPT").getOrThrow(), "/tmp/receipt")
    let plain = uiShellEnvironment(context, "snapshot")
    @Expect(plain.get("CANGHUI_DEBUG_UI_WINDOW").getOrThrow(), "")
    @Expect(plain.get("CANGHUI_DEBUG_UI_WINDOW_RECEIPT").getOrThrow(), "")
}
