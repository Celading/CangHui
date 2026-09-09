package chui.desktop

import chui.core.GraphemeIndex

// AccessKit characters are editor-selectable UTF-8 spans. Reuse the editor's
// boundary owner; never split a combining sequence to fit the native UInt8 ABI.
// This preview represents one unwrapped line, not multiline/glyph geometry.
internal func accessibilityTextLengths(role: String, text: String): ?Array<UInt8> {
    if (role != "textfield" || text.size > 1024 * 1024 || text.contains("\u{0}") ||
        text.contains("\n") || text.contains("\r")) { return None }
    let index = GraphemeIndex(text)
    let lengths = Array<UInt8>(index.count, {_ => UInt8(0)})
    for (i in 0..index.count) {
        let length = index.boundary(i + 1) - index.boundary(i)
        if (length <= 0 || length > 255) { return None }
        lengths[i] = UInt8(length)
    }
    Some(lengths)
}
