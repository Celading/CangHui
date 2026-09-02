package cuic

import std.fs.{Directory, File, canonicalize, exists, removeIfExists}

@Test
func harmonyProjectionIsDeterministicAndRejectsGeneratedDrift(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src"), recursive: true)
    Directory.create(joinPath(project, "assets/data"), recursive: true)
    File.writeTo(joinPath(project, "src/main.cj"),
        "package demo\npublic func message(): String { \"desktop\" }\n".toArray())
    File.writeTo(joinPath(project, "assets/data/value.bin"),
        [UInt8(0), UInt8(1), UInt8(255)])
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\nresources = [\"assets/data\"]\n" +
        "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.demo\"\n" +
        "output = \".canghui/harmony\"\n" +
        "transforms = [\"replace:package demo=>package demo_harmony\"]\n"
    )
    validateApplicationManifest(manifest, project)
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    let first = prepareHarmonyProjection(project, framework, manifest)
    let second = prepareHarmonyProjection(project, framework, manifest)
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"canghui.harmony-projection/v1\""))
    @Expect(first.contains("\"outputDigest\":"))
    @Expect(String.fromUtf8(File.readFrom(
        joinPath(project, ".canghui/harmony/cangjie/src/main.cj")))
        .contains("package demo_harmony"))
    @Expect(exists(joinPath(project, ".canghui/harmony/host/CangHuiHost.ets")))
    @Expect(exists(joinPath(project,
        ".canghui/harmony/entry/src/main/resources/rawfile/assets/data/value.bin")))

    let generatedHost = joinPath(project, ".canghui/harmony/host/CangHuiHost.ets")
    let originalHost = File.readFrom(generatedHost)
    File.writeTo(generatedHost, "drift".toArray())
    var driftRejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        driftRejected = true
    }
    @Expect(driftRejected)
    File.writeTo(generatedHost, originalHost)

    File.writeTo(joinPath(project, "src/main.cj"),
        "package demo\npublic func message(): String { \"changed\" }\n".toArray())
    var sourceDriftRejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        sourceDriftRejected = true
    }
    @Expect(sourceDriftRejected)
}

@Test
func harmonyProjectionSupportsMultipleCanonicalSourceRoots(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-multi-root-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src/core"), recursive: true)
    Directory.create(joinPath(project, "feature"), recursive: true)
    Directory.create(joinPath(project, "desktop"), recursive: true)
    File.writeTo(joinPath(project, "src/core/model.cj"), "package model\n".toArray())
    File.writeTo(joinPath(project, "feature/page.cj"), "package page\n".toArray())
    File.writeTo(joinPath(project, "desktop/window.cj"), "package desktop\n".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Multi\"\nidentifier = \"dev.example.multi\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\", \"feature\", \"desktop\"]\n" +
        "exclude = [\"desktop\"]\ntarget-package = \"dev.example.multi\"\n" +
        "output = \"generated/harmony\"\n"
    )
    validateApplicationManifest(manifest, project)
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    let receipt = prepareHarmonyProjection(project, framework, manifest)
    @Expect(receipt.contains("src/core/model.cj"))
    @Expect(receipt.contains("feature/page.cj"))
    @Expect(!receipt.contains("desktop/window.cj"))
    @Expect(prepareHarmonyProjection(project, framework, manifest), receipt)
}

@Test
func harmonyProjectionRefusesForeignOutputDirectory(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-projection-foreign-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(joinPath(project, "src"), recursive: true)
    Directory.create(joinPath(project, ".canghui/harmony"), recursive: true)
    File.writeTo(joinPath(project, "src/main.cj"), "package demo\n".toArray())
    File.writeTo(joinPath(project, ".canghui/harmony/foreign.txt"), "keep".toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.demo\"\n" +
        "output = \".canghui/harmony\"\n"
    )
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    var rejected = false
    try {
        let _ = prepareHarmonyProjection(project, framework, manifest)
    } catch (_: CuicError) {
        rejected = true
    }
    @Expect(rejected)
    @Expect(String.fromUtf8(File.readFrom(
        joinPath(project, ".canghui/harmony/foreign.txt"))), "keep")
}

