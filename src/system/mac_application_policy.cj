package chui.system

/**
 * Controls whether the process owns a Dock presence. Accessory mode keeps
 * windows and status items available while allowing a tray-only launcher.
 */
@When[os == "macOS"]
public func setMacApplicationDockIconVisible(visible: Bool): SystemShellResult {
    try {
        let native = MacShellApi()
        try {
            let app = native.require(
                native.get(native.cls("NSApplication"), "sharedApplication"),
                "application")
            // NSApplicationActivationPolicyRegular=0, Accessory=1.
            let policy = if (visible) { Int64(0) } else { Int64(1) }
            if (!native.setActivationPolicy(app, policy)) {
                return SystemShellResult(SystemShellResultStatus.Failed,
                    message: "AppKit activation policy was rejected")
            }
            SystemShellResult(SystemShellResultStatus.Applied,
                message: if (visible) {
                    "AppKit activation policy restored to regular"
                } else {
                    "AppKit activation policy set to accessory"
                })
        } finally {
            native.close()
        }
    } catch (error: Exception) {
        SystemShellResult(SystemShellResultStatus.Failed,
            message: "AppKit activation policy failed: ${error.message}")
    }
}

@When[os != "macOS"]
public func setMacApplicationDockIconVisible(_: Bool): SystemShellResult {
    SystemShellResult(SystemShellResultStatus.Unsupported,
        message: "Dock activation policy is macOS-only")
}
