package chui.desktop

import chui.core.{GraphemeIndex, SemanticNode}

// AccessKit characters are editor-selectable UTF-8 spans. Reuse the editor's
// boundary owner; never split a combining sequence to fit the native UInt8 ABI.
// Stock TextArea is NoWrap: hard LF lines, never inferred soft-wrap/glyph geometry.
internal func accessibilityTextLengths(role: String, text: String): ?Array<UInt8> {
    if ((role != "textfield" && role != "textarea") || text.size > 1024 * 1024 || text.contains("\u{0}")) { return None }
    if (role == "textfield" && (text.contains("\n") || text.contains("\r"))) { return None }
    if (role == "textarea" && text.replace("\r\n", "").contains("\r")) { return None }
    let index = GraphemeIndex(text)
    let lengths = Array<UInt8>(index.count, {_ => UInt8(0)})
    for (i in 0..index.count) {
        let length = index.boundary(i + 1) - index.boundary(i)
        if (length <= 0 || length > 255) { return None }
        lengths[i] = UInt8(length)
    }
    Some(lengths)
}

// Translate only exact editor boundaries. The compatibility min/max fields do
// not reveal direction by themselves; a missing/invalid focus stays unknown.
internal func accessibilityTextSelection(node: SemanticNode, lengths: Array<UInt8>): ?(Int64, Int64) {
    if ((node.role != "textfield" && node.role != "textarea") || node.selectionStart.isNone() ||
        node.selectionEnd.isNone() || node.selectionFocus.isNone()) { return None }
    let start = node.selectionStart.getOrThrow()
    let end = node.selectionEnd.getOrThrow()
    let focus = node.selectionFocus.getOrThrow()
    if (start < 0 || end < start || (focus != start && focus != end)) { return None }
    var startOrdinal: Int64 = -1
    var endOrdinal: Int64 = -1
    var offset: Int64 = 0
    for (i in 0..(lengths.size + 1)) {
        if (offset == start) { startOrdinal = i }
        if (offset == end) { endOrdinal = i }
        if (i < lengths.size) { offset += Int64(lengths[i]) }
    }
    if (startOrdinal < 0 || endOrdinal < 0) { return None }
    if (focus == start) { Some((endOrdinal, startOrdinal)) }
    else { Some((startOrdinal, endOrdinal)) }
}
