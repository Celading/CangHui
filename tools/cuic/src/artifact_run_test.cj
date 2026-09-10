package cuic

import std.collection.HashMap
import std.fs.{Directory, File, SymbolicLink, exists, removeIfExists}

private func artifactRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: Exception) { true }
}

@Test
func artifactRunKeepsApplicationArgumentsLiteralAndRequiresOneBundle(): Unit {
    let parsed = parseArtifactRunOptions(["macos", "Demo Space.app", "--", "--mode", "debug", "a; $(no)", ""], 0)
    @Expect(parsed.platform, "macos")
    @Expect(parsed.artifact, "Demo Space.app")
    @Expect(parsed.appArgs, ["--mode", "debug", "a; $(no)", ""])
    let rejectedInputs: Array<Array<String>> = [[], ["macos"], ["--", "file.app"], ["a.app", "b.app"], ["--build", "a.app"]]
    for (args in rejectedInputs) {
        @Expect(artifactRejects({=> let _ = parseArtifactRunOptions(args, 0) }))
    }
    @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("linux", "missing.app") }))
    @Expect(helpText().contains("cuic package run"))
    @Expect(helpText().contains("--artifact <trusted.app>"))
}

@Test
func artifactCaptureCannotSilentlyBuildOrChooseDeviceRoutes(): Unit {
    let options = parsePrntOptions(["macos", "--artifact", "Demo.app", "--frames", "3", "--window", "settings",
        "--", "--artifact", "literal"], 0)
    @Expect(options.artifact, "Demo.app")
    @Expect(options.frames, UInt64(3))
    @Expect(options.windowId, "settings")
    @Expect(options.appArgs.toArray(), ["--artifact", "literal"])
    @Expect(parsePrntOptions(["macos", "."], 0).artifact, "")
    for (args in [["--artifact"], ["--artifact", ""], ["--artifact", "--output"],
        ["--artifact", "a.app", "--artifact", "b.app"], [".", "--artifact", "a.app"],
        ["--artifact", "a.app", "--mode", "release"], ["--mode", "debug", "--artifact", "a.app"],
        ["--artifact", "a.app", "--device", "device"], ["--app", "id", "--artifact", "a.app"]]) {
        @Expect(artifactRejects({=> let _ = parsePrntOptions(args, 0) }))
    }
}

@Test
func artifactEnvironmentCannotBorrowSdkOrAmbientDebugCaptureState(): Unit {
    let inherited = HashMap<String, String>()
    let blocked = ["DYLD_LIBRARY_PATH", "DYLD_INSERT_LIBRARIES", "LD_LIBRARY_PATH", "LD_PRELOAD",
        "CANGHUI_FRAMEWORK_ROOT", "CANGHUI_CAPTURE_PATH", "CANGHUI_DEBUG_UI_SCRIPT_HEX", "CUI_ROOT",
        "CUIC_TARGET_DIR", "CANGJIE_HOME", "STDX_HOME", "SDL_DYNAMIC_API", "LIBRARY_PATH", "cjProcessorNum"]
    for (key in blocked) { inherited.add(key, "must-not-inherit") }
    inherited.add("PATH", "/usr/bin:/bin")
    inherited.add("HOME", "/caller")
    inherited.add("MY_APP_ARGUMENT", "unchanged")
    let result = packagedApplicationEnvironment(inherited)
    for (key in blocked) {
        @Expect(!result.contains(key))
        @Expect(inherited.contains(key))
    }
    @Expect(result["PATH"], "/usr/bin:/bin")
    @Expect(result["HOME"], "/caller")
    @Expect(result["MY_APP_ARGUMENT"], "unchanged")
}

@Test
func artifactExecutableNameNeverEscapesOrBecomesACommand(): Unit {
    for (name in ["Hello", "Hello World", "仓绘", "Player-arm64"]) { @Expect(validPackagedExecutableName(name)) }
    for (name in ["", ".", "..", "../Other", "/bin/sh", "a/b", "a\\b", "-option", " name", "name ", "a\nb"]) {
        @Expect(!validPackagedExecutableName(name))
    }
}

@Test
func artifactMetadataAndEntryAreValidatedBeforeLaunch(): Unit {
    if (hostPlatform() != "macos") { return }
    let root = joinPath(currentDirectory(), "target/artifact-validation.app")
    if (exists(root)) { throw CuicError("artifact fixture already exists") }
    Directory.create(joinPath(root, "Contents/MacOS"), recursive: true)
    let plist = joinPath(root, "Contents/Info.plist")
    let entry = joinPath(root, "Contents/MacOS/hello")
    let appManifest = parseApplicationManifest("[application]\nname=\"hello\"\nidentifier=\"dev.example.hello\"\nversion=\"1\"\n")
    try {
        File.writeTo(plist, macInfoPlist(appManifest, "").toArray())
        @Expect(readPackagedPlistField(plist, "CFBundleExecutable"), "hello")
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
        File.writeTo(entry, "#!/bin/sh\nexit 0\n".toArray())
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
        removeIfExists(entry)
        Directory.create(entry)
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
        removeIfExists(entry)
        File.writeTo(entry, "not Mach-O".toArray())
        removeIfExists(plist)
        Directory.create(plist)
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
        removeIfExists(plist)
        SymbolicLink.create(plist, to: entry)
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
        removeIfExists(plist)
        File.writeTo(plist, Array<UInt8>(1048577, repeat: 65))
        @Expect(artifactRejects({=> let _ = resolvePackagedMacApplication("macos", root) }))
    } finally { removeIfExists(root, recursive: true) }
}

@Test
func artifactCaptureKeepsExistingOutputAndRejectsBundleWritesAndBusyWork(): Unit {
    let root = joinPath(currentDirectory(), "target/artifact-output-fixture")
    if (exists(root)) { throw CuicError("artifact output fixture already exists") }
    let app = joinPath(root, "Demo.app")
    Directory.create(app, recursive: true)
    let output = joinPath(root, "preview.png")
    File.writeTo(output, "old output".toArray())
    try {
        let work = prepareArtifactCaptureWork(app, output)
        @Expect(exists(work))
        @Expect(String.fromUtf8(File.readFrom(output)), "old output")
        @Expect(artifactRejects({=> let _ = prepareArtifactCaptureWork(app, output) }))
        @Expect(exists(work))
        @Expect(artifactRejects({=> let _ = prepareArtifactCaptureWork(app, joinPath(app, "new/sub.png")) }))
        @Expect(!exists(joinPath(app, "new")))
        let link = joinPath(root, "inside-link")
        SymbolicLink.create(link, to: app)
        @Expect(artifactRejects({=> let _ = prepareArtifactCaptureWork(app, joinPath(link, "preview.png")) }))
        removeIfExists(link)
        SymbolicLink.create(link, to: output)
        @Expect(artifactRejects({=> let _ = prepareArtifactCaptureWork(app, link) }))
    } finally { removeIfExists(root, recursive: true) }
}
