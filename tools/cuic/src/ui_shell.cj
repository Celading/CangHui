package cuic

import std.collection.HashMap
import std.fs.{File, Path, exists, removeIfExists}
import std.process.{ProcessRedirect, launch}

class UiShellSelection {
    let project: String
    let script: String
    let windowId: String

    init(project: String, script: String, windowId!: String = "") {
        this.project = project
        this.script = script
        this.windowId = windowId
    }
}

@When[debug]
func shellCommand(args: Array<String>, start: Int64): Int64 {
    requireDebugChannelBuild("cuic shell")
    let selection = parseUiShellSelection(args, start)
    runUiShell(selection.project, selection.script, windowId: selection.windowId)
}

@When[!debug]
func shellCommand(_: Array<String>, _: Int64): Int64 {
    requireDebugChannelBuild("cuic shell")
    1
}

func parseUiShellSelection(args: Array<String>, start: Int64): UiShellSelection {
    if (start >= args.size) {
        throw CuicError("shell requires click, touch, down, move, up, cancel, focus, key, text, snapshot, or run")
    }
    let action = args[start]
    if (action == "run") {
        return parseUiShellRun(args, start + 1)
    }
    if (action == "snapshot" || action == "cancel") {
        if (start + 2 < args.size) { throw CuicError("shell ${action} accepts one project") }
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        return UiShellSelection(resolveProject(requested, ""), action)
    }
    if (action == "click" || action == "touch" || action == "down" || action == "press" ||
        action == "move" || action == "up" || action == "release") {
        let remaining = args.size - (start + 1)
        if (remaining != 2 && remaining != 3) {
            throw CuicError("shell ${action} requires [project] <x> <y>")
        }
        let project = if (remaining == 3) { resolveProject(args[start + 1], "") } else { resolveProject("", "") }
        let offset = if (remaining == 3) { start + 2 } else { start + 1 }
        let normalized = if (action == "touch") { "click" } else { action }
        return UiShellSelection(project, normalized + " " + args[offset] + " " + args[offset + 1])
    }
    if (action == "focus" || action == "key" || action == "text") {
        let remaining = args.size - (start + 1)
        if (remaining != 1 && remaining != 2) {
            throw CuicError("shell ${action} requires [project] <value>")
        }
        let project = if (remaining == 2) { resolveProject(args[start + 1], "") } else { resolveProject("", "") }
        let value = args[args.size - 1]
        return UiShellSelection(project, action + " " + value)
    }
    throw CuicError("unknown shell action '${action}'")
}

func parseUiShellRun(args: Array<String>, start: Int64): UiShellSelection {
    var requested = ""
    var script = ""
    var windowId = ""
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--window") {
            if (!windowId.isEmpty() || i + 1 >= args.size || args[i + 1].isEmpty() ||
                startsWithText(args[i + 1], "-")) {
                throw CuicError("shell --window requires one semantic window id")
            }
            windowId = args[i + 1]
            i += 2
            continue
        }
        if (value == "--events" || value == "--script") {
            if (i + 1 >= args.size) { throw CuicError(value + " requires a value") }
            if (!script.isEmpty()) { throw CuicError("shell run accepts one event source") }
            script = if (value == "--script") {
                String.fromUtf8(File.readFrom(args[i + 1]))
            } else {
                args[i + 1]
            }
            i += 2
            continue
        }
        if (startsWithText(value, "-")) { throw CuicError("unknown shell run option '${value}'") }
        if (!requested.isEmpty()) { throw CuicError("shell run accepts one project") }
        requested = value
        i += 1
    }
    if (script.trimAscii().isEmpty()) {
        throw CuicError("shell run requires --events <script> or --script <file>")
    }
    UiShellSelection(resolveProject(requested, ""), script, windowId: windowId)
}

@When[debug]
func runUiShell(project: String, script: String, windowId!: String = ""): Int64 {
    let framework = ensureFrameworkRoot(project)
    requireUiShellWindowSource(framework, windowId)
    let context = ExecutionContext(project, framework)
    let boot = bootstrap(hostPlatform(), framework, stagingRoot: context.stagingRoot)
    if (boot != 0) { return boot }
    let lease = context.acquireLease()
    let receipt = if (windowId.isEmpty()) { "" } else { joinPath(context.targetDir, "cuic-ui-window-selection.txt") }
    try {
        if (!receipt.isEmpty()) { removeIfExists(receipt) }
        println("==> building ${basename(project)} (debug UI shell)")
        let buildCode = executeCjpm(context, ["build", "-g"])
        if (buildCode != 0) { return buildCode }
        let executable = debugUiExecutable(context.targetDir)
        let environment = uiShellEnvironment(context, script, windowId: windowId, selectionReceipt: receipt)
        let process = launch(
            executable,
            [],
            workingDirectory: Path(project),
            environment: workingDirectoryEnvironment(project, environment),
            stdIn: ProcessRedirect.Discard,
            stdOut: ProcessRedirect.Inherit,
            stdErr: ProcessRedirect.Inherit
        )
        let code = process.wait()
        if (code == 0 && !windowId.isEmpty()) {
            let actual = if (exists(receipt)) { Some(String.fromUtf8(File.readFrom(receipt))) } else { None<String> }
            verifyUiShellWindowSelection(windowId, actual)
        }
        code
    } finally {
        try { if (!receipt.isEmpty()) { removeIfExists(receipt) } }
        finally { context.releaseLease(lease) }
    }
}

@When[!debug]
func runUiShell(_: String, _: String, windowId!: String = ""): Int64 {
    requireDebugChannelBuild("cuic shell")
    1
}

func debugUiExecutable(targetDir: String): String {
    for (candidate in builtExecutableCandidates(targetDir, "debug")) {
        if (exists(candidate)) { return candidate }
    }
    throw CuicError("debug build completed but no executable was found")
}

@When[debug]
func uiShellEnvironment(context: ExecutionContext, script: String,
    windowId!: String = "", selectionReceipt!: String = ""): HashMap<String, String> {
    requireDebugChannelBuild("cuic shell")
    let environment = applicationEnvironment(context.framework, "", UInt64(0),
        nativeDirectory: context.sdlDirectory(), project: context.project)
    environment.add("CANGHUI_DEBUG_UI_SCRIPT_HEX", encodeCuicKModeText(script))
    environment.add("CANGHUI_DEBUG_UI_WINDOW", windowId)
    environment.add("CANGHUI_DEBUG_UI_WINDOW_RECEIPT", selectionReceipt)
    environment
}

@When[!debug]
func uiShellEnvironment(_: ExecutionContext, _: String,
    windowId!: String = "", selectionReceipt!: String = ""): HashMap<String, String> {
    requireDebugChannelBuild("cuic shell")
    HashMap<String, String>()
}

func requireUiShellWindowSource(framework: String, windowId: String): Unit {
    if (windowId.isEmpty()) { return }
    let source = joinPath(framework, "src/desktop/debug_ui_window.cj")
    if (!exists(source) || !String.fromUtf8(File.readFrom(source)).contains("canghui.debug-ui-window.v1")) {
        throw CuicError("shell --window requires the matching window-aware CangHui runtime; update the paired source SDK")
    }
}

func verifyUiShellWindowSelection(expected: String, actual: ?String): Unit {
    if (expected.isEmpty()) { return }
    match (actual) {
        case Some(value) where value == expected => ()
        case _ => throw CuicError("application did not acknowledge requested debug UI window '${expected}'")
    }
}
