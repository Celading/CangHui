package chui.desktop

@When[debug]
import std.env.getVariable
@When[debug]
import std.fs.File
@When[debug]
import chui.core.SemanticRuntime

// CUIC checks this source capability before passing an explicit window selector.
@When[debug]
internal let DEBUG_UI_WINDOW_PROTOCOL = "canghui.debug-ui-window.v1"

@When[debug]
internal func debugUiRequestedWindow(): String {
    validateDebugUiWindow(getVariable("CANGHUI_DEBUG_UI_WINDOW") ?? "")
}

@When[debug]
internal func validateDebugUiWindow(value: String): String {
    if (!value.isEmpty()) { let _ = SemanticRuntime(value) }
    value
}

@When[debug]
internal func recordDebugUiWindow(windowId: String): Unit {
    let receipt = getVariable("CANGHUI_DEBUG_UI_WINDOW_RECEIPT") ?? ""
    if (!receipt.isEmpty()) { File.writeTo(receipt, windowId.toArray()) }
}
