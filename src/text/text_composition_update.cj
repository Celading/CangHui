package chui.text

import sdl.TextCompositionEvent

private func utf8CharacterCount(value: String): Int64 {
    var count: Int64 = 0
    var cursor: Int64 = 0
    while (cursor < value.size) {
        cursor = nextTextBoundary(value, cursor)
        count += 1
    }
    count
}

internal func validTextCompositionRange(source: String, start: Int64, end: Int64): Bool {
    start >= 0 && end >= start && end <= source.size &&
        normalizedTextCursor(source, start) == start && normalizedTextCursor(source, end) == end
}

/** Shared transient transaction for single/multi-line editors. No document mutation. */
internal func updatedTextComposition(source: String, revision: UInt64,
    previous: TextCompositionSnapshot, edit: TextEditState, event: TextCompositionEvent,
    captureCurrentRange: Bool): TextCompositionSnapshot {
    var start = edit.selectionStart()
    var end = edit.selectionEnd()
    if (!captureCurrentRange && previous.active) {
        start = previous.replacementStartByte
        end = previous.replacementEndByte
    }
    if (validTextCompositionRange(source, event.replacementStartByte, event.replacementEndByte)) {
        start = event.replacementStartByte
        end = event.replacementEndByte
    }
    let count = utf8CharacterCount(event.text)
    let selectionStart = if (event.selectionStart < 0) { count } else { min(event.selectionStart, count) }
    let selectionLength = if (event.selectionLength < 0) { Int64(0) }
        else { min(event.selectionLength, count - selectionStart) }
    TextCompositionSnapshot(active: true, preedit: event.text, selectionStart: selectionStart,
        selectionLength: selectionLength, replacementStartByte: start, replacementEndByte: end,
        documentRevision: revision, generation: previous.generation + UInt64(1))
}
