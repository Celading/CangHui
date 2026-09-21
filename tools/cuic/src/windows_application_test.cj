package cuic

import std.fs.{Directory, File, SymbolicLink, exists, removeIfExists}

func windowsPeFixture(pe64!: Bool = true, odd!: Bool = false): Array<UInt8> {
    let bytes = Array<UInt8>(if (odd) { 1025 } else { 1024 }, repeat: UInt8(0))
    bytes[0] = 0x4d; bytes[1] = 0x5a
    peWrite32(bytes, 60, 128)
    peWrite32(bytes, 128, 0x4550)
    peWrite32(bytes, 132, if (pe64) { 0x18664 } else { 0x1014c }) // machine, one section
    peWrite32(bytes, 148, if (pe64) { 0x200f0 } else { 0x200e0 }) // optional size, executable
    peWrite32(bytes, 152, if (pe64) { 0x20b } else { 0x10b })
    peWrite32(bytes, 168, 0x1000) // original compiler entry
    peWrite32(bytes, 208, 0x2000) // SizeOfImage
    peWrite32(bytes, 212, 512) // SizeOfHeaders
    peWrite32(bytes, 220, 3) // console
    let directories = if (pe64) { 264 } else { 248 }
    peWrite32(bytes, directories - 4, 16)
    let section = if (pe64) { 392 } else { 376 }
    peWrite32(bytes, section + 8, 512)
    peWrite32(bytes, section + 12, 0x1000)
    peWrite32(bytes, section + 16, 512)
    peWrite32(bytes, section + 20, 512)
    peWrite32(bytes, section + 36, 0x60000020)
    bytes[512] = 0xc3
    if (odd) { bytes[1024] = 0x7b }
    bytes
}

@Test
func windowsGuiPreservesRuntimeEntryAndEverythingExceptSubsystemChecksum(): Unit {
    for (wide in [true, false]) {
        let input = windowsPeFixture(pe64: wide, odd: true)
        let output = windowsApplicationImage(input, false)
        @Expect(peRead16(input, 220), 3)
        @Expect(peRead16(output, 220), 2)
        @Expect(peRead32(output, 168), 0x1000)
        @Expect(peRead32(output, 216) > 0)
        for (index in 0..input.size) {
            if (index < 216 || index > 221) { @Expect(input[index], output[index]) }
        }
        @Expect(windowsApplicationImage(output, false), output)
        let console = windowsApplicationImage(output, true)
        @Expect(peRead16(console, 220), 3)
        @Expect(peRead32(console, 168), 0x1000)
    }
}

