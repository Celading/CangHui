package cuic

import std.collection.{ArrayList, HashMap, HashSet}
import std.convert.*
import std.fs.{Directory, File, FileInfo, Path, exists}
import std.process.executeWithOutput

let SOURCE_SDK_MANIFEST = "canghui-sdk.env"

func protectSourceSdkDestination(framework: String, destination: String): Unit {
    let root = canonicalPackagingPath(joinPath(framework, ".."), "source SDK root")
    let absolute = if (startsWithText(destination, "/") || isWindowsAbsolute(destination)) { destination }
        else { joinPath(currentDirectory(), destination) }
    let candidate = canonicalPackagingPathIfExists(absolute, "application destination")
    if (candidate == root || startsWithText(candidate, root + "/")) {
        throw CuicError("application destination must be outside the immutable source SDK")
    }
}

// A source SDK is an immutable delivery directory, not a writable framework checkout.
// Checksums detect corruption; they do not authenticate a publisher.
func sourceSdkFields(text: String, revision: String, cliVersion: String, target: String,
    paired!: Bool = true): HashMap<String, String> {
    if (paired && target.isEmpty()) { throw CuicError("paired SDK validation requires an exact host target") }
    if (text.size > 16384) { throw CuicError("source SDK manifest exceeds size limit") }
    let fields = HashMap<String, String>()
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        let separator = indexOfText(line, "=")
        if (separator <= 0) { throw CuicError("invalid source SDK manifest") }
        let key = substringTo(line, separator)
        let value = substringFrom(line, separator + 1)
        if (fields.contains(key) || value.isEmpty()) { throw CuicError("duplicate or empty source SDK field") }
        if (key != "schema" && key != "sourceCommit" && key != "cuicVersion" && key != "frameworkVersion" &&
            key != "kitVersion" && key != "compilerVersion" && key != "target" && key != "minimumOS" &&
            key != "nativeFiles" && key != "libc" && key != "minimumLibc") {
            throw CuicError("unknown source SDK field: " + key)
        }
        fields[key] = value
    }
    for (key in ["schema", "sourceCommit", "cuicVersion", "frameworkVersion", "kitVersion",
        "compilerVersion", "target", "nativeFiles"]) {
        if (!fields.contains(key)) { throw CuicError("missing source SDK field: " + key) }
    }
    validateSourceSdkPlatformFields(fields, target)
    if (!validGitCommitId(fields["sourceCommit"]) ||
        (paired && (fields["sourceCommit"] != revision || fields["cuicVersion"] != cliVersion))) {
        throw CuicError("source SDK/CUIC identity mismatch; use the CUIC shipped in this SDK")
    }
    if (fields["compilerVersion"] != "1.1.3") { throw CuicError("unsupported source SDK compiler ABI") }
    for (key in ["frameworkVersion", "kitVersion", "cuicVersion"]) {
        let _ = sourceSdkVersionParts(fields[key], 3)
    }
    fields
}

func sourceSdkNativeNames(value: String, target!: String = "macos-arm64"): Array<String> {
    if (sourceSdkLinuxTarget(target)) { return sourceSdkLinuxNativeNames(value) }
    if (target != "macos-arm64") { throw CuicError("unsupported source SDK native target") }
    let names = value.split(",")
    let seen = HashSet<String>()
    for (name in names) {
        if (name.isEmpty() || name == "." || name == ".." || name.contains("/") || name.contains("\\") ||
            !endsWithText(name, ".dylib") || seen.contains(name)) { throw CuicError("unsafe SDK native filename") }
        for (r in name.toRuneArray()) {
            let c = r.toString()
            if (!(c >= "a" && c <= "z") && !(c >= "A" && c <= "Z") && !(c >= "0" && c <= "9") &&
                c != "_" && c != "." && c != "-") { throw CuicError("unsafe SDK native filename") }
        }
        seen.add(name)
    }
    if (!seen.contains("libSDL3.dylib") || !seen.contains("libSDL3_ttf.dylib")) {
        throw CuicError("source SDK is missing required SDL libraries")
    }
    names
}

