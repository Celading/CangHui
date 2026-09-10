package cuic

import std.collection.HashMap

private func hardeningRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: Exception) { true }
}

@Test
func macHardeningIsExplicitAndKeepsNamedPluginExports(): Unit {
    @Expect(MacPackagingHardening().linkOptions(), "")
    let policy = MacPackagingHardening(enabled: true, exports: ["_plugin_host", "_api2"])
    @Expect(policy.exports, ["_main", "_plugin_host", "_api2"])
    @Expect(policy.exportList(), "_main\n_plugin_host\n_api2\n")
    @Expect(policy.linkOptions(), "-exported_symbol _main -exported_symbol _plugin_host -exported_symbol _api2")
    @Expect(hardeningRejects({=> let _ = MacPackagingHardening(exports: ["_api"]) }))
    @Expect(hardeningRejects({=> let _ = MacPackagingHardening(enabled: true, exports: ["_main"]) }))
    @Expect(hardeningRejects({=> let _ = MacPackagingHardening(enabled: true, exports: ["_api", "_api"]) }))
    @Expect(hardeningRejects({=> let _ = MacPackagingHardening(enabled: true, exports: Array<String>(129, repeat: "_api")) }))
}

@Test
func macExportPolicyRejectsPatternsAndOptionInjection(): Unit {
    for (name in ["", "_", "main", "-all", "_api*", "_api\n_main", "_a b", "_$(bad)", "_a/b", "_界面"]) {
        @Expect(!validMacExportSymbol(name))
        @Expect(hardeningRejects({=> let _ = MacPackagingHardening(enabled: true, exports: [name]) }))
    }
    @Expect(validMacExportSymbol("_canghui_callback_2"))
}

@Test
func packagingRootsPreserveSpaceAndUnicodeWithoutBroadening(): Unit {
    @Expect(quotedPackagingRoot("/tmp/My 工程"), "\"/tmp/My 工程/\"")
    @Expect(quotedPackagingRoot("/tmp/owner's app/"), "\"/tmp/owner's app/\"")
    for (root in ["/", "", "relative", "/tmp/a\nb", "/tmp/a\tb", "/tmp/a\"b", "/tmp/a\\b", "/tmp/$x", "/tmp/`x`"]) {
        @Expect(hardeningRejects({=> let _ = quotedPackagingRoot(root) }))
    }
}

@Test
func sdkTemplateBindingsAreOptInAndDoNotRewriteUserOptions(): Unit {
    let generated = sourceSdkInitLinkOption(true, "macos")
    requirePackagingBindings("[package]\n" + generated)
    let withFlags = generated.replace("override-compile-option = \"", "override-compile-option = \"-Woff unused ")
        .replace("link-option = \"-headerpad", "link-option = \"-dead_strip -headerpad")
    requirePackagingBindings("[package]\n" + withFlags + "[dependencies]\ncustom = {path = \"../custom\"}\n")
    @Expect(withFlags.contains("-Woff unused"))
    for (text in [generated, "[workspace]\n" + generated, "[package]\n# " + generated,
        "[package]\n" + generated.replace(PACKAGE_COMPILE_ENV, "OTHER"),
        "[package]\n" + generated.replace(PACKAGE_LINK_ENV, "OTHER")]) {
        @Expect(hardeningRejects({=> requirePackagingBindings(text) }))
    }
}

@Test
func ordinaryCjpmChildrenClearAmbientPackagingFlags(): Unit {
    let inherited = HashMap<String, String>()
    inherited.add(PACKAGE_COMPILE_ENV, "--strip-all")
    inherited.add(PACKAGE_LINK_ENV, "-exported_symbol _unexpected")
    inherited.add("MY_PROJECT_SETTING", "retain")
    let normal = packagingBuildEnvironment(inherited, "", "")
    @Expect(normal[PACKAGE_COMPILE_ENV], "")
    @Expect(normal[PACKAGE_LINK_ENV], "")
    @Expect(normal["MY_PROJECT_SETTING"], "retain")
    @Expect(inherited[PACKAGE_COMPILE_ENV], "--strip-all")
    let harden = packagingBuildEnvironment(inherited, "--trimpath /bounded/", "-exported_symbol _main")
    @Expect(harden[PACKAGE_COMPILE_ENV], "--trimpath /bounded/")
    @Expect(harden[PACKAGE_LINK_ENV], "-exported_symbol _main")
}

@Test
func packagingAuditCannotInheritShellHooksOrRelaxedLimits(): Unit {
    let env = packagingInspectorEnvironment()
    @Expect(env["CANGHUI_MAX_RELEASE_SYMBOLS"], "2000")
    @Expect(env["PATH"], "/usr/bin:/bin:/usr/sbin:/sbin")
    for (name in ["BASH_ENV", "ENV", "DYLD_INSERT_LIBRARIES", "LD_PRELOAD", "SHELLOPTS"]) {
        @Expect(!env.contains(name))
    }
    for (platform in ["linux", "windows", "harmony"]) {
        @Expect(hardeningRejects({=> validateMacPackagingHardening(MacPackagingHardening(enabled: true), platform, "macos", "", "") }))
    }
    @Expect(hardeningRejects({=> validateMacPackagingHardening(MacPackagingHardening(enabled: true), "macos", "linux", "", "") }))
}

@Test
func packagingReceiptDoesNotInferAuditFromAssemblyOrPublisherSigning(): Unit {
    let manifest = parseApplicationManifest("[application]\nname=\"app\"\nidentifier=\"dev.example.app\"\nversion=\"1\"\n")
    let plain = ApplicationPackagingArtifactReceipt("macos", "macos-unsigned-app-bundle", manifest,
        [], [], true, false, "not-launched", ["publisher-signing-and-notarization-not-run"])
    @Expect(renderApplicationPackagingReceiptJson(plain).contains("\"candidateAuditPassed\":false"))
    let passed = ApplicationPackagingArtifactReceipt("macos", "macos-unsigned-app-bundle", manifest,
        [], [], true, false, "not-launched", plain.limitations, candidateAuditPassed: true)
    let json = renderApplicationPackagingReceiptJson(passed)
    @Expect(json.contains("\"candidateAuditPassed\":true"))
    @Expect(json.contains("\"signed\":false"))
    @Expect(json.contains("publisher-signing-and-notarization-not-run"))
    @Expect(helpText().contains("--export-symbol <_name>"))
}
