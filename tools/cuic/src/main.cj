package cuic

import std.collection.ArrayList
import std.env.{getCommandLine, getVariable}
import std.fs.{Directory, File, Path, exists, removeIfExists}
import std.process.executeWithOutput

let VERSION = "0.4.0"

class CuicError <: Exception {
    init(message: String) {
        super(message)
    }
}

main(): Int64 {
    try {
        runCuic(getCommandLine())
    } catch (e: CuicError) {
        println("error: ${e.message}")
        1
    } catch (e: Exception) {
        println("error: ${e.message}")
        1
    }
}

func runCuic(args: Array<String>): Int64 {
    runCuicInternal(args, true)
}

func runCuicInternal(args: Array<String>, allowProjectScripts: Bool): Int64 {
    if (args.size <= 1) {
        println(helpText())
        return 0
    }
    let command = args[1]
    if (command == "help" || command == "--help" || command == "-h") {
        println(helpText())
        return 0
    }
    if (command == "version" || command == "--version" || command == "-V") {
        println(renderCuicVersion())
        return 0
    }
    if (command == "examples") {
        return listExamples(frameworkForCurrentCommand())
    }
    if (command == "doctor") {
        return doctorCommand(args, 2)
    }
    if (command == "bootstrap") {
        let platform = if (args.size > 2) { normalizePlatform(args[2]) } else { hostPlatform() }
        return bootstrap(platform, frameworkForCurrentCommand())
    }
    if (command == "font") {
        return fontCommand(args, 2)
    }
    if (command == "symbol") {
        return symbolCommand(args, 2, frameworkForCurrentCommand())
    }
    if (command == "kmode") {
        return kModeCommand(args, 2)
    }
    if (command == "probe") {
        return probeCommand(args, 2)
    }
    if (command == "scripts") {
        return scriptsCommand(args, 2)
    }
    if (command == "init") {
        return initProject(args, 2)
    }
    if (command == "build" || command == "test") {
        let parsed = parsePlatformAndProject(args, 2, "")
        return runCjpm(command, parsed.platform, parsed.project)
    }
    if (command == "run") {
        let parsed = parsePlatformAndProject(args, 2, "notepad")
        return runCjpm("run", parsed.platform, parsed.project)
    }
    if (command == "prnt" || command == "print" || command == "snapshot") {
        return printWindow(args, 2)
    }
    if (command == "clean") {
        let requested = if (args.size > 2) { args[2] } else { "" }
        let project = resolveProject(requested, "")
        return executeCommand("cjpm", ["clean"], project)
    }
    if (allowProjectScripts) {
        match (tryRunProjectScript(args, command)) {
            case Some(code) => return code
            case None => ()
        }
    }
    throw CuicError("unknown command '${command}'")
}

class ProjectSelection {
    let platform: String
    let project: String

    init(platform: String, project: String) {
        this.platform = platform
        this.project = project
    }
}

func parsePlatformAndProject(args: Array<String>, start: Int64, defaultExample: String): ProjectSelection {
    var platform = hostPlatform()
    var index = start
    if (index < args.size && isPlatform(args[index])) {
        platform = normalizePlatform(args[index])
        index += 1
    }
    let requested = if (index < args.size) {
        args[index]
    } else {
        implicitProjectRequest(defaultExample, exists(joinPath(currentDirectory(), "cjpm.toml")))
    }
    ProjectSelection(platform, resolveProject(requested, ""))
}

func implicitProjectRequest(defaultExample: String, currentProjectAvailable: Bool): String {
    if (currentProjectAvailable) { "" } else { defaultExample }
}

