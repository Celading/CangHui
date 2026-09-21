package canghui_macos_shell

import chui.*
import std.env.getCommandLine

func argument(name: String): String {
    let args = getCommandLine()
    for (i in 0..max(0, args.size - 1)) { if (args[i] == name) { return args[i+1] } }
    ""
}

func content(radius: State<Float32>, visible: State<Bool>, message: State<String>,
    changeRadius: (Float32) -> Unit, toggleStatus: () -> Unit, close: () -> Unit): Unit {
    VStack(spacing: 16.vp) {
        Label("Window & application settings", fontSize: 24.fp).bold()
        Label("Custom corners / native About / menu-bar status item", muted: true).wrap()
        Label("Corner radius: ${radius.value} logical pixels")
        HStack(spacing: 12.vp) {
            Button("Square", {=> changeRadius(0.0)}).key("corners.square")
            Button("18", {=> changeRadius(18.0)}).key("corners.medium")
            Button("36", {=> changeRadius(36.0)}).key("corners.large")
        }.hug()
        Button(if (visible.value) { "Hide menu-bar item" } else { "Show menu-bar item" }, toggleStatus)
            .key("status.toggle")
        Label(message.value).wrap().probe("shell.message", "Label")
        Button("Close window", close).key("window.close")
    }.hug().padding(32.vp)
}

main(): Unit {
    if (runKModeStdioIfRequested()) { return }
    let radius = State<Float32>(18.0)
    let visible = State<Bool>(true)
    let message = State<String>("Open Settings from the application or status menu.")
    let icon = argument("--icon")
    let assets = if (icon.isEmpty()) { Array<AppAsset>() } else {
        [AppAsset(AppAssetRole.ApplicationIcon, icon), AppAsset(AppAssetRole.StatusItemIcon, icon)]
    }
    let status = {show: Bool => AppStatusItem("CangHui Shell", title: if (icon.isEmpty()) { "CH" } else { "" },
        actionIds: ["app.settings", "window.close"], visible: show, templateIcon: false)}
    let manifest = ApplicationManifest(AppIdentity("CangHui Shell", "dev.canghui.shell-example", "1.0.0"),
        assets: assets, actions: [AppAction("app.settings", "Settings…", shortcut: Some("CmdOrCtrl+,")),
            AppAction("window.close", "Close window")], statusItem: Some(status(true)))
    let shell = desktopApplicationShell(manifest)
    let app = DesktopApp(WindowSpec("CangHui Shell", 620, 420, frameless: true,
        transparent: true, cornerRadius: 18.0), applicationShell: Some(shell))
    shell.registerAction(AppAction("app.settings", "Settings…", shortcut: Some("CmdOrCtrl+,")),
        {=> message.value = "Settings action received from the native menu." })
    shell.registerAction(AppAction("window.close", "Close window"), {=> app.requestWindowClose() })
    let change = {value: Float32 =>
        let receipt = app.setWindowCornerRadius(value)
        radius.value = value
        message.value = "Native corners: " + windowShapeApplyStatusName(receipt.status)
    }
    let toggle = {=>
        let result = shell.setStatusItem(status(!visible.value))
        if (result.ok()) { visible.value = !visible.value }
        message.value = result.message
    }
    let output = argument("--write-demo-icon")
    if (!output.isEmpty()) {
        // A small procedural test mark, not a product brand asset.
        try (surface = SdlSurface.create(128,128)) {
            surface.clear(Color.rgb(26,100,180))
            for (y in 32..96) { for (x in 32..96) {
                surface.writePixel(Int32(x), Int32(y), Color.rgb(235,245,255))
            } }
            surface.savePng(output)
        }
    }
    if (argument("--verify-corners") == "true") {
        for (value in [Float32(36.0), Float32(0.0), Float32(18.0)]) {
            let receipt = app.setWindowCornerRadius(value)
            let expected = if (value == 0.0) { WindowShapeApplyStatus.NotRequested } else { WindowShapeApplyStatus.Applied }
            if (receipt.status != expected) { throw Exception("native corner change failed: " + receipt.detail) }
        }
        println("NATIVE_CORNER_OPTIONS_PASS change=true clear=true restore=true")
    }
    if (argument("--verify-shell") == "true") {
        if (!shell.attach().ok()) { throw Exception("native shell attachment failed") }
        for (show in [false, true, false, true]) {
            if (!shell.setStatusItem(status(show)).ok()) { throw Exception("native status update failed") }
        }
        println("NATIVE_SHELL_CALLS_PASS attached=true status-hide-show=true visual-proof=false")
    }
    app.run { content(radius, visible, message, change, toggle, {=> app.requestWindowClose() }) }
    if (argument("--verify-shell") == "true") {
        if (!shell.isClosed() || shell.setStatusItem(status(true)).ok()) {
            throw Exception("closed shell accepted status update")
        }
        println("NATIVE_SHELL_CALLS_PASS detached=true late-update-rejected=true visual-proof=false")
    }
}