func verifySourceSdkFiles(root: String, nativeNames: Array<String>, target!: String = "macos-arm64"): Unit {
    if (target != "macos-arm64" && !sourceSdkLinuxTarget(target)) { throw CuicError("unsupported source SDK target") }
    let ledger = joinPath(root, "SHA256SUMS")
    requireFile(ledger, "source SDK checksum ledger is missing")
    let seen = HashSet<String>()
    for (line in readSourceSdkText(ledger, 4194304).split("\n")) {
        if (line.isEmpty()) { continue }
        if (line.size < 67 || substringTo(substringFrom(line, 64), 2) != "  ") {
            throw CuicError("invalid source SDK checksum entry")
        }
        let relative = substringFrom(line, 66)
        validateManifestRelativePath(relative, "SDK checksum entry")
        let input = joinPath(root, relative)
        let info = FileInfo(input)
        if (seen.contains(relative) || info.isSymbolicLink()) {
            throw CuicError("duplicate or symlink source SDK entry")
        }
        // exists() also accepts FIFOs and sockets. Never hand a special file to
        // shasum: opening a FIFO can wait forever for an unrelated writer.
        if (!info.isRegular()) {
            throw CuicError("source SDK artifact must be a regular file: " + relative)
        }
        ensurePackagingPathStaysInsideProject(root, input, "SDK checksum entry")
        requireFile(input, "source SDK artifact is missing")
        seen.add(relative)
    }
    for (required in ["framework/" + SOURCE_SDK_MANIFEST, "framework/cjpm.toml", "framework/src/chui.cj",
        "bin/cuic", "bin/cuic-debug"]) {
        if (!seen.contains(required)) { throw CuicError("source SDK checksum coverage missing: " + required) }
    }
    let requiredNative = if (sourceSdkLinuxTarget(target)) {
        ["libSDL3.so", "libSDL3.so.0", "libSDL3_ttf.so", "libSDL3_ttf.so.0"]
    } else { ["libSDL3.dylib", "libSDL3_ttf.dylib"] }
    for (name in requiredNative) {
        if (!seen.contains("native/" + name)) { throw CuicError("source SDK required native checksum coverage missing") }
    }
    for (name in nativeNames) {
        if (!seen.contains("native/" + name)) { throw CuicError("source SDK native checksum coverage missing") }
    }
    verifySourceSdkCoverage(root, seen)
    let checker = if (hostPlatform() == "linux") { "/usr/bin/sha256sum" } else { "/usr/bin/shasum" }
    let args = if (hostPlatform() == "linux") { ["-c", "SHA256SUMS"] } else { ["-a", "256", "-c", "SHA256SUMS"] }
    let (code, _, _) = executeWithOutput(checker, args,
        workingDirectory: Path(root))
    if (code != 0) { throw CuicError("source SDK checksum verification failed") }
}

func verifySourceSdkCoverage(root: String, seen: HashSet<String>): Unit {
    let pending = ArrayList<String>()
    pending.add("")
    var index: Int64 = 0
    var count: Int64 = 0
    while (index < pending.size) {
        let directory = pending[index]
        index += 1
        for (entry in Directory.readFrom(joinPath(root, directory))) {
            count += 1
            if (count > 20000 || entry.isSymbolicLink()) { throw CuicError("SDK symlink or file-count limit exceeded") }
            let relative = if (directory.isEmpty()) { basename(entry.path.toString()) }
                else { directory + "/" + basename(entry.path.toString()) }
            if (entry.isDirectory()) { pending.add(relative) }
            else if (relative != "SHA256SUMS" && !seen.contains(relative)) {
                throw CuicError("unlisted file in immutable source SDK: " + relative)
            }
        }
    }
}

