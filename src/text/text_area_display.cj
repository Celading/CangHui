package chui.text

import std.collection.ArrayList

// One transient splice, not a second editable document. Every exposed position
// is a UTF8 byte offset; preedit source scalar offsets are lowered by the existing
// CRLF projection. Never write these display offsets back to the durable state.
internal class TextAreaDisplayProjection {
    let source: String
    let sourceRevision: UInt64
    let composition: TextCompositionSnapshot
    let active: Bool
    let text: String
    let preeditStart: Int64
    let preeditEnd: Int64
    let selectionStart: Int64
    let selectionEnd: Int64

    init(source: String, revision: UInt64, composition: TextCompositionSnapshot) {
        this.source = source; this.sourceRevision = revision; this.composition = composition
        let a = composition.replacementStartByte
        let b = composition.replacementEndByte
        let valid = composition.active && !composition.preedit.isEmpty() &&
            composition.documentRevision == revision && a >= 0 && b >= a && b <= source.size &&
            normalizedTextCursor(source, a) == a && normalizedTextCursor(source, b) == b
        this.active = valid
        if (valid) {
            let preedit = TextAreaPreeditProjection(composition.preedit,
                composition.selectionStart, composition.selectionLength)
            this.text = source[0..a] + preedit.text + source[b..source.size]
            this.preeditStart = a; this.preeditEnd = a + preedit.text.size
            this.selectionStart = a + preedit.selectionStartByte
            this.selectionEnd = a + preedit.selectionEndByte
        } else {
            this.text = source
            this.preeditStart = 0; this.preeditEnd = 0
            this.selectionStart = 0; this.selectionEnd = 0
        }
    }

    func cursor(documentCursor: Int64): Int64 {
        if (active) { selectionEnd } else { normalizedTextCursor(source, documentCursor) }
    }

    // Preedit interiors collapse to the replacement start when cancelling by
    // pointer; its right boundary and the suffix map to the replacement end.
    func documentOffset(displayOffset: Int64): Int64 {
        let at = normalizedTextCursor(text, displayOffset)
        if (!active || at < preeditStart) { return at }
        if (at < preeditEnd) { return preeditStart }
        composition.replacementEndByte + (at - preeditEnd)
    }

    func decorations(values: Array<TextAreaDecoration>): Array<TextAreaDecoration> {
        if (!active) { return values }
        let out = ArrayList<TextAreaDecoration>()
        for (value in values) {
            if (!validTextAreaDecoration(source, value)) { continue }
            let leftEnd = min(value.endByte, preeditStart)
            if (value.startByte < leftEnd) {
                out.add(TextAreaDecoration(value.startByte, leftEnd, value.style))
            }
            let rightStart = max(value.startByte, composition.replacementEndByte)
            if (rightStart < value.endByte) {
                out.add(TextAreaDecoration(preeditEnd + (rightStart - composition.replacementEndByte),
                    preeditEnd + (value.endByte - composition.replacementEndByte), value.style))
            }
        }
        out.toArray()
    }

    func matches(value: String, revision: UInt64, next: TextCompositionSnapshot): Bool {
        source == value && sourceRevision == revision && composition.active == next.active &&
            composition.preedit == next.preedit && composition.selectionStart == next.selectionStart &&
            composition.selectionLength == next.selectionLength &&
            composition.replacementStartByte == next.replacementStartByte &&
            composition.replacementEndByte == next.replacementEndByte &&
            composition.documentRevision == next.documentRevision && composition.generation == next.generation
    }
}

internal class TextAreaDisplayCache {
    private var value: ?TextAreaDisplayProjection = None
    private var serial: UInt64 = 0
    prop revision: UInt64 { get() { serial } }

    func resolve(text: String, revision: UInt64, composition: TextCompositionSnapshot): TextAreaDisplayProjection {
        if (let Some(previous) <- value) {
            if (previous.matches(text, revision, composition)) { return previous }
        }
        let next = TextAreaDisplayProjection(text, revision, composition)
        value = Some(next)
        serial += UInt64(1)
        next
    }
}
