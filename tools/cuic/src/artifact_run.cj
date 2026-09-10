package cuic

import std.collection.{ArrayList, HashMap}
import std.env.getVariables
import std.fs.{Directory, File, FileInfo, Path, exists, removeIfExists}
import std.process.{ProcessRedirect, executeWithOutput, launch}

// A trusted local artifact launch, not an installer, signature verifier or sandbox.
// Never resolve a source project or augment its native/SDK search path here.
class PackagedMacApplication {
    let root: String
    let executable: String

    init(root: String, executable: String) {
        this.root = root
        this.executable = executable
    }
}

class ArtifactRunOptions {
    let platform: String
    let artifact: String
    let appArgs: Array<String>

    init(platform: String, artifact: String, appArgs: Array<String>) {
        this.platform = platform
        this.artifact = artifact
        this.appArgs = appArgs
    }
}

func parseArtifactRunOptions(args: Array<String>, start: Int64): ArtifactRunOptions {
    var platform = hostPlatform()
    var artifact = ""
    let appArgs = ArrayList<String>()
    var i = start
    if (i < args.size && isPlatform(args[i])) { platform = normalizePlatform(args[i]); i += 1 }
    while (i < args.size) {
        if (args[i] == "--") {
            i += 1
            while (i < args.size) { appArgs.add(args[i]); i += 1 }
            break
        }
        if (startsWithText(args[i], "-")) { throw CuicError("unknown package run option '${args[i]}'") }
        if (!artifact.isEmpty()) { throw CuicError("package run accepts one artifact; put application arguments after --") }
        artifact = args[i]
        i += 1
    }
    if (artifact.isEmpty()) { throw CuicError("package run requires a trusted local .app artifact") }
    ArtifactRunOptions(platform, artifact, appArgs.toArray())
}

func applicationPackagingRunCommand(args: Array<String>, start: Int64): Int64 {
    let options = parseArtifactRunOptions(args, start)
    let app = resolvePackagedMacApplication(options.platform, options.artifact)
    println("==> running packaged application (no build, no SDK environment): ${app.root}")
    executePackagedApplication(app, options.appArgs, currentPackagedApplicationEnvironment())
}

func requireArtifactDirectory(path: String): Unit {
    let info = FileInfo(path)
    if (info.isSymbolicLink() || !info.isDirectory()) {
        throw CuicError("artifact directory must not be a symlink: ${path}")
    }
}

func requireArtifactFile(root: String, path: String): Unit {
    let info = FileInfo(path)
    if (info.isSymbolicLink() || !info.isRegular()) {
        throw CuicError("artifact input must be a regular non-symlink file: ${path}")
    }
    ensurePackagingPathStaysInsideProject(root, path, "artifact input")
}

func validPackagedExecutableName(value: String): Bool {
    value.size <= 255 && isApplicationNameSafe(value) && !startsWithText(value, "-")
}

func readPackagedPlistField(plist: String, field: String): String {
    // Only fixed field names below reach this command. The plist is one argv item.
    let (code, bytes, _) = executeWithOutput("/usr/libexec/PlistBuddy", ["-c", "Print :" + field, plist])
    let raw = String.fromUtf8(bytes)
    let value = if (endsWithText(raw, "\n")) { substringTo(raw, Int64(raw.toRuneArray().size) - 1) } else { raw }
    if (code != 0 || value.isEmpty() || value.size > 255) {
        throw CuicError("packaged application has invalid " + field)
    }
    value
}

func resolvePackagedMacApplication(platform: String, requested: String): PackagedMacApplication {
    if (platform != "macos" || hostPlatform() != "macos") {
        throw CuicError("packaged artifact execution currently requires a macOS host and macos target")
    }
    let absolute = if (startsWithText(requested, "/")) { requested } else { joinPath(currentDirectory(), requested) }
    let normalized = Path(absolute).normalize().toString()
    if (!endsWithText(normalized, ".app")) { throw CuicError("packaged artifact must end in .app") }
    requireArtifactDirectory(normalized)
    let root = canonicalPackagingPath(normalized, "application artifact")
    requireArtifactDirectory(joinPath(root, "Contents"))
    requireArtifactDirectory(joinPath(root, "Contents/MacOS"))
    let plist = joinPath(root, "Contents/Info.plist")
    requireArtifactFile(root, plist)
    if (FileInfo(plist).size > 1048576) { throw CuicError("application Info.plist exceeds size limit") }
    if (readPackagedPlistField(plist, "CFBundlePackageType") != "APPL") {
        throw CuicError("artifact is not an APPL bundle")
    }
    let name = readPackagedPlistField(plist, "CFBundleExecutable")
    if (!validPackagedExecutableName(name)) { throw CuicError("unsafe packaged executable name") }
    let executable = joinPath(root, "Contents/MacOS/" + name)
    requireArtifactFile(root, executable)
    let (code, bytes, _) = executeWithOutput("/usr/bin/file", ["-b", executable])
    let kind = String.fromUtf8(bytes)
    if (code != 0 || !kind.contains("Mach-O") || !kind.contains(" executable")) {
        throw CuicError("packaged application entry must be a Mach-O executable")
    }
    PackagedMacApplication(root, executable)
}