func bootstrapSourceSdk(framework: String, staging: String): Bool {
    let manifest = joinPath(framework, SOURCE_SDK_MANIFEST)
    if (!exists(manifest)) { return false }
    let root = canonicalPackagingPath(joinPath(framework, ".."), "source SDK root")
    let fields = sourceSdkFields(readSourceSdkText(manifest, 16384), CUIC_BUILD_REVISION,
        VERSION, sourceSdkHostTarget())
    requireSourceSdkExecutionTarget(fields["target"])
    let names = sourceSdkNativeNames(fields["nativeFiles"])
    let (compilerCode, compilerOut, _) = executeWithOutput("cjc", ["--version"])
    if (compilerCode != 0 || !sourceSdkCompilerMatches(String.fromUtf8(compilerOut))) {
        throw CuicError("this source SDK requires Cangjie compiler 1.1.3")
    }
    let (osCode, osOut, _) = executeWithOutput("/usr/bin/sw_vers", ["-productVersion"])
    if (osCode != 0 || !sourceSdkOSAtLeast(trimAscii(String.fromUtf8(osOut)), fields["minimumOS"])) {
        throw CuicError("source SDK requires macOS " + fields["minimumOS"] + " or newer")
    }
    verifySourceSdkFiles(root, names)
    verifySourceSdkPackageIdentity(root, fields)
    ensurePackagingDirectory(joinPath(staging, "sdl/.sdl3"))
    for (name in names) { copyNativeLibrary(joinPath(root, "native/" + name), joinPath(staging, "sdl/.sdl3/" + name)) }
    true
}

func sourceSdkOSAtLeast(actual: String, minimum: String): Bool {
    let a = sourceSdkVersionParts(actual, 1)
    let b = sourceSdkVersionParts(minimum, 1)
    var result: Int64 = 0
    for (i in 0..3) {
        let av = if (i < a.size) { a[i] } else { 0 }
        let bv = if (i < b.size) { b[i] } else { 0 }
        if (result == 0 && av != bv) { result = if (av > bv) { 1 } else { -1 } }
    }
    result >= 0
}

func sourceSdkBuildArguments(args: Array<String>): Array<String> {
    if (args.isEmpty()) { return args }
    for (arg in args) {
        if (arg == "-j" || arg == "--jobs" || arg == "--build-args") { return args }
    }
    let result = ArrayList<String>()
    for (arg in args) { result.add(arg) }
    if (args[0] == "build" || args[0] == "test") { result.add("-j"); result.add("1") }
    else if (args[0] == "run") { result.add("--build-args"); result.add("-j 1") }
    result.toArray()
}

let SOURCE_SDK_BUNDLED_FONT = "canghui-sdk/fonts/HarmonyOS_Sans_SC.ttf"

func generatedSdkMain(packageName: String): String {
    generatedWelcomeMain(packageName, true)
}

func generatedWelcomeMain(packageName: String, sdkMode: Bool): String {
    "package ${packageName}\n\n" +
    "import chui.{ApplicationPaths, Button, ButtonRole, ComponentProbe, DesktopApp, Fonts, Label, " +
    "LengthUnits, ProbeProperty, State, VStack, WindowSpec, runKModeStdioIfRequested}\n" +
    (if (sdkMode) { "import chui.WindowScaleSettings\n" } else { "" }) +
    "import chui.kmode.macros.*\n\n" +
    "func welcomeContent(message: State<String>): Unit {\n" +
    "    VStack(spacing: 12.vp) {\n" +
    "        Label(message.value).fontSize(26.fp).probe(\"welcome.message\", \"Label\", [ProbeProperty(\"label\", message.value)])\n" +
    "        Button(\"更新状态\", {=> message.value = \"CangHui 已准备好\"}).key(\"welcome.ready\").role(ButtonRole.Primary)\n" +
    "    }.padding(24.vp)\n}\n\n" +
    "@CuiProbe[\"welcome.main\"]\nfunc welcomeProbe(script: String): String {\n" +
    "    let message = State<String>(\"你好，CangHui\")\n" +
    "    ComponentProbe(\"welcome.main\", width: 720.0, height: 480.0).run(script) { welcomeContent(message) }\n}\n\n" +
    "main(): Unit {\n" +
    "    // SDL resolves .app Resources independently of the launch working directory.\n" +
    "    match (ApplicationPaths.basePath()) {\n" +
    "        case Some(base) => Fonts.registerBundledFallback(base + \"${SOURCE_SDK_BUNDLED_FONT}\")\n" +
    "        case None => ()\n    }\n" +
    "    if (runKModeStdioIfRequested()) { return }\n" +
    "    let message = State<String>(\"你好，CangHui\")\n" +
    "    DesktopApp(WindowSpec(\"${packageName}\", 720, 480" +
    (if (sdkMode) { ", scaling: Some(WindowScaleSettings())" } else { "" }) + ")).run {\n" +
    "        welcomeContent(message)\n    }\n}\n"
}