@Test
func windowsGuiRejectsSignedManagedDllDriverAndBadHeaders(): Unit {
    // Single-field counterexamples; no broad exception catch may hide bounds errors.
    for ((offset, value) in [(0, 0), (60, 0x7fffffff), (128, 0), (132, 0x18665),
        (132, 0x8664), (148, 0x200200f0), (148, 0x200000f0), (148, 0x20020),
        (152, 0x107), (260, 17), (296, 512), (300, 8), (376, 100),
        (220, 1), (212, 100), (168, 0), (168, 0x1200), (412, 100),
        (408, 2048), (428, 0x40000040)]) {
        let bytes = windowsPeFixture()
        peWrite32(bytes, offset, value)
        var rejected = false
        try { let _ = windowsApplicationImage(bytes, false) }
        catch (e: CuicError) { rejected = !e.message.isEmpty() }
        @Expect(rejected)
    }
    for (size in [0, 64, 128, 151, 200, 391, 431, 1023]) {
        let bytes = windowsPeFixture()[0..size].toArray()
        var rejected = false
        try { let _ = windowsApplicationImage(bytes, false) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func windowsExecutableOptionsFailClosedBeforeProjectLookup(): Unit {
    validateWindowsExecutableRequest("windows", "target/main.exe", false, false, false, "")
    validateWindowsExecutableRequest("windows", "target/main.exe", true, false, false, "")
    for (args in [ ["windows", "--console"], ["linux", "--executable", "main.exe"],
        ["windows", "--executable"], ["windows", "--executable", "../main.exe"],
        ["windows", "--executable", "main.dll"], ["windows", "--executable", "/tmp/main.exe"],
        ["windows", "--executable", "main.exe", "--harden"],
        ["windows", "--executable", "main.exe", "--export-symbol", "_main"],
        ["windows", "--executable", "main.exe", "--runtime-manifest", "runtime.json"],
        ["windows", "--executable", "main.exe", "--executable", "other.exe"],
        ["windows", "--console", "--console"] ]) {
        var rejected = false
        try { let _ = applicationPackagingBuildCommand(args, 0) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func windowsPackagingCopiesGuiWithoutChangingInputAndRejectsOverwrite(): Unit {
    let fixture = joinPath(currentDirectory(), "target/windows-gui-package-test")
    removeIfExists(fixture, recursive: true)
    Directory.create(fixture, recursive: true)
    try {
        File.writeTo(joinPath(fixture, "canghui.toml"),
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n".toArray())
        let bytes = windowsPeFixture()
        File.writeTo(joinPath(fixture, "main.exe"), bytes)
        @Expect(buildProvidedWindowsArtifact(fixture, "main.exe", "dist/gui", false, true), 0)
        let output = File.readFrom(joinPath(fixture, "dist/gui/Demo.exe"))
        @Expect(output, windowsApplicationImage(bytes, false))
        @Expect(File.readFrom(joinPath(fixture, "main.exe")), bytes)
        let receipt = String.fromUtf8(File.readFrom(joinPath(fixture, "dist/gui/canghui-packaging-receipt.json")))
        @Expect(receipt.contains("windows-unsigned-gui-application"))
        @Expect(receipt.contains("\"executableIncluded\":true"))
        @Expect(receipt.contains("native-runtime-dlls-not-included"))
        @Expect(receipt.contains("supplied-pe-validated-not-launched"))
        var overwriteRejected = false
        try { let _ = buildProvidedWindowsArtifact(fixture, "main.exe", "dist/gui", false, true) }
        catch (_: CuicError) { overwriteRejected = true }
        @Expect(overwriteRejected)
        @Expect(File.readFrom(joinPath(fixture, "dist/gui/Demo.exe")), output)
        @Expect(!exists(joinPath(fixture, "dist/gui.cuic-lease")))
        @Expect(buildProvidedWindowsArtifact(fixture, "main.exe", "dist/console", true, true), 0)
        @Expect(peRead16(File.readFrom(joinPath(fixture, "dist/console/Demo.exe")), 220), 3)
        peWrite32(bytes, 296, 512)
        File.writeTo(joinPath(fixture, "signed.exe"), bytes)
        var signedRejected = false
        try { let _ = buildProvidedWindowsArtifact(fixture, "signed.exe", "dist/signed", false, true) }
        catch (_: CuicError) { signedRejected = true }
        @Expect(signedRejected)
        @Expect(!exists(joinPath(fixture, "dist/signed")))
    } finally { removeIfExists(fixture, recursive: true) }
}

@Test
func windowsPackagingRejectsSymlinksAndNonRegularInputs(): Unit {
    let fixture = joinPath(currentDirectory(), "target/windows-gui-path-test")
    removeIfExists(fixture, recursive: true)
    Directory.create(fixture, recursive: true)
    try {
        File.writeTo(joinPath(fixture, "original.exe"), windowsPeFixture())
        SymbolicLink.create(joinPath(fixture, "link.exe"), to: joinPath(fixture, "original.exe"))
        Directory.create(joinPath(fixture, "directory.exe"))
        for (path in ["link.exe", "directory.exe", "../outside.exe"]) {
            var rejected = false
            try { let _ = readWindowsApplicationExecutable(fixture, path) }
            catch (_: CuicError) { rejected = true }
            @Expect(rejected)
        }
    } finally { removeIfExists(fixture, recursive: true) }
}