func helpText(): String {
    "CangHui CLI\n\n" +
    "Usage:\n" +
    "  cuic init <directory> [--name <package>] [--platform <platform>]\n" +
    "      [--canghui-path <path> | --canghui-git <url> --canghui-commit <commit>]\n" +
    "  cuic doctor [target] [--project <directory>] [--json] [--verbose]\n" +
    "  cuic bootstrap [platform]\n" +
    "  cuic font <status|install> [platform]\n" +
    "  cuic symbol list [material|ant|arco] [--json]\n" +
    "  cuic symbol generate <provider:name[@export]>... --output <file.cj> [--package <name>]\n" +
    "  cuic kmode diff [project]\n" +
    "  cuic kmode list [project]\n" +
    "  cuic kmode describe [project] <endpoint>\n" +
    "  cuic kmode call [project] <endpoint> [payload]\n" +
    "  cuic probe diff [project]\n" +
    "  cuic probe list [project] [--json]\n" +
    "  cuic probe describe [project] <probe> [--json]\n" +
    "  cuic probe run [project] <probe> [--script <file>|--events <script>] [--json]\n" +
    "  cuic scripts init|list [project]\n" +
    "  cuic scripts run <name> [project]\n" +
    "  cuic build [platform] [project]\n" +
    "  cuic test [platform] [project]\n" +
    "  cuic run [platform] [project|example]\n" +
    "  cuic prnt [platform] [project|example] [--output <file.bmp|file.png>] [-- <app args...>]\n" +
    "  cuic clean [project]\n" +
    "  cuic examples\n" +
    "  cuic version\n\n" +
    "Project scripts: declare portable lifecycle pipelines in canghui.toml, then run cuic <name>.\n" +
    "Framework: generated projects use a public Git dependency pinned by commit and CJPM cache. " +
    "Use --canghui-path or CANGHUI_FRAMEWORK_ROOT only for local framework development."
}

func hostPlatform(): String {
    try {
        let (code, out, _) = executeWithOutput("uname", ["-s"])
        if (code == 0) {
            let name = trimAscii(String.fromUtf8(out))
            if (name == "Darwin") { return "macos" }
            if (name == "Linux") { return "linux" }
        }
    } catch (_: Exception) {}
    "windows"
}

func isPlatform(value: String): Bool {
    value == "mac" || value == "macos" || value == "darwin" || value == "win" ||
    value == "windows" || value == "linux" || value == "android"
}

func normalizePlatform(value: String): String {
    if (value == "mac" || value == "macos" || value == "darwin") { return "macos" }
    if (value == "win" || value == "windows") { return "windows" }
    if (value == "linux" || value == "android") { return value }
    throw CuicError("unknown platform '${value}'")
}

func currentDirectory(): String {
    if (hostPlatform() == "windows") {
        let (code, out, _) = executeWithOutput("cmd", ["/D", "/C", "cd"])
        if (code == 0) { return trimAscii(String.fromUtf8(out)) }
    } else {
        let (code, out, _) = executeWithOutput("pwd", [])
        if (code == 0) { return trimAscii(String.fromUtf8(out)) }
    }
    throw CuicError("cannot resolve current directory")
}

func frameworkForCurrentCommand(): String {
    let cwd = currentDirectory()
    if (exists(joinPath(cwd, "cjpm.toml"))) {
        return ensureFrameworkRoot(cwd)
    }
    resolveFrameworkRoot("")
}

func cliRoot(): String {
    match (getVariable("CANGHUI_CLI_ROOT")) {
        case Some(value) where value.size > 0 => return trimTrailingSlash(value)
        case _ => ()
    }
    match (getVariable("CANGUI_CLI_ROOT")) {
        case Some(value) where value.size > 0 => return trimTrailingSlash(value)
        case _ => ()
    }
    let cwd = currentDirectory()
    if (exists(joinPath(cwd, "cjpm.toml")) && exists(joinPath(cwd, "src/main.cj")) &&
        exists(joinPath(cwd, "bin/cuic"))) {
        return cwd
    }
    let command = getCommandLine()[0]
    parentPath(parentPath(parentPath(parentPath(command))))
}

func resolveFrameworkRoot(project: String): String {
    let integrated = integratedFrameworkRoot()
    if (integrated.size > 0) {
        return integrated
    }
    for (name in ["CANGHUI_FRAMEWORK_ROOT", "CANGUI_FRAMEWORK_ROOT"]) {
        match (getVariable(name)) {
            case Some(value) where value.size > 0 => return validateFramework(value)
            case _ => ()
        }
    }
    if (project.size > 0 && exists(joinPath(project, "cjpm.toml"))) {
        let spec = frameworkDependencySpec(project)
        if (spec.isLocal()) {
            let dependency = if (startsWithText(spec.path, "/") || isWindowsAbsolute(spec.path)) {
                spec.path
            } else {
                joinPath(project, spec.path)
            }
            return validateFramework(dependency)
        }
        let cached = cachedFrameworkRoot(project)
        if (!cached.isEmpty()) {
            return cached
        }
    }
    let parent = parentPath(cliRoot())
    for (name in ["CangHui", "CangjieGUI"]) {
        let candidate = joinPath(parent, name)
        if (frameworkRootCandidate(candidate)) {
            return trimTrailingSlash(candidate)
        }
    }
    throw CuicError("CangHui dependency is not available; run cuic build in a project or set CANGHUI_FRAMEWORK_ROOT")
}