@Test
func harmonyProjectionCopiesCompatibleProviderPackWithoutFrameworkFork(): Unit {
    let project = joinPath(currentDirectory(), "target/harmony-provider-consumer-fixture")
    let provider = joinPath(currentDirectory(), "target/harmony-provider-pack-fixture")
    _ = removeIfExists(project, recursive: true)
    _ = removeIfExists(provider, recursive: true)
    Directory.create(joinPath(project, "src"), recursive: true)
    Directory.create(joinPath(provider, "lib"), recursive: true)
    File.writeTo(joinPath(project, "src/main.cj"), "package consumer\n".toArray())
    File.writeTo(joinPath(provider, "lib/libSDL3.so"), [UInt8(1), UInt8(2)])
    File.writeTo(joinPath(provider, "lib/libcanghui_ohos_surface.so"), [UInt8(3), UInt8(4)])
    File.writeTo(joinPath(provider, "canghui-harmony-provider.env"),
        ("schema=canghui.harmony-provider/v1\n" +
        "providerVersion=20260902.1\n" +
        "frameworkVersion=0.17.0\n" +
        "frameworkCommit=0123456789abcdef0123456789abcdef01234567\n" +
        "frameworkAbi=canghui.harmony-native-surface/v1\n" +
        "inputAbi=canghui.harmony-pointer/v2\n" +
        "projectionProtocol=canghui.harmony-projection/v1\n" +
        "targetAbi=arm64-v8a\n" +
        "artifacts=lib/libSDL3.so,lib/libcanghui_ohos_surface.so\n").toArray())
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Consumer\"\nidentifier = \"dev.example.consumer\"\nversion = \"1.0.0\"\n" +
        "[harmony]\nsource-roots = [\"src\"]\ntarget-package = \"dev.example.consumer\"\n" +
        "output = \"generated/harmony\"\n")
    validateApplicationManifest(manifest, project)
    let cwd = currentDirectory()
    let framework = if (frameworkRootCandidate(cwd)) { cwd }
        else { canonicalize(joinPath(cwd, "../..")).toString() }
    let receipt = prepareHarmonyProjection(project, framework, manifest, providerRoot: provider)
    @Expect(receipt.contains("\"version\":\"20260902.1\""))
    @Expect(receipt.contains("\"targetAbi\":\"arm64-v8a\""))
    @Expect(exists(joinPath(project,
        "generated/harmony/native/provider/pack/lib/libSDL3.so")))
    @Expect(exists(joinPath(project,
        "generated/harmony/native/provider/pack/lib/libcanghui_ohos_surface.so")))
    @Expect(exists(joinPath(project,
        "generated/harmony/native/provider/framework-contract.env")))
}

@Test
func harmonyProjectionRejectsProviderBuiltForAnotherFrameworkVersion(): Unit {
    let provider = joinPath(currentDirectory(), "target/harmony-provider-mismatch-fixture")
    _ = removeIfExists(provider, recursive: true)
    Directory.create(joinPath(provider, "lib"), recursive: true)
    File.writeTo(joinPath(provider, "lib/libSDL3.so"), [UInt8(1)])
    File.writeTo(joinPath(provider, "canghui-harmony-provider.env"),
        ("schema=canghui.harmony-provider/v1\n" +
        "providerVersion=old\nframeworkVersion=0.16.0\n" +
        "frameworkCommit=0123456789abcdef0123456789abcdef01234567\n" +
        "frameworkAbi=canghui.harmony-native-surface/v1\n" +
        "inputAbi=canghui.harmony-pointer/v2\n" +
        "projectionProtocol=canghui.harmony-projection/v1\n" +
        "targetAbi=arm64-v8a\nartifacts=lib/libSDL3.so\n").toArray())
    var rejected = false
    try {
        let _ = loadHarmonyProviderPack(provider)
    } catch (error: CuicError) {
        rejected = error.message.contains("framework mismatch")
    }
    @Expect(rejected)
}
