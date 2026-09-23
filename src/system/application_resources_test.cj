package chui.system

import std.fs.{Directory, File, Path, SymbolicLink, canonicalize, exists, removeIfExists}
import sdl.Fonts

@Test
func applicationResourcesResolveDeclaredSourceAssetsWithProvenance(): Unit {
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE", role: ApplicationResourceRole.License),
        ApplicationResourceDeclaration("ui-font", "assets/fonts/HarmonyOS_Sans_SC.ttf",
            role: ApplicationResourceRole.TextFont, family: "CangHui Test Sans"),
        ApplicationResourceDeclaration("symbols", "packages/symbol-ant/symbols.catalog",
            role: ApplicationResourceRole.SymbolCatalog)
    ], [ApplicationResourceRoot.source(".")])

    let receipt = resources.resolve("license")
    @Expect(receipt.provenance(), "source:license")
    @Expect(receipt.path, canonicalize("LICENSE").toString())
    @Expect(resources.replay().size, 3)
    let fonts = resources.registerFonts()
    @Expect(fonts.size, 1)
    @Expect(Fonts.isRegistered("CangHui Test Sans"))
    Fonts.unregister("CangHui Test Sans")
}

@Test
func applicationResourcesRejectDuplicateTraversalUndeclaredAndStaleMobileInputs(): Unit {
    var duplicateRejected = false
    try {
        let _ = ApplicationResources([
            ApplicationResourceDeclaration("same", "LICENSE"),
            ApplicationResourceDeclaration("same", "README.md")
        ], [ApplicationResourceRoot.source(".")])
    } catch (_: IllegalArgumentException) { duplicateRejected = true }
    @Expect(duplicateRejected)

    var traversalRejected = false
    try {
        let _ = ApplicationResourceDeclaration("escape", "../LICENSE")
    } catch (_: IllegalArgumentException) { traversalRejected = true }
    @Expect(traversalRejected)

    let source = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE")
    ], [ApplicationResourceRoot.source(".")])
    var undeclaredRejected = false
    try { let _ = source.resolve("secret") } catch (_: IllegalArgumentException) {
        undeclaredRejected = true
    }
    @Expect(undeclaredRejected)

    let mobile = ApplicationResources([
        ApplicationResourceDeclaration("license", "LICENSE")
    ], [ApplicationResourceRoot.mobileRawfile(".", 3)], activeMobileGeneration: Some(4))
    var staleRejected = false
    try { let _ = mobile.resolve("license") } catch (_: IllegalStateException) {
        staleRejected = true
    }
    @Expect(staleRejected)
}

@Test
func applicationResourceRootHelpersMatchCuicPackageLayouts(): Unit {
    @Expect(ApplicationResourceRoot.macBundle("Demo.app").path,
        Path("Demo.app/Contents/Resources/assets").normalize().toString())
    @Expect(ApplicationResourceRoot.windowsPackage("dist/windows").path,
        Path("dist/windows/assets").normalize().toString())
    @Expect(ApplicationResourceRoot.linuxPackage("dist/linux", "dev.cureatex.demo").path,
        Path("dist/linux/share/dev.cureatex.demo/resources").normalize().toString())
}

@Test
func applicationResourcesReplaySourceDesktopPackagesAndMobileRawfile(): Unit {
    let fixture = "target/application-resources-layout-fixture"
    _ = removeIfExists(fixture, recursive: true)
    let paths = [
        fixture + "/source/assets/data",
        fixture + "/Demo.app/Contents/Resources/assets/assets/data",
        fixture + "/windows/assets/assets/data",
        fixture + "/linux/share/dev.example.demo/resources/assets/data",
        fixture + "/mobile/assets/data"
    ]
    for (path in paths) {
        Directory.create(path, recursive: true)
        File.writeTo(path + "/config.bin", [UInt8(1), UInt8(2), UInt8(3)])
    }
    let declaration = ApplicationResourceDeclaration(
        "config", "assets/data/config.bin", role: ApplicationResourceRole.Data)
    let cases = [
        ApplicationResources([declaration], [
            ApplicationResourceRoot.source(fixture + "/source")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.macBundle(fixture + "/Demo.app")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.windowsPackage(fixture + "/windows")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.linuxPackage(fixture + "/linux", "dev.example.demo")]),
        ApplicationResources([declaration], [
            ApplicationResourceRoot.mobileRawfile(fixture + "/mobile", 7)],
            activeMobileGeneration: Some(7))
    ]
    let expected = [
        "source:config", "macos-bundle:config", "windows-package:config",
        "linux-package:config", "mobile-rawfile:config"
    ]
    var i: Int64 = 0
    while (i < cases.size) {
        @Expect(cases[i].replay()[0].provenance(), expected[i])
        i += 1
    }
}