func currentPackagedApplicationEnvironment(): HashMap<String, String> {
    let inherited = HashMap<String, String>()
    for ((key, value) in getVariables()) { inherited.add(key, value) }
    packagedApplicationEnvironment(inherited)
}

func packagedApplicationEnvironment(inherited: HashMap<String, String>): HashMap<String, String> {
    let environment = HashMap<String, String>()
    for ((key, value) in inherited) {
        if (startsWithText(key, "DYLD_") || startsWithText(key, "LD_") ||
            startsWithText(key, "CANGHUI_") || startsWithText(key, "CUI_") ||
            startsWithText(key, "CUIC_") || startsWithText(key, "CANGJIE_") ||
            startsWithText(key, "STDX_") || startsWithText(key, "SDL_") ||
            key == "LIBRARY_PATH" || key == "cjProcessorNum") { continue }
        environment.add(key, value)
    }
    environment
}

func executePackagedApplication(app: PackagedMacApplication, args: Array<String>,
    environment: HashMap<String, String>): Int64 {
    try {
        let process = launch(app.executable, args, workingDirectory: Path(app.root),
            environment: workingDirectoryEnvironment(app.root, environment),
            stdIn: ProcessRedirect.Inherit, stdOut: ProcessRedirect.Inherit, stdErr: ProcessRedirect.Inherit)
        process.wait()
    } catch (error: Exception) {
        println("error: failed to launch packaged application: ${error.message}")
        127
    }
}

func prepareArtifactCaptureWork(appRoot: String, output: String): String {
    // Protect the bundle even when an output parent is a symlink back into it.
    let ancestor = canonicalPackagingPathIfExists(output, "capture output")
    if (ancestor == appRoot || startsWithText(ancestor, appRoot + "/")) {
        throw CuicError("artifact capture output must be outside the application bundle")
    }
    if (exists(output) && (FileInfo(output).isSymbolicLink() || !FileInfo(output).isRegular())) {
        throw CuicError("capture output must be a regular non-symlink file")
    }
    if (!exists(parentPath(output))) { Directory.create(parentPath(output), recursive: true) }
    let work = output + ".cuic-capture"
    // Exclusive creation; never consume or erase a previous capture's work directory.
    Directory.create(work)
    work
}

func printPackagedApplication(options: PrntOptions): Int64 {
    let app = resolvePackagedMacApplication(options.platform, options.artifact)
    let requested = if (options.output.isEmpty()) { "cuic-" + basename(app.root) + ".png" } else { options.output }
    let output = Path(if (startsWithText(requested, "/")) { requested }
        else { joinPath(currentDirectory(), requested) }).normalize().toString()
    if (!endsWithText(output, ".png") && !endsWithText(output, ".PNG")) {
        throw CuicError("prnt --artifact requires a .png output and a native CangHui PNG capture host")
    }
    let work = prepareArtifactCaptureWork(app.root, output)
    let snapshot = joinPath(work, "frame.png")
    let receipt = joinPath(work, "window.txt")
    try {
        let environment = currentPackagedApplicationEnvironment()
        environment.add("CANGHUI_CAPTURE_PATH", snapshot)
        environment.add("CANGHUI_CAPTURE_FRAMES", options.frames.toString())
        environment.add("CANGHUI_CAPTURE_WINDOW", options.windowId)
        environment.add("CANGHUI_CAPTURE_WINDOW_RECEIPT", if (options.windowId.isEmpty()) { "" } else { receipt })
        environment.add("cjProcessorNum", "1")
        println("==> capturing packaged application via CangHui (no build): ${app.root}")
        let code = executePackagedApplication(app, options.appArgs.toArray(), environment)
        if (code != 0) { return code }
        var actual = None<String>
        if (!options.windowId.isEmpty() && exists(receipt)) {
            requireArtifactFile(work, receipt)
            if (FileInfo(receipt).size > 4096) { throw CuicError("capture window receipt exceeds size limit") }
            actual = Some(String.fromUtf8(File.readFrom(receipt)))
        }
        verifyCaptureWindowSelection(options.windowId, actual)
        requireArtifactFile(work, snapshot)
        publishDesktopPng(snapshot, output)
        println("snapshot: ${output}")
        0
    } finally {
        // Remove only the files we assigned, not arbitrary application-created contents.
        removeIfExists(snapshot)
        removeIfExists(receipt)
        removeIfExists(work)
    }
}
