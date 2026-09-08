package chui.system

/** AppKit key equivalents. Unsupported chords fail before native projection. */
internal func macMenuShortcut(shortcut: ?String): (String, Int64) {
    let value = match (shortcut) { case Some(text) => text; case None => return ("", 0) }
    let parts = value.split("+")
    if (parts.isEmpty()) { throw IllegalArgumentException("menu shortcut is empty") }
    var mask: Int64 = 0
    for (i in 0..(parts.size - 1)) {
        let flag: Int64 = match (parts[i]) {
            case "Cmd" | "Command" | "Meta" | "CmdOrCtrl" => 1048576
            case "Ctrl" | "Control" => 262144
            case "Alt" | "Option" => 524288
            case "Shift" => 131072
            case _ => throw IllegalArgumentException("unsupported menu shortcut modifier: " + parts[i])
        }
        if ((mask & flag) != 0) { throw IllegalArgumentException("duplicate menu shortcut modifier") }
        mask = mask | flag
    }
    var key = parts[parts.size - 1]
    match (key) {
        case "Enter" | "Return" => key = "\r"
        case "Tab" => key = "\t"
        case "Escape" => key = "\u{1b}"
        case "Backspace" => key = "\u{8}"
        case "Delete" => key = "\u{7f}"
        case "Space" => key = " "
        case "Plus" => key = "+"
        case _ =>
            let runes = key.toRuneArray()
            if (runes.size != 1 || runes[0] < r' ') { throw IllegalArgumentException("unsupported menu shortcut key: " + key) }
            if (runes[0] >= r'A' && runes[0] <= r'Z') {
                key = Rune(UInt32(runes[0]) + UInt32(32)).toString()
            }
    }
    (key, mask)
}
