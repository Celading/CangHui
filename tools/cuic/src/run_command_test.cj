package cuic

@Test
func runRejectsBadOptionsBeforeResolvingOrBuildingAProject(): Unit {
    for ((args, expected) in [
        (["cuic", "run", "/cuic-no-such-run-project", "--mode", "fast"], "run mode"),
        (["cuic", "run", "/cuic-no-such-run-project", "--mode"], "run requires"),
        (["cuic", "run", "/cuic-no-such-run-project", "--bogus"], "unexpected run argument"),
        (["cuic", "run", "/cuic-no-such-run-project", "extra"], "unexpected run argument")
    ]) {
        var rejected = false
        try { let _ = runCuicInternal(args, false) }
        catch (error: CuicError) { rejected = error.message.contains(expected) }
        @Expect(rejected)
    }
}

@Test
func ordinaryApplicationLaunchDoesNotInheritCaptureProcessorPinning(): Unit {
    let environment = applicationEnvironment("/tmp/canghui", "", UInt64(0))
    @Expect(environment.get("cjProcessorNum") ?? "", readEnv("cjProcessorNum"))
    @Expect(environment.get("CANGHUI_CAPTURE_PATH") ?? "missing", "")
}

@Test
func runSelectsExactProfilesAndForwardsOnlyExplicitAppArguments(): Unit {
    let selected = parseRunOptions(["mac", ".", "--mode", "debug", "--",
        "--mode", "literal value", "你好", "$(not-a-shell)"], 0)
    @Expect(selected.platform, "macos")
    @Expect(selected.project, currentDirectory())
    @Expect(selected.mode, "debug")
    @Expect(selected.appArgs, ["--mode", "literal value", "你好", "$(not-a-shell)"])
    let implicit = parseRunOptions(["--mode", "release"], 0)
    @Expect(implicit.project, currentDirectory())
    @Expect(implicit.mode, "release")
    @Expect(implicit.appArgs.size, Int64(0))
    @Expect(parseRunOptions(["."], 0).mode, "release")
}

@Test
func runRejectsDuplicateModesButLeavesApplicationFlagsUntouched(): Unit {
    var rejected = false
    try { let _ = parseRunOptions([".", "--mode", "debug", "--mode", "release"], 0) }
    catch (_: CuicError) { rejected = true }
    @Expect(rejected)
    @Expect(parseRunOptions([".", "--", "--mode", "invalid"], 0).appArgs,
        ["--mode", "invalid"])
}

@Test
func runKeepsBuiltinExampleResolution(): Unit {
    let expected = resolveProject("notepad", "")
    @Expect(parseRunOptions(["notepad"], 0).project, expected)
}