func integratedFrameworkRoot(): String {
    let candidate = parentPath(parentPath(cliRoot()))
    if (frameworkRootCandidate(candidate) && exists(joinPath(candidate, "tools/cuic/cjpm.toml"))) {
        return trimTrailingSlash(candidate)
    }
    let cwd = currentDirectory()
    if (frameworkRootCandidate(cwd) && exists(joinPath(cwd, "tools/cuic/cjpm.toml"))) {
        return trimTrailingSlash(cwd)
    }
    ""
}

func frameworkRootCandidate(path: String): Bool {
    exists(joinPath(path, "cjpm.toml")) && exists(joinPath(path, "sdl")) && exists(joinPath(path, "src/cui.cj"))
}

func validateFramework(path: String): String {
    let normalized = trimTrailingSlash(path)
    if (!frameworkRootCandidate(normalized)) {
        throw CuicError("CangHui not found at ${path}; set CANGHUI_FRAMEWORK_ROOT")
    }
    normalized
}

func resolveProject(requested: String, frameworkHint: String): String {
    let direct = if (requested.size == 0) { currentDirectory() } else { requested }
    if (exists(joinPath(direct, "cjpm.toml"))) { return trimTrailingSlash(direct) }
    let framework = if (frameworkHint.size > 0) { frameworkHint } else { resolveFrameworkRoot("") }
    let example = joinPath(joinPath(framework, "examples"), requested)
    if (exists(joinPath(example, "cjpm.toml"))) { return example }
    throw CuicError("no cjpm.toml found in ${direct}")
}

func bootstrap(platform: String, framework: String): Int64 {
    if (platform == "android") {
        throw CuicError("Android backend is not implemented: no cjpm target, SDL activity bridge, NDK packaging, or APK runner")
    }
    let host = hostPlatform()
    if (platform != host) {
        throw CuicError("target '${platform}' requires a ${platform} host; current host is '${host}'")
    }
    if (platform == "windows") {
        requireFile(joinPath(framework, "sdl/.sdl3/SDL3.dll"), "SDL3.dll is missing")
        requireFile(joinPath(framework, "sdl/.sdl3/SDL3_ttf.dll"), "SDL3_ttf.dll is missing")
        println("Windows SDL libraries are ready in ${joinPath(framework, "sdl/.sdl3")}")
        return 0
    }
    let sdlDirectory = joinPath(framework, "sdl/.sdl3")
    if (!exists(sdlDirectory)) { Directory.create(sdlDirectory, recursive: true) }
    if (platform == "macos") {
        let sdl3 = homebrewLibrary("sdl3", "libSDL3.dylib")
        let sdl3Ttf = homebrewLibrary("sdl3_ttf", "libSDL3_ttf.dylib")
        copyNativeLibrary(sdl3, joinPath(sdlDirectory, "libSDL3.dylib"))
        copyNativeLibrary(sdl3Ttf, joinPath(sdlDirectory, "libSDL3_ttf.dylib"))
    } else {
        let sdl3 = pkgConfigLibrary("sdl3", "libSDL3.so")
        let sdl3Ttf = pkgConfigLibrary("sdl3-ttf", "libSDL3_ttf.so")
        copyNativeLibrary(sdl3, joinPath(sdlDirectory, "libSDL3.so"))
        copyNativeLibrary(sdl3Ttf, joinPath(sdlDirectory, "libSDL3_ttf.so"))
    }
    println("${platform} SDL libraries are ready in ${sdlDirectory}")
    0
}

func homebrewLibrary(formula: String, library: String): String {
    let (code, stdoutBytes, _) = executeWithOutput("brew", ["--prefix", formula])
    if (code != 0) {
        throw CuicError("Homebrew formula '${formula}' is not installed; run: brew install sdl3 sdl3_ttf")
    }
    let path = joinPath(trimAscii(String.fromUtf8(stdoutBytes)), "lib/${library}")
    requireFile(path, "expected Homebrew library not found: ${path}")
    path
}

func pkgConfigLibrary(packageName: String, library: String): String {
    let (existsCode, _, _) = executeWithOutput("pkg-config", ["--exists", packageName])
    if (existsCode != 0) { throw CuicError("pkg-config package '${packageName}' is not installed") }
    let (prefixCode, stdoutBytes, _) = executeWithOutput("pkg-config", ["--variable=libdir", packageName])
    if (prefixCode != 0) { throw CuicError("cannot resolve library directory for '${packageName}'") }
    let path = joinPath(trimAscii(String.fromUtf8(stdoutBytes)), library)
    requireFile(path, "expected pkg-config library not found: ${path}")
    path
}

