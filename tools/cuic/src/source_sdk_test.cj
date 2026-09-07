package cuic

import std.fs.{Directory, File, removeIfExists}
import std.process.executeWithOutput

private func sdkRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: CuicError) { true }
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
func sourceSdkBuildUsesBoundedScanJobsWithoutReplacingCallerOptions(): Unit {
    @Expect(sourceSdkBuildArguments(["build"]), ["build", "-j", "1"])
    @Expect(sourceSdkBuildArguments(["test", "-g"]), ["test", "-g", "-j", "1"])
    @Expect(sourceSdkBuildArguments(["run"]), ["run", "--build-args", "-j 1"])
    @Expect(sourceSdkBuildArguments(["build", "-j", "2"]), ["build", "-j", "2"])
    @Expect(sourceSdkBuildArguments(["run", "--build-args", "-g"]), ["run", "--build-args", "-g"])
}

@Test
func sourceSdkChecksumsRejectCorruptionAndUnlistedSource(): Unit {
    if (hostPlatform() != "macos") { return }
    let root = joinPath(currentDirectory(), "target/source-sdk-checksum-fixture")
    _ = removeIfExists(root, recursive: true)
    for (directory in ["framework/src", "bin", "native"]) {
        Directory.create(joinPath(root, directory), recursive: true)
    }
    let names = ["libSDL3.dylib", "libSDL3_ttf.dylib"]
    let files = ["framework/canghui-sdk.env", "framework/cjpm.toml", "framework/src/chui.cj",
        "bin/cuic", "bin/cuic-debug", "native/libSDL3.dylib", "native/libSDL3_ttf.dylib"]
    var ledger = ""
    for (file in files) {
        File.writeTo(joinPath(root, file), "original".toArray())
        let (code, bytes, _) = executeWithOutput("/usr/bin/shasum", ["-a", "256", joinPath(root, file)])
        @Expect(code, 0)
        ledger += substringTo(String.fromUtf8(bytes), 64) + "  " + file + "\n"
    }
    File.writeTo(joinPath(root, "SHA256SUMS"), ledger.toArray())
    verifySourceSdkFiles(root, names)
    File.writeTo(joinPath(root, "framework/src/chui.cj"), "changed".toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names) }))
    File.writeTo(joinPath(root, "framework/src/chui.cj"), "original".toArray())
    File.writeTo(joinPath(root, "framework/src/unlisted.cj"), "unlisted".toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names) }))
    _ = removeIfExists(joinPath(root, "framework/src/unlisted.cj"))
    File.writeTo(joinPath(root, "SHA256SUMS"), (ledger + ledger).toArray())
    @Expect(sdkRejects({=> verifySourceSdkFiles(root, names) }))
}
