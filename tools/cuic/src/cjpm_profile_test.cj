package cuic

@Test
func cjpmProfileSelectsExactBuildAndTestMode(): Unit {
    @Expect(cjpmProfileArguments("build", "debug"), ["build", "-g"])
    @Expect(cjpmProfileArguments("test", "debug"), ["test", "-g"])
    @Expect(cjpmProfileArguments("build", "release"), ["build"])
    @Expect(cjpmProfileArguments("test", "release"), ["test"])
    let (selection, mode) = parseCjpmProfile(["mac", ".", "--mode", "debug"], 0)
    @Expect(selection.platform, "macos")
    @Expect(selection.project, currentDirectory())
    @Expect(mode, "debug")
    let (_, defaultMode) = parseCjpmProfile(["."], 0)
    @Expect(defaultMode, "release")
    let (implicit, earlyMode) = parseCjpmProfile(["--mode", "release"], 0)
    @Expect(implicit.project, currentDirectory())
    @Expect(earlyMode, "release")
}

@Test
func cjpmProfileRejectsMissingDuplicateAndIgnoredOptions(): Unit {
    for (args in [[".", "--mode"], [".", "--mode", "fast"], [".", "--mod", "debug"],
        [".", "extra"], [".", "--mode", "debug", "--mode", "release"]]) {
        var rejected = false
        try { let _ = parseCjpmProfile(args, 0) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}