func copyNativeLibrary(source: String, destination: String): Unit {
    removeIfExists(destination)
    File.writeTo(destination, File.readFrom(source))
}

func runCjpm(action: String, platform: String, project: String): Int64 {
    let framework = ensureFrameworkRoot(project)
    let diffCode = runKModeDiff(project, quiet: true)
    if (diffCode != 0) { return diffCode }
    let probeDiffCode = runProbeDiff(project, quiet: true)
    if (probeDiffCode != 0) { return probeDiffCode }
    let boot = bootstrap(platform, framework)
    if (boot != 0) { return boot }
    println("==> cjpm ${action} (${platform}) in ${project}")
    executeCjpm(project, [action], framework)
}

func executeCjpm(project: String, cjpmArgs: Array<String>, framework: String): Int64 {
    let sdl = joinPath(framework, "sdl/.sdl3")
    let font = runtimeHarmonyFont(framework)
    if (hostPlatform() == "windows") {
        let command = windowsCjpmCommand(sdl, font, cjpmArgs)
        return executeCommand("cmd", ["/D", "/C", command], project)
    }
    let args = ArrayList<String>()
    if (hostPlatform() == "macos") {
        args.add("DYLD_LIBRARY_PATH=${sdl}:${readEnv("DYLD_LIBRARY_PATH")}")
    } else {
        args.add("LD_LIBRARY_PATH=${sdl}:${readEnv("LD_LIBRARY_PATH")}")
    }
    args.add("CANGHUI_HARMONYOS_SANS=${font}")
    args.add("cjpm")
    for (arg in cjpmArgs) { args.add(arg) }
    executeCommand("/usr/bin/env", args.toArray(), project)
}

func executeCjpmQuiet(project: String, cjpmArgs: Array<String>, framework: String): Int64 {
    let sdl = joinPath(framework, "sdl/.sdl3")
    let font = runtimeHarmonyFont(framework)
    if (hostPlatform() == "windows") {
        let command = windowsCjpmCommand(sdl, font, cjpmArgs)
        return executeCommandQuiet("cmd", ["/D", "/C", command], project)
    }
    let args = ArrayList<String>()
    if (hostPlatform() == "macos") {
        args.add("DYLD_LIBRARY_PATH=${sdl}:${readEnv("DYLD_LIBRARY_PATH")}")
    } else {
        args.add("LD_LIBRARY_PATH=${sdl}:${readEnv("LD_LIBRARY_PATH")}")
    }
    args.add("CANGHUI_HARMONYOS_SANS=${font}")
    args.add("cjpm")
    for (arg in cjpmArgs) { args.add(arg) }
    executeCommandQuiet("/usr/bin/env", args.toArray(), project)
}

func executeCommand(program: String, args: Array<String>, workingDirectory: String): Int64 {
    try {
        let (code, stdoutBytes, stderrBytes) = executeWithOutput(program, args, workingDirectory: Path(workingDirectory))
        let stdout = String.fromUtf8(stdoutBytes)
        let stderr = String.fromUtf8(stderrBytes)
        if (stdout.size > 0) { print(stdout, flush: true) }
        if (stderr.size > 0) { print(stderr, flush: true) }
        code
    } catch (e: Exception) {
        println("error: failed to execute ${program}: ${e.message}")
        127
    }
}

func executeCommandQuiet(program: String, args: Array<String>, workingDirectory: String): Int64 {
    try {
        let (code, stdoutBytes, stderrBytes) = executeWithOutput(program, args, workingDirectory: Path(workingDirectory))
        if (code != 0) {
            let stdout = String.fromUtf8(stdoutBytes)
            let stderr = String.fromUtf8(stderrBytes)
            if (stdout.size > 0) { print(stdout, flush: true) }
            if (stderr.size > 0) { print(stderr, flush: true) }
        }
        code
    } catch (e: Exception) {
        println("error: failed to execute ${program}: ${e.message}")
        127
    }
}

func resolveHarmonyFont(platform: String): String {
    let bundled = bundledHarmonyFont()
    if (exists(bundled)) { return bundled }
    let installed = resolveInstalledHarmonyFont(platform)
    if (installed.size > 0) { return installed }
    ""
}

func resolveInstalledHarmonyFont(platform: String): String {
    let home = if (platform == "windows") { readEnv("USERPROFILE") } else { readEnv("HOME") }
    for (path in installedHarmonyFontCandidates(platform, home)) {
        if (exists(path)) { return path }
    }
    ""
}

