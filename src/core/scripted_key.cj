package chui.core

import sdl.Key

// Shared by offline probes and the compiler-debug-only desktop script runner.
// Parsing is not a transport; modifier state belongs to one UiContext dispatch.
@When[debug]
protected func parseScriptedKeyInput(input: String): (Key, UInt16) {
    let parts = input.split("+")
    if (parts.isEmpty()) { throw IllegalArgumentException("unsupported key: " + input) }
    var mask = UInt16(0)
    for (i in 0..(parts.size - 1)) {
        let flag: UInt16 = match (scriptedKeyLowercase(parts[i])) {
            case "shift" => UInt16(0x0001)
            case "ctrl" | "control" => UInt16(0x0040)
            case "alt" | "option" => UInt16(0x0100)
            case "cmd" | "command" | "meta" => UInt16(0x0400)
            case "cmdorctrl" => scriptedCommandModifier()
            case _ => throw IllegalArgumentException("unsupported key modifier: " + parts[i])
        }
        if ((mask & flag) != UInt16(0)) {
            throw IllegalArgumentException("duplicate key modifier: " + parts[i])
        }
        mask = mask | flag
    }
    (parseScriptedBaseKey(parts[parts.size - 1]), mask)
}

// Existing release offline probes keep single-key replay, not chord injection.
@When[!debug]
protected func parseScriptedKeyInput(input: String): (Key, UInt16) {
    (parseScriptedBaseKey(input), UInt16(0))
}

@When[os == "macOS"]
private func scriptedCommandModifier(): UInt16 { UInt16(0x0400) }
@When[os != "macOS"]
private func scriptedCommandModifier(): UInt16 { UInt16(0x0040) }

private func scriptedKeyLowercase(input: String): String {
    let bytes = input.toArray()
    for (i in 0..bytes.size) {
        if (bytes[i] >= UInt8(65) && bytes[i] <= UInt8(90)) { bytes[i] += UInt8(32) }
    }
    String.fromUtf8(bytes)
}

private func parseScriptedBaseKey(input: String): Key {
    match (scriptedKeyLowercase(input)) {
        case "escape" => Key.Escape
        case "backspace" => Key.Backspace
        case "enter" | "return" => Key.Enter
        case "tab" => Key.Tab
        case "delete" => Key.Delete
        case "space" => Key.Space
        case "home" => Key.Home
        case "end" => Key.End
        case "left" => Key.Left
        case "right" => Key.Right
        case "up" => Key.Up
        case "down" => Key.Down
        case _ =>
            let bytes = input.toArray()
            if (bytes.size == 1 && bytes[0] >= UInt8(97) && bytes[0] <= UInt8(122)) {
                Key.Letter(bytes[0] - UInt8(32))
            } else if (bytes.size == 1 && bytes[0] >= UInt8(65) && bytes[0] <= UInt8(90)) {
                Key.Letter(bytes[0])
            } else if (bytes.size == 1 && bytes[0] >= UInt8(48) && bytes[0] <= UInt8(57)) {
                Key.Digit(bytes[0])
            } else {
                throw IllegalArgumentException("unsupported key: " + input)
            }
    }
}
