package cuic

import std.collection.ArrayList
import std.fs.{Directory, File, exists, removeIfExists}
import std.process.executeWithOutput

private func sdkRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: CuicError) { true }
}

@Test
func sourceSdkRejectsDirectoryPayloadBeforeHashingOrCoverageChecks(): Unit {
    let root = joinPath(currentDirectory(), "target/source-sdk-payload-type-fixture")
    Directory.create(joinPath(root, "payload"), recursive: true)
    File.writeTo(joinPath(root, "SHA256SUMS"),
        ("0000000000000000000000000000000000000000000000000000000000000000  payload\n").toArray())
    var message = ""
    try { verifySourceSdkFiles(root, ["libSDL3.dylib", "libSDL3_ttf.dylib"]) }
    catch (error: CuicError) { message = error.message }
    @Expect(message.contains("must be a regular file: payload"))
    _ = removeIfExists(root, recursive: true)
}

@Test
func sourceSdkCompilerGateRejectsVersionPrefixAndWrongTarget(): Unit {
    @Expect(sourceSdkCompilerMatches("Cangjie Compiler: 1.1.3 (cjnative)\nTarget: aarch64-apple-darwin\n"))
    for (output in ["Cangjie Compiler: 1.1.30 (cjnative)\nTarget: aarch64-apple-darwin",
        "Cangjie Compiler: 1.1.3-beta (cjnative)\nTarget: aarch64-apple-darwin",
        "Cangjie Compiler: 1.1.3 (cjnative)\nTarget: x86_64-apple-darwin",
        "warning Cangjie Compiler: 1.1.3 (cjnative)\nTarget: aarch64-apple-darwin", ""]) {
        @Expect(!sourceSdkCompilerMatches(output))
    }
}

@Test
func sourceSdkVersionChecksRejectNonNumericMetadata(): Unit {
    for (bad in ["+15", "15..1", "15.0;run", "15.0.0.0", "999999999999999999999", "", "15\n0"]) {
        @Expect(sdkRejects({=> let _ = sourceSdkOSAtLeast(bad, "15.0") }))
    }
    @Expect(sourceSdkVersionRelation("0.9.0", "0.17.0"), "higher")
    @Expect(sourceSdkVersionRelation("1.0.0", "0.17.0"), "lower")
    @Expect(sourceSdkVersionRelation("0.17.0", "0.17.0"), "equal")
    @Expect(sdkRejects({=> let _ = sourceSdkVersionRelation("1.0", "1.0.0") }))
}

@Test
func sourceSdkPackageIdentityRejectsWrongSectionAndDuplicates(): Unit {
    let good = "[package]\nname = \"chui\"\nversion = \"0.17.0\"\n[dependencies]\nversion = \"other\"\n"
    @Expect(sourceSdkPackageIdentityMatches(good, "chui", "0.17.0"))
    @Expect(!sourceSdkPackageIdentityMatches(good, "cui", "0.17.0"))
    @Expect(!sourceSdkPackageIdentityMatches(good, "chui", "0.16.0"))
    @Expect(!sourceSdkPackageIdentityMatches("[dependencies]\nname = \"chui\"\nversion = \"0.17.0\"", "chui", "0.17.0"))
    @Expect(!sourceSdkPackageIdentityMatches(good + "[package]\nname = \"chui\"\nversion = \"0.17.0\"", "chui", "0.17.0"))
    @Expect(!sourceSdkPackageIdentityMatches("[package]\nname = \"chui\"\nname = \"chui\"\nversion = \"0.17.0\"", "chui", "0.17.0"))
}

@Test
func sourceSdkCliRejectsInvalidRequestsBeforeMutation(): Unit {
    @Expect(sourceSdkCommand(["verify", "--json"], 0), 1)
    @Expect(sourceSdkCommand(["compare", "one", "--json"], 0), 1)
    @Expect(sourceSdkCommand(["install", "one", "--json"], 0), 1)
    @Expect(helpText().contains("cuic sdk compare"))
}

@Test
func sourceSdkMetadataReaderRejectsDirectoryAndOversize(): Unit {
    let root = joinPath(currentDirectory(), "target/source-sdk-reader-fixture")
    Directory.create(root, recursive: true)
    let path = joinPath(root, "metadata")
    File.writeTo(path, "12345".toArray())
    @Expect(sdkRejects({=> let _ = readSourceSdkText(path, 4) }))
    @Expect(sdkRejects({=> let _ = readSourceSdkText(root, 4096) }))
    @Expect(readSourceSdkText(path, 5), "12345")
    _ = removeIfExists(root, recursive: true)
}