func installedHarmonyFontCandidates(platform: String, home: String): Array<String> {
    let candidates = ArrayList<String>()
    if (platform == "macos") {
        candidates.add(joinPath(home, "Library/Fonts/HarmonyOS_Sans_SC.ttf"))
        candidates.add(joinPath(home, "Library/Fonts/HarmonyOS Sans SC.ttf"))
        candidates.add("/Library/Fonts/HarmonyOS_Sans_SC.ttf")
        candidates.add("/Library/Fonts/HarmonyOS Sans SC.ttf")
    } else if (platform == "windows") {
        candidates.add("C:\\Windows\\Fonts\\HarmonyOS_Sans_SC.ttf")
        candidates.add("C:\\Windows\\Fonts\\HarmonyOS Sans SC.ttf")
    } else {
        candidates.add(joinPath(home, ".local/share/fonts/HarmonyOS_Sans_SC.ttf"))
        candidates.add("/usr/local/share/fonts/HarmonyOS_Sans_SC.ttf")
        candidates.add("/usr/share/fonts/truetype/harmonyos/HarmonyOS_Sans_SC.ttf")
    }
    candidates.toArray()
}

func bundledHarmonyFont(): String {
    let integrated = integratedFrameworkRoot()
    if (integrated.size > 0) {
        return joinPath(integrated, "assets/fonts/HarmonyOS_Sans_SC.ttf")
    }
    let projectFramework = tryResolveFrameworkRoot(currentDirectory())
    if (!projectFramework.isEmpty()) {
        return joinPath(projectFramework, "assets/fonts/HarmonyOS_Sans_SC.ttf")
    }
    joinPath(cliRoot(), "assets/fonts/HarmonyOS_Sans_SC.ttf")
}

func fontCommand(args: Array<String>, start: Int64): Int64 {
    let action = if (start < args.size) { args[start] } else { "status" }
    let platform = if (start + 1 < args.size) { normalizePlatform(args[start + 1]) } else { hostPlatform() }
    let framework = frameworkForCurrentCommand()
    if (action == "status") {
        let source = joinPath(framework, "assets/fonts/HarmonyOS_Sans_SC.ttf")
        requireFile(source, "HarmonyOS Sans SC source is missing from CangHui")
        println("HarmonyOS Sans SC bundled fallback: ${source}")
        let installed = resolveInstalledHarmonyFont(platform)
        if (installed.size > 0) {
            println("optional host installation: ${installed}")
        } else {
            println("optional host installation: not installed")
            println("install with: cuic font install ${platform}")
        }
        println("default resolution: component -> theme/application -> bundled -> system")
        return 0
    }
    if (action != "install") { throw CuicError("font action must be 'status' or 'install'") }
    if (platform != hostPlatform()) {
        throw CuicError("font installation for '${platform}' requires a ${platform} host")
    }
    let source = joinPath(framework, "assets/fonts/HarmonyOS_Sans_SC.ttf")
    requireFile(source, "HarmonyOS Sans SC source is missing from CangHui")
    let home = readEnv(if (platform == "windows") { "USERPROFILE" } else { "HOME" })
    if (home.isEmpty()) { throw CuicError("cannot resolve the current user's home directory") }
    let destination = if (platform == "macos") {
        joinPath(home, "Library/Fonts/HarmonyOS_Sans_SC.ttf")
    } else if (platform == "linux") {
        joinPath(home, ".local/share/fonts/HarmonyOS_Sans_SC.ttf")
    } else {
        throw CuicError("automatic Windows font registration is not implemented; install the bundled TTF with Windows Settings")
    }
    let parent = parentPath(destination)
    if (!exists(parent)) { Directory.create(parent, recursive: true) }
    copyNativeLibrary(source, destination)
    println("HarmonyOS Sans SC installed: ${destination}")
    println("restart running CangHui applications to use the installed compatibility font")
    0
}

func listExamples(framework: String): Int64 {
    let root = joinPath(framework, "examples")
    for (entry in Directory.readFrom(root)) {
        if (entry.isDirectory() && exists(joinPath(entry.path.toString(), "cjpm.toml"))) {
            println(basename(entry.path.toString()))
        }
    }
    0
}

