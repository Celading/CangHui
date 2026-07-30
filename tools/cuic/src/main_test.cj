package cuic

@Test
func platformAliasesNormalize(): Unit {
    @Expect(normalizePlatform("mac"), "macos")
    @Expect(normalizePlatform("darwin"), "macos")
    @Expect(normalizePlatform("win"), "windows")
    @Expect(normalizePlatform("linux"), "linux")
}

@Test
func pathHelpersKeepRootAndBasenameStable(): Unit {
    @Expect(joinPath("/tmp/root/", "/child"), "/tmp/root/child")
    @Expect(parentPath("/tmp/root/child"), "/tmp/root")
    @Expect(basename("/tmp/root/child/"), "child")
}

@Test
func packageNamesAreCompilerFriendly(): Unit {
    @Expect(sanitizePackageName("Hello-CangUI"), "hello_cangui")
    @Expect(sanitizePackageName("2026 Demo"), "app_2026_demo")
}

@Test
func windowsAbsolutePathsAreRecognized(): Unit {
    @Expect(isWindowsAbsolute("C:\\work\\CangHui"))
    @Expect(!isWindowsAbsolute("examples/notepad"))
}

@Test
func harmonyFontCandidatesPreferInstalledMacFont(): Unit {
    let candidates = installedHarmonyFontCandidates("macos", "/Users/demo")
    @Expect(candidates[0], "/Users/demo/Library/Fonts/HarmonyOS_Sans_SC.ttf")
    @Expect(candidates[1], "/Users/demo/Library/Fonts/HarmonyOS Sans SC.ttf")
}

@Test
func bundledHarmonyFontIsTheDefaultCliResolution(): Unit {
    @Expect(resolveHarmonyFont("macos"), bundledHarmonyFont())
}

@Test
func kModeLinkScannerAcceptsOnlyCanonicalSingleLineForm(): Unit {
    @Expect(extractKModeLinkEndpoint("@KModeLink[\"app.echo\"]") ?? "", "app.echo")
    @Expect(extractKModeLinkEndpoint("  @KModeLink[\"app.version\"]  ") ?? "", "app.version")
    @Expect(extractKModeLinkEndpoint("@KModeLink [\"app.bad\"]").isNone())
    @Expect(extractKModeLinkEndpoint("// @KModeLink[\"app.comment\"]").isNone())
}

@Test
func probeScannerAcceptsOnlyCanonicalSingleLineForm(): Unit {
    @Expect(extractCuiProbeEndpoint("@CuiProbe[\"app.button\"]") ?? "", "app.button")
    @Expect(extractCuiProbeEndpoint("  @CuiProbe[\"app.version\"]  ") ?? "", "app.version")
    @Expect(extractCuiProbeEndpoint("@CuiProbe [\"app.bad\"]").isNone())
    @Expect(extractCuiProbeEndpoint("// @CuiProbe[\"app.comment\"]").isNone())
}

@Test
func kModeWireCodecPreservesUtf8AndPipes(): Unit {
    let encoded = encodeCuicKModeRequest(9, "invoke", "app.echo", "仓颉|ready")
    @Expect(containsText(encoded, "仓颉"), false)
    let response = decodeCuicKModeResponse(
        "canghui.kmode.v0|9|1|6f6b|" + encodeCuicKModeText("完成|ok") + "|0|"
    )
    @Expect(response.id, Int64(9))
    @Expect(response.payload, "完成|ok")
}

@Test
func kModeLauncherNoiseAllowsKnownCjpmPreambleOnly(): Unit {
    @Expect(isKModeLauncherNoise(""))
    @Expect(isKModeLauncherNoise("cjpm build success"))
    @Expect(isKModeLauncherNoise(
        "Warning: the functionality of 'CJPM_CONFIG' will be deprecated, please use cangjie-repo.toml"
    ))
    @Expect(!isKModeLauncherNoise("application wrote unexpected stdout"))
}

@Test
func kModeDependencyScannerStaysInsideDependencySections(): Unit {
    let paths = kModeLocalDependencyPaths(
        "[package]\n" +
        "description = \"path = not-a-dependency\"\n" +
        "[dependencies]\n" +
        "cui = { path = \"../CangHui\" }\n" +
        "[profile]\n" +
        "output-path = \"ignored\"\n"
    )
    @Expect(paths.size, 1)
    @Expect(paths[0], "../CangHui")
}

@Test
func integratedFrameworkRootWinsBeforeCompatibilityAliases(): Unit {
    let root = integratedFrameworkRoot()
    @Expect(root.endsWith("/CangjieGUI") || root.endsWith("/CangHui"))
    @Expect(frameworkRootCandidate(root))
}

@Test
func probeTargetParserPreservesScriptAndJsonMode(): Unit {
    let parsed = parseProbeTarget(
        ["cuic", "probe", "run", "component-gallery", "gallery.primary-button",
            "--events", "move-in 10 10\npress 10 10", "--json"],
        3,
        true
    )
    @Expect(parsed.name, "gallery.primary-button")
    @Expect(parsed.script, "move-in 10 10\npress 10 10")
    @Expect(parsed.json)
    @Expect(parsed.project.endsWith("/examples/component-gallery"))
}

@Test
func remoteDependencyRenderingPinsPublicCommitWithoutLocalPath(): Unit {
    let rendered = renderFrameworkDependency(defaultFrameworkDependencySpec())
    @Expect(rendered.contains("git = \"https://github.com/Celading/CangHui.git\""))
    @Expect(rendered.contains("commitId = \"a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02\""))
    @Expect(rendered.contains("/Users/"), false)
}

@Test
func inlineDependencyParserSeparatesGitCommitAndPathFields(): Unit {
    let remote = "cui = { git = \"https://example/CangHui.git\", commitId = \"abc123\" }"
    @Expect(extractInlineTomlString(remote, "git"), "https://example/CangHui.git")
    @Expect(extractInlineTomlString(remote, "commitId"), "abc123")
    @Expect(extractInlineTomlString(remote, "path"), "")
    let local = "cui = { path = \"../CangHui\" }"
    @Expect(extractInlineTomlString(local, "path"), "../CangHui")
}

@Test
func cjpmCachePathsExpandHomeForms(): Unit {
    @Expect(expandHomePath("$" + "{HOME}/cache", "/Users/demo"), "/Users/demo/cache")
    @Expect(expandHomePath("$HOME/cache", "/Users/demo"), "/Users/demo/cache")
    @Expect(expandHomePath("~/cache", "/Users/demo"), "/Users/demo/cache")
}

@Test
func repositoryCacheParserHonorsTheCjpmCacheSection(): Unit {
    let configured = repositoryCachePathFromText(
        "[repository.home]\n" +
        "registry = \"https://example.invalid\"\n" +
        "[repository.cache]\n" +
        "path = \"$" + "{HOME}/project-cache\"\n",
        "/Users/demo"
    )
    @Expect(configured, "/Users/demo/project-cache")
}