@Test
func applicationResourcesRejectSymbolicLinkInputs(): Unit {
    let fixture = "target/application-resources-symlink-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/root", recursive: true)
    Directory.create(fixture + "/outside", recursive: true)
    File.writeTo(fixture + "/outside/value.txt", "secret".toArray())
    SymbolicLink.create(fixture + "/root/value.txt",
        to: canonicalize(fixture + "/outside/value.txt").toString())
    @Expect(exists(fixture + "/root/value.txt"))
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("value", "value.txt")
    ], [ApplicationResourceRoot.source(fixture + "/root")])
    var rejected = false
    try { let _ = resources.resolve("value") } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func applicationResourcesRejectAmbiguousRelativeDeclarations(): Unit {
    for (path in [".", "..", "assets/..", "assets/./a", "assets//a", "assets/",
        "C:secret", "C:/secret", "assets/a:stream", "assets/\nfile", "assets/\rfile"]) {
        var rejected = false
        try { let _ = ApplicationResourceDeclaration("invalid", path) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected, true)
    }
}

@Test
func applicationResourcesRejectDirectoryReceipts(): Unit {
    let fixture = "target/application-resources-directory-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/root/subdir", recursive: true)
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("directory", "subdir")
    ], [ApplicationResourceRoot.source(fixture + "/root")])
    var rejected = false
    try { let _ = resources.resolve("directory") }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}

@Test
func applicationResourcesRejectSymbolicLinkRoot(): Unit {
    let fixture = "target/application-resources-root-link-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/real", recursive: true)
    File.writeTo(fixture + "/real/value.txt", "value".toArray())
    SymbolicLink.create(fixture + "/linked", to: canonicalize(fixture + "/real").toString())
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("value", "value.txt")
    ], [ApplicationResourceRoot.source(fixture + "/linked")])
    var rejected = false
    try { let _ = resources.resolve("value") }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}

@Test
func applicationResourceCanonicalWindowsContainment(): Unit {
    // Canonical string comparison tests, not Windows filesystem certification.
    for ((root, candidate) in [
        ("C:\\app\\assets", "C:\\app\\assets\\font.ttf"),
        ("C:\\app\\assets", "C:/app/assets/fonts/body.ttf"),
        ("C:/app/assets", "C:\\app\\assets\\body.ttf"),
        ("C:\\", "C:\\font.ttf"),
        ("C:/", "C:/font.ttf"),
        ("\\\\server\\share", "\\\\server\\share\\font.ttf"),
        ("\\\\server\\share\\", "//server/share/fonts/body.ttf"),
        ("\\\\?\\C:\\app", "\\\\?\\C:\\app\\font.ttf"),
        ("C:\\应用 甲\\字体", "C:\\应用 甲\\字体\\正文.ttf")
    ]) {
        @Expect(resourceCanonicalContained(root, candidate, true))
    }
    for ((root, candidate) in [
        ("C:\\app", "C:\\application\\font.ttf"),
        ("C:\\app", "D:\\app\\font.ttf"),
        ("C:\\App", "C:\\app\\font.ttf"),
        ("\\\\server\\share", "\\\\server\\share2\\font.ttf"),
        ("\\\\server\\share", "\\\\other\\share\\font.ttf"),
        ("C:\\app", "C:\\app"),
        ("C:\\app", "C:\\app\\"),
        ("C:\\应用甲", "C:\\应用甲乙\\正文.ttf"),
        ("", "C:\\app\\font.ttf")
    ]) {
        @Expect(!resourceCanonicalContained(root, candidate, true))
    }
}