func initProject(args: Array<String>, start: Int64): Int64 {
    var directory = ""
    var packageName = ""
    var platform = hostPlatform()
    var frameworkPath = ""
    var frameworkGit = DEFAULT_CANGHUI_GIT
    var frameworkCommit = DEFAULT_CANGHUI_COMMIT
    var gitCustomized = false
    var i = start
    while (i < args.size) {
        let current = args[i]
        if ((current == "--name" || current == "--platform" || current == "--canghui-path" ||
            current == "--cui-path" || current == "--canghui-git" || current == "--canghui-commit") &&
            i + 1 >= args.size) {
            throw CuicError("${current} requires a value")
        }
        if (current == "--name") { packageName = args[i + 1]; i += 2; continue }
        if (current == "--platform") { platform = normalizePlatform(args[i + 1]); i += 2; continue }
        if (current == "--canghui-path" || current == "--cui-path") {
            frameworkPath = validateFramework(args[i + 1])
            i += 2
            continue
        }
        if (current == "--canghui-git") {
            frameworkGit = args[i + 1]
            gitCustomized = true
            i += 2
            continue
        }
        if (current == "--canghui-commit") {
            frameworkCommit = args[i + 1]
            gitCustomized = true
            i += 2
            continue
        }
        if (startsWithText(current, "-")) { throw CuicError("unknown init option '${current}'") }
        if (directory.size > 0) { throw CuicError("init accepts one destination directory") }
        directory = current
        i += 1
    }
    if (directory.size == 0) { throw CuicError("init requires a destination directory") }
    if (!frameworkPath.isEmpty() && gitCustomized) {
        throw CuicError("--canghui-path cannot be combined with --canghui-git or --canghui-commit")
    }
    if (frameworkPath.isEmpty() && (frameworkGit.isEmpty() || frameworkCommit.isEmpty())) {
        throw CuicError("Git initialization requires both a CangHui URL and commit")
    }
    if (exists(directory)) {
        for (_ in Directory.readFrom(directory)) { throw CuicError("destination is not empty: ${directory}") }
    } else {
        Directory.create(directory, recursive: true)
    }
    Directory.create(joinPath(directory, "src"), recursive: true)
    let dependency = if (!frameworkPath.isEmpty()) {
        installProjectFontAssets(directory, frameworkPath)
        FrameworkDependencySpec(frameworkPath, "", "")
    } else {
        FrameworkDependencySpec("", frameworkGit, frameworkCommit)
    }
    if (packageName.size == 0) { packageName = sanitizePackageName(basename(directory)) }
    let manifest = "[package]\n" +
        "cjc-version = \"1.1.3\"\n" +
        "name = \"${packageName}\"\n" +
        "version = \"0.1.0\"\n" +
        "output-type = \"executable\"\n" +
        "compile-option = \"--set-runtime-rpath\"\n" +
        "description = \"CangHui desktop application.\"\n\n" +
        "[dependencies]\n" +
        renderFrameworkDependency(dependency) + "\n"
    File.writeTo(joinPath(directory, "cjpm.toml"), manifest.toArray())
    File.writeTo(joinPath(directory, PROJECT_MANIFEST), defaultProjectManifest().toArray())
    File.writeTo(joinPath(directory, ".gitignore"), "target/\ndist/\n".toArray())
    File.writeTo(joinPath(directory, "src/main.cj"), generatedMain(packageName).toArray())
    println("created CangHui project: ${directory}")
    println("package: ${packageName}")
    println("platform: ${platform}")
    if (dependency.isLocal()) {
        println("CangHui dependency: local ${dependency.path}")
    } else {
        println("CangHui dependency: ${dependency.git}@${shortCommit(dependency.commitId)}")
        println("next: cd ${directory} && cuic build ${platform}")
    }
    0
}

func generatedMain(packageName: String): String {
    "package ${packageName}\n\n" +
    "import cui.{Button, ButtonRole, DesktopApp, Label, LengthUnits, State, VStack, WindowSpec, runKModeStdioIfRequested}\n\n" +
    "main(): Unit {\n" +
    "    if (runKModeStdioIfRequested()) { return }\n" +
    "    let message = State<String>(\"你好，CangHui\")\n" +
    "    let app = DesktopApp(WindowSpec(\"${packageName}\", 720, 480, scale: 1.5))\n" +
    "    app.run {\n" +
    "        VStack {\n" +
    "            Label(message.value)\n" +
    "            Button(\"更新状态\", {=> message.value = \"CangHui 已准备好\"}).role(ButtonRole.Primary)\n" +
    "        }.spacing(12.vp).padding(24.vp)\n" +
    "    }\n" +
    "}\n"
}

