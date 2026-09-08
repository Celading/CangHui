package cuic

import std.collection.ArrayList
import std.fs.exists

class RunOptions {
    let platform: String
    let project: String
    let mode: String
    let appArgs: Array<String>

    init(platform: String, project: String, mode: String, appArgs: Array<String>) {
        this.platform = platform; this.project = project
        this.mode = mode; this.appArgs = appArgs
    }
}

/** Parse all CLI options before project lookup; only arguments after -- reach the app. */
func parseRunOptions(args: Array<String>, start: Int64): RunOptions {
    var index = start
    var platform = hostPlatform()
    if (index < args.size && isPlatform(args[index])) {
        platform = normalizePlatform(args[index]); index += 1
    }
    var requested = ""
    var hasProject = false
    var mode = "release"
    var hasMode = false
    let appArgs = ArrayList<String>()
    while (index < args.size) {
        let value = args[index]
        if (value == "--") {
            index += 1
            while (index < args.size) { appArgs.add(args[index]); index += 1 }
            break
        }
        if (value == "--mode") {
            if (hasMode || index + 1 >= args.size) {
                throw CuicError("run requires one --mode release|debug value")
            }
            mode = args[index + 1]
            if (mode != "release" && mode != "debug") {
                throw CuicError("run mode must be release or debug")
            }
            hasMode = true; index += 2
        } else {
            if (value.startsWith("-") || hasProject) {
                throw CuicError("unexpected run argument: ${value}; use -- before application arguments")
            }
            requested = value; hasProject = true; index += 1
        }
    }
    if (!hasProject) {
        requested = implicitProjectRequest("notepad", exists(joinPath(currentDirectory(), "cjpm.toml")))
    }
    RunOptions(platform, resolveProject(requested, ""), mode, appArgs.toArray())
}

func runDesktopApplication(options: RunOptions): Int64 {
    if (options.platform != hostPlatform()) {
        throw CuicError("run requires a ${options.platform} host; cross-device launch is not implemented")
    }
    let project = options.project
    let framework = ensureFrameworkRoot(project)
    let context = ExecutionContext(project, framework)
    let diffCode = runKModeDiff(project, quiet: true)
    if (diffCode != 0) { return diffCode }
    let probeCode = runProbeDiff(project, quiet: true)
    if (probeCode != 0) { return probeCode }
    let boot = bootstrap(options.platform, framework, stagingRoot: context.stagingRoot)
    if (boot != 0) { return boot }
    let lease = context.acquireLease()
    try {
        println("==> building ${basename(project)} (${options.platform}, ${options.mode})")
        let buildCode = executeCjpm(context, cjpmProfileArguments("build", options.mode))
        if (buildCode != 0) { return buildCode }
        let executable = desktopCaptureExecutable(context.targetDir, options.mode, {path => exists(path)})
        println("==> running ${basename(project)} (${options.platform}, ${options.mode})")
        // Inherit stdio and the process exit status; never buffer an interactive app until exit.
        return executeApplication(project, executable, options.appArgs, framework, "", UInt64(0),
            nativeDirectory: context.sdlDirectory())
    } finally {
        context.releaseLease(lease)
    }
}