@Test
func sourceSdkComparisonNeverInfersCommitOrderOrRuntimeCompatibility(): Unit {
    let commit = "0123456789012345678901234567890123456789"
    let manifest = "schema=canghui.source-sdk/v1\nsourceCommit=" + commit +
        "\ncuicVersion=0.6.0\nframeworkVersion=0.17.0\nkitVersion=0.1.0\ncompilerVersion=1.1.3\n" +
        "target=macos-arm64\nminimumOS=15.0\nnativeFiles=libSDL3.dylib,libSDL3_ttf.dylib\n"
    let current = SourceSdkInspection(sourceSdkFields(manifest, commit, "0.6.0", "macos-arm64"), "ledger-a")
    let candidateFields = sourceSdkFields(manifest, "unpaired", "0.6.0", "macos-arm64", paired: false)
    candidateFields["sourceCommit"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    candidateFields["frameworkVersion"] = "0.18.0"
    let comparison = sourceSdkComparisonJson(current, SourceSdkInspection(candidateFields, "ledger-b"))
    @Expect(comparison.contains("different-commit-order-unknown"))
    @Expect(comparison.contains("\"frameworkVersionRelation\":\"higher\""))
    @Expect(comparison.contains("requires-consumer-regression"))
    @Expect(comparison.contains("\"automaticUpdate\":false"))
    @Expect(comparison.contains("\"samePayloadLedger\":false"))
    @Expect(sourceSdkInspectionJson(current).contains("\"publisherAuthenticated\":false"))
}

@Test
func defaultTemplateHasTheSameObservableWelcomeFlowAsSdk(): Unit {
    let source = generatedMain("welcome_test")
    @Expect(source.contains("@CuiProbe[\"welcome.main\"]"))
    @Expect(source.contains(".key(\"welcome.ready\")"))
    @Expect(source.contains("welcomeContent(message)"))
    @Expect(!source.contains("scale: 1.5"))
    // The default published pin predates WindowScaleSettings.
    @Expect(!source.contains("WindowScaleSettings"))
}

@Test
func initLocalDependencyResolvesFromCallerAndProtectsSdkRoot(): Unit {
    let relative = "target/source-sdk-init-fixture"
    let root = joinPath(currentDirectory(), relative)
    _ = removeIfExists(root, recursive: true)
    let framework = joinPath(root, "framework")
    for (directory in ["sdl", "src", "assets/fonts"]) {
        Directory.create(joinPath(framework, directory), recursive: true)
    }
    for (file in ["cjpm.toml", "src/chui.cj", "assets/fonts/HarmonyOS_Sans_SC.ttf",
        "assets/fonts/HARMONYOS_SANS_LICENSE.txt", "assets/fonts/HARMONYOS_SANS_SOURCE.txt"]) {
        File.writeTo(joinPath(framework, file), "fixture".toArray())
    }
    let app = joinPath(root, "app")
    @Expect(initProject([app, "--canghui-path", relative + "/framework"], 0), 0)
    @Expect(String.fromUtf8(File.readFrom(joinPath(app, "cjpm.toml"))).contains(
        "path = \"" + canonicalPackagingPath(framework, "fixture") + "\""))
    File.writeTo(joinPath(framework, SOURCE_SDK_MANIFEST), "fixture".toArray())
    protectSourceSdkDestination(framework, "ck103-nonexistent-relative-app")
    let forbidden = joinPath(root, "new-app")
    @Expect(sdkRejects({=> let _ = initProject([forbidden, "--canghui-path", framework], 0) }))
    @Expect(!exists(forbidden))
    _ = removeIfExists(root, recursive: true)
}

@Test
func sourceSdkRequiresExactPairedIdentityAndTarget(): Unit {
    let commit = "0123456789012345678901234567890123456789"
    let manifest = "schema=canghui.source-sdk/v1\nsourceCommit=" + commit +
        "\ncuicVersion=0.6.0\nframeworkVersion=0.17.0\nkitVersion=0.1.0\ncompilerVersion=1.1.3\n" +
        "target=macos-arm64\nminimumOS=15.0\nnativeFiles=libSDL3.dylib,libSDL3_ttf.dylib\n"
    let fields = sourceSdkFields(manifest, commit, "0.6.0", "macos-arm64")
    @Expect(fields["frameworkVersion"], "0.17.0")
    @Expect(sdkRejects({=> let _ = sourceSdkFields(manifest, "unembedded", "0.6.0", "macos-arm64") }))
    @Expect(sdkRejects({=> let _ = sourceSdkFields(manifest, commit, "0.4.0", "macos-arm64") }))
    @Expect(sdkRejects({=> let _ = sourceSdkFields(manifest, commit, "0.6.0", "windows-x86_64") }))
    @Expect(sdkRejects({=> let _ = sourceSdkFields(manifest + "target=macos-arm64\n", commit, "0.6.0", "macos-arm64") }))
}

@Test
func sourceSdkNativeClosureNamesCannotEscapeOrOmitSdl(): Unit {
    @Expect(sourceSdkNativeNames("libSDL3.dylib,libSDL3_ttf.dylib,libharfbuzz.0.dylib").size, 3)
    for (bad in ["../libSDL3.dylib", "libSDL3.dylib", "libSDL3.dylib,libSDL3_ttf.dylib,libSDL3.dylib",
        "libSDL3.dylib,libSDL3_ttf.dylib,bad name.dylib"]) {
        @Expect(sdkRejects({=> let _ = sourceSdkNativeNames(bad) }))
    }
}

@Test
func sourceSdkComparesRealMinimumSystemVersion(): Unit {
    @Expect(sourceSdkOSAtLeast("15.0", "15.0.0"))
    @Expect(sourceSdkOSAtLeast("26.0", "15.0"))
    @Expect(!sourceSdkOSAtLeast("14.7.5", "15.0"))
    @Expect(!sourceSdkOSAtLeast("15.0.0", "15.0.1"))
}

@Test
func sourceSdkMacAppDependencyPolicyRejectsHostLeaksAndTraversal(): Unit {
    let names = ["libSDL3.dylib", "libSDL3_ttf.dylib"]
    @Expect(sdkMacDependencyAllowed("/usr/lib/libSystem.B.dylib", names, false))
    @Expect(sdkMacDependencyAllowed("@rpath/libSDL3.dylib", names, false))
    @Expect(sdkMacDependencyAllowed("@loader_path/libSDL3.dylib", names, true))
    @Expect(!sdkMacDependencyAllowed("@loader_path/libSDL3.dylib", names, false))
    @Expect(!sdkMacDependencyAllowed("@rpath/../libSDL3.dylib", names, false))
    @Expect(!sdkMacDependencyAllowed("/usr/lib/../../opt/foreign.dylib", names, false))
    @Expect(!sdkMacDependencyAllowed("/opt/homebrew/lib/libSDL3.dylib", names, false))
    @Expect(!sdkMacDependencyAllowed("@rpath/libcangjie-runtime.dylib", names, false))
}

@Test
func sourceSdkTemplateResolvesPackagedFontBeforeProbeOrWindowLaunch(): Unit {
    let source = generatedSdkMain("sdk_demo")
    @Expect(!source.contains("import sdl."))
    @Expect(source.contains("ApplicationPaths.basePath()"))
    @Expect(source.contains("base + \"" + SOURCE_SDK_BUNDLED_FONT + "\""))
    @Expect(indexOfText(source, "Fonts.registerBundledFallback") < indexOfText(source, "if (runKModeStdioIfRequested()"))
}

@Test
func sourceSdkBuildUsesBoundedScanJobsWithoutReplacingCallerOptions(): Unit {
    @Expect(sourceSdkBuildArguments(["build"]), ["build", "-j", "1"])
    @Expect(sourceSdkBuildArguments(["test", "-g"]), ["test", "-g", "-j", "1"])
    @Expect(sourceSdkBuildArguments(["run"]), ["run", "--build-args", "-j 1"])
    @Expect(sourceSdkBuildArguments(["build", "-j", "2"]), ["build", "-j", "2"])
    @Expect(sourceSdkBuildArguments(["run", "--build-args", "-g"]), ["run", "--build-args", "-g"])
}

@Test
func sourceSdkChecksumsRejectCorruptionAndUnlistedSource(): Unit {
    if (hostPlatform() != "macos" && hostPlatform() != "linux") { return }
    let linux = hostPlatform() == "linux"
    let target = sourceSdkHostTarget()
    let root = joinPath(currentDirectory(), "target/source-sdk-checksum-fixture")
    _ = removeIfExists(root, recursive: true)
    for (directory in ["framework/src", "bin", "native"]) {
        Directory.create(joinPath(root, directory), recursive: true)
    }
    let names = if (linux) { ["libSDL3.so", "libSDL3.so.0", "libSDL3_ttf.so", "libSDL3_ttf.so.0"] }
        else { ["libSDL3.dylib", "libSDL3_ttf.dylib"] }
    let files = ArrayList<String>()
    for (path in ["framework/canghui-sdk.env", "framework/cjpm.toml", "framework/src/chui.cj", "bin/cuic", "bin/cuic-debug"]) {
        files.add(path)
    }
    for (name in names) { files.add("native/" + name) }
    var ledger = ""
    for (file in files) {
        File.writeTo(joinPath(root, file), "original".toArray())
        let checker = if (linux) { "/usr/bin/sha256sum" } else { "/usr/bin/shasum" }
        let args = if (linux) { [joinPath(root, file)] } else { ["-a", "256", joinPath(root, file)] }
        let (code, bytes, _) = executeWithOutput(checker, args)
        @Expect(code, 0)
        ledger += substringTo(String.fromUtf8(bytes), 64) + "  " + file + "\n"
    }
    File.writeTo(joinPath(root, "SHA256SUMS"), ledger.toArray())
    verifySourceSdkFiles(root, names, target: target)
    File.writeTo(joinPath(root, "framework/src/chui.cj"), "changed".toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names, target: target) }))
    File.writeTo(joinPath(root, "framework/src/chui.cj"), "original".toArray())
    File.writeTo(joinPath(root, "framework/src/unlisted.cj"), "unlisted".toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names, target: target) }))
    _ = removeIfExists(joinPath(root, "framework/src/unlisted.cj"))
    File.writeTo(joinPath(root, "SHA256SUMS"), (ledger + ledger).toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names, target: target) }))
}