func printWindow(args: Array<String>, start: Int64): Int64 {
    var platform = hostPlatform()
    var requested = "notepad"
    var output = ""
    var projectSet = false
    let appArgs = ArrayList<String>()
    var i = start
    if (i < args.size && isPlatform(args[i])) { platform = normalizePlatform(args[i]); i += 1 }
    while (i < args.size) {
        let current = args[i]
        if (current == "--output" || current == "-o") {
            if (i + 1 >= args.size) { throw CuicError("--output requires a path") }
            output = args[i + 1]
            i += 2
            continue
        }
        if (current == "--") {
            i += 1
            while (i < args.size) { appArgs.add(args[i]); i += 1 }
            break
        }
        if (startsWithText(current, "-")) { throw CuicError("unknown prnt option '${current}'") }
        if (projectSet) { throw CuicError("prnt accepts one project or example") }
        requested = current
        projectSet = true
        i += 1
    }
    let project = resolveProject(requested, "")
    let framework = ensureFrameworkRoot(project)
    let boot = bootstrap(platform, framework)
    if (boot != 0) { return boot }
    if (output.size == 0) { output = joinPath(currentDirectory(), "cuic-${basename(project)}.png") }
    if (!startsWithText(output, "/") && !isWindowsAbsolute(output)) { output = joinPath(currentDirectory(), output) }
    let parent = parentPath(output)
    if (parent.size > 0 && !exists(parent)) { Directory.create(parent, recursive: true) }
    let lowerBmp = endsWithText(output, ".bmp") || endsWithText(output, ".BMP")
    let lowerPng = endsWithText(output, ".png") || endsWithText(output, ".PNG")
    if (!lowerBmp && !lowerPng) { throw CuicError("prnt output must end in .bmp or .png") }
    let snapshot = if (lowerBmp) { output } else { output + ".bmp" }
    removeIfExists(snapshot)
    println("==> capturing ${basename(project)} (${platform})")
    let runArgs = ArrayList<String>()
    for (value in ["run", "--", "--snapshot", snapshot]) { runArgs.add(value) }
    for (value in appArgs) { runArgs.add(value) }
    let code = executeCjpm(project, runArgs.toArray(), framework)
    if (code != 0) { return code }
    if (!exists(snapshot)) { throw CuicError("application exited without producing a snapshot") }
    if (lowerPng) {
        let converted = convertPng(snapshot, output)
        if (converted != 0) { return converted }
        removeIfExists(snapshot)
    }
    println("snapshot: ${output}")
    0
}

func convertPng(source: String, output: String): Int64 {
    if (programAvailable("magick")) { return executeCommand("magick", [source, output], currentDirectory()) }
    if (hostPlatform() == "macos" && programAvailable("sips")) {
        return executeCommand("sips", ["-s", "format", "png", source, "--out", output], currentDirectory())
    }
    if (programAvailable("convert")) { return executeCommand("convert", [source, output], currentDirectory()) }
    throw CuicError("PNG output requires magick, sips, or convert; request .bmp instead")
}

func programAvailable(program: String): Bool {
    try {
        let (code, _, _) = executeWithOutput(program, ["--version"])
        code == 0
    } catch (_: Exception) { false }
}

func windowsCjpmCommand(sdl: String, font: String, args: Array<String>): String {
    let out = StringBuilder()
    out.append("set \"PATH=${sdl};%PATH%\" && set \"CANGHUI_HARMONYOS_SANS=${font}\" && cjpm")
    for (arg in args) { out.append(" \"${arg}\"") }
    out.toString()
}

func runtimeHarmonyFont(framework: String): String {
    let configured = readEnv("CANGHUI_HARMONYOS_SANS")
    if (!configured.isEmpty()) { return configured }
    joinPath(framework, "assets/fonts/HarmonyOS_Sans_SC.ttf")
}

func installProjectFontAssets(project: String, framework: String): Unit {
    let destination = joinPath(project, "assets/fonts")
    Directory.create(destination, recursive: true)
    for (name in ["HarmonyOS_Sans_SC.ttf", "HARMONYOS_SANS_LICENSE.txt", "HARMONYOS_SANS_SOURCE.txt"]) {
        let source = joinPath(framework, "assets/fonts/${name}")
        requireFile(source, "CangHui font asset is missing: ${source}")
        File.writeTo(joinPath(destination, name), File.readFrom(source))
    }
}

func requireFile(path: String, message: String): Unit {
    if (!exists(path)) { throw CuicError(message) }
}

func readEnv(name: String): String {
    match (getVariable(name)) {
        case Some(value) => value
        case None => ""
    }
}

