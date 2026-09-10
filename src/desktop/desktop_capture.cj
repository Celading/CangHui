package chui.desktop

import std.convert.*
import std.env.getVariable
import std.fs.File
import chui.core.SemanticRuntime

/**
 * A framework-owned request for one settled renderer capture.
 *
 * Applications may construct this value when they own their host lifecycle. The
 * `cuic prnt` command injects the same request through the process environment
 * before launching the already-built application, so capture does not depend on
 * CJPM forwarding application arguments.
 */
public class DesktopCaptureRequest {
    /** Destination path: .png/.PNG selects native PNG; other paths retain BMP output. */
    public let path: String
    /** Number of rendered frames to wait before capturing. */
    public let settleFrames: UInt64
    /** Optional semanticWindowId; empty selects the first live managed window, never OS focus. */
    public let windowId: String

    public init(path: String, settleFrames!: UInt64 = UInt64(48), windowId!: String = "") {
        if (path.isEmpty()) {
            throw IllegalArgumentException("desktop capture path must not be empty")
        }
        if (!windowId.isEmpty()) { let _ = SemanticRuntime(windowId) }
        this.path = path
        this.settleFrames = if (settleFrames == UInt64(0)) { UInt64(1) } else { settleFrames }
        this.windowId = windowId
    }

    /** Reads the host capture request installed by `cuic prnt`, if present. */
    public static func fromEnvironment(): ?DesktopCaptureRequest {
        let path = environmentValue("CANGHUI_CAPTURE_PATH")
        if (path.isEmpty()) { return None }
        let frames = captureFrameValue(environmentValue("CANGHUI_CAPTURE_FRAMES"))
        Some(DesktopCaptureRequest(path, settleFrames: frames,
            windowId: environmentValue("CANGHUI_CAPTURE_WINDOW")))
    }
}

/** Additive CUIC selector acknowledgment; never enable a transport or input channel. */
internal func recordDesktopCaptureSelection(windowId: String): Unit {
    let path = environmentValue("CANGHUI_CAPTURE_WINDOW_RECEIPT")
    if (!path.isEmpty()) { File.writeTo(path, windowId.toArray()) }
}

private func environmentValue(name: String): String {
    match (getVariable(name)) {
        case Some(value) => value
        case None => ""
    }
}

internal func captureFrameValue(value: String): UInt64 {
    if (value.isEmpty()) { return UInt64(48) }
    try {
        let parsed = UInt64.parse(value)
        if (parsed > UInt64(0)) { parsed } else { UInt64(48) }
    } catch (_: Exception) {
        UInt64(48)
    }
}