@Test
func applicationResourceCanonicalPosixContainment(): Unit {
    @Expect(resourceCanonicalContained("/", "/font.ttf", false))
    @Expect(resourceCanonicalContained("/app/", "/app/font.ttf", false))
    @Expect(!resourceCanonicalContained("/app", "/application/font.ttf", false))
    @Expect(!resourceCanonicalContained("/app", "/App/font.ttf", false))
    @Expect(!resourceCanonicalContained("/", "/", false))
    // Backslashes are ordinary filename characters on POSIX, not separators.
    @Expect(!resourceCanonicalContained("/app", "/app\\font.ttf", false))
    @Expect(!resourceCanonicalContained("/app\\data", "/app/data/font.ttf", false))
    @Expect(resourceCanonicalContained("/app\\data", "/app\\data/font.ttf", false))
}

@Test
func applicationResourcesPreserveUnicodeAndFallbackProvenance(): Unit {
    let fixture = "target/application-resources-unicode-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/empty", recursive: true)
    Directory.create(fixture + "/应用 甲/字体", recursive: true)
    File.writeTo(fixture + "/应用 甲/字体/正文.bin", [UInt8(42)])
    let resources = ApplicationResources([
        ApplicationResourceDeclaration("正文", "字体/正文.bin", role: ApplicationResourceRole.Data)
    ], [ApplicationResourceRoot.source(fixture + "/empty"),
        ApplicationResourceRoot.mobileRawfile(fixture + "/应用 甲", 9)],
        activeMobileGeneration: Some(9))
    let receipt = resources.resolve("正文")
    @Expect(receipt.path, canonicalize(fixture + "/应用 甲/字体/正文.bin").toString())
    @Expect(receipt.provenance(), "mobile-rawfile:正文")
    @Expect(receipt.generation, Some(9))
    @Expect(File.readFrom(receipt.path), [UInt8(42)])
}

@Test
func applicationResourcesRejectMissingAssets(): Unit {
    let fixture = "target/application-resources-missing-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture, recursive: true)
    let resources = ApplicationResources([ApplicationResourceDeclaration("missing", "absent.bin")],
        [ApplicationResourceRoot.source(fixture)])
    var rejected = false
    try { let _ = resources.resolve("missing") }
    catch (error: IllegalStateException) {
        rejected = error.message == "declared application resource is missing: missing"
    }
    @Expect(rejected)
}

@Test
func applicationResourcesRejectLinkedParentsWithoutFallback(): Unit {
    let fixture = "target/application-resources-parent-link-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture + "/root/real", recursive: true)
    Directory.create(fixture + "/root-sibling", recursive: true)
    Directory.create(fixture + "/fallback/inside", recursive: true)
    Directory.create(fixture + "/fallback/outside", recursive: true)
    Directory.create(fixture + "/fallback/dangling", recursive: true)
    File.writeTo(fixture + "/root/real/value.bin", [UInt8(1)])
    File.writeTo(fixture + "/root-sibling/value.bin", [UInt8(2)])
    File.writeTo(fixture + "/fallback/inside/value.bin", [UInt8(3)])
    File.writeTo(fixture + "/fallback/outside/value.bin", [UInt8(4)])
    File.writeTo(fixture + "/fallback/dangling/value.bin", [UInt8(5)])
    SymbolicLink.create(fixture + "/root/inside", to: canonicalize(fixture + "/root/real").toString())
    SymbolicLink.create(fixture + "/root/outside", to: canonicalize(fixture + "/root-sibling").toString())
    SymbolicLink.create(fixture + "/root/dangling", to: canonicalize(fixture + "/root").toString() + "/absent")
    for (path in ["inside/value.bin", "outside/value.bin", "dangling/value.bin"]) {
        let resources = ApplicationResources([ApplicationResourceDeclaration("value", path)],
            [ApplicationResourceRoot.source(fixture + "/root"),
                ApplicationResourceRoot.source(fixture + "/fallback")])
        var rejected = false
        try { let _ = resources.resolve("value") }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func applicationResourcesRejectFileRootAndFileParent(): Unit {
    let fixture = "target/application-resources-file-parent-fixture"
    _ = removeIfExists(fixture, recursive: true)
    Directory.create(fixture, recursive: true)
    File.writeTo(fixture + "/file.bin", [UInt8(1)])
    let resources = [
        ApplicationResources([ApplicationResourceDeclaration("value", "value.bin")],
            [ApplicationResourceRoot.source(fixture + "/file.bin")]),
        ApplicationResources([ApplicationResourceDeclaration("value", "file.bin/child.bin")],
            [ApplicationResourceRoot.source(fixture)])
    ]
    for (resolver in resources) {
        var rejected = false
        try { let _ = resolver.resolve("value") }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}