func sanitizePackageName(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        if (r >= r'a' && r <= r'z') { out.append(r.toString()) }
        else if (r >= r'A' && r <= r'Z') { out.append(asciiLower(r).toString()) }
        else if (r >= r'0' && r <= r'9') { out.append(r.toString()) }
        else { out.append("_") }
    }
    let name = out.toString()
    if (name.size == 0) { return "cangui_app" }
    let first = name.toRuneArray()[0]
    if (first >= r'0' && first <= r'9') { return "app_${name}" }
    name
}

func asciiLower(value: Rune): Rune {
    let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toRuneArray()
    let lower = "abcdefghijklmnopqrstuvwxyz".toRuneArray()
    var i: Int64 = 0
    while (i < upper.size) {
        if (upper[i] == value) { return lower[i] }
        i += 1
    }
    value
}

func isWindowsAbsolute(path: String): Bool {
    let runes = path.toRuneArray()
    runes.size >= 3 && runes[1] == r':' && (runes[2] == r'\\' || runes[2] == r'/')
}

func joinPath(root: String, suffix: String): String {
    if (root.size == 0) { return suffix }
    if (suffix.size == 0) { return root }
    trimTrailingSlash(root) + "/" + trimLeadingSlash(suffix)
}

func basename(path: String): String {
    let trimmed = trimTrailingSlash(path)
    let runes = trimmed.toRuneArray()
    var last: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'/' || runes[i] == r'\\') { last = i }
        i += 1
    }
    if (last < 0) { return trimmed }
    substringFrom(trimmed, last + 1)
}

func parentPath(path: String): String {
    let trimmed = trimTrailingSlash(path)
    let runes = trimmed.toRuneArray()
    var last: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'/' || runes[i] == r'\\') { last = i }
        i += 1
    }
    if (last == 0) { return "/" }
    if (last < 0) { return "" }
    substringTo(trimmed, last)
}

func trimTrailingSlash(value: String): String {
    var out = value
    while (out.size > 1 && (endsWithText(out, "/") || endsWithText(out, "\\"))) {
        out = substringTo(out, Int64(out.toRuneArray().size - 1))
    }
    out
}

func trimLeadingSlash(value: String): String {
    var out = value
    while (out.size > 0 && (startsWithText(out, "/") || startsWithText(out, "\\"))) {
        out = substringFrom(out, 1)
    }
    out
}

func trimAscii(value: String): String {
    let runes = value.toRuneArray()
    var start: Int64 = 0
    var end: Int64 = runes.size
    while (start < end && isWhitespace(runes[start])) { start += 1 }
    while (end > start && isWhitespace(runes[end - 1])) { end -= 1 }
    substringRange(value, start, end)
}

func isWhitespace(r: Rune): Bool {
    r == r' ' || r == r'\t' || r == r'\n' || r == r'\r'
}

func containsText(text: String, needle: String): Bool { indexOfText(text, needle) >= 0 }

func startsWithText(text: String, prefix: String): Bool {
    if (prefix.toRuneArray().size > text.toRuneArray().size) { return false }
    substringTo(text, Int64(prefix.toRuneArray().size)) == prefix
}

func endsWithText(text: String, suffix: String): Bool {
    let textSize = Int64(text.toRuneArray().size)
    let suffixSize = Int64(suffix.toRuneArray().size)
    if (suffixSize > textSize) { return false }
    substringRange(text, textSize - suffixSize, textSize) == suffix
}

func indexOfText(text: String, needle: String): Int64 {
    if (needle.size == 0) { return 0 }
    let textRunes = text.toRuneArray()
    let needleRunes = needle.toRuneArray()
    if (needleRunes.size > textRunes.size) { return -1 }
    var i: Int64 = 0
    while (i <= textRunes.size - needleRunes.size) {
        var j: Int64 = 0
        var matched = true
        while (j < needleRunes.size) {
            if (textRunes[i + j] != needleRunes[j]) { matched = false; break }
            j += 1
        }
        if (matched) { return i }
        i += 1
    }
    -1
}

func substringTo(text: String, end: Int64): String { substringRange(text, 0, end) }
func substringFrom(text: String, start: Int64): String { substringRange(text, start, Int64(text.toRuneArray().size)) }

func substringRange(text: String, start: Int64, end: Int64): String {
    let runes = text.toRuneArray()
    let out = StringBuilder()
    var i = start
    while (i < end && i < runes.size) { out.append(runes[i].toString()); i += 1 }
    out.toString()
}
