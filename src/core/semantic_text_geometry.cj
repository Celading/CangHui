package chui.core

import sdl.Rect

/** A selectable grapheme's actual logical rectangle relative to the text origin. */
public struct SemanticTextGlyph {
    public let startByte: Int64
    public let endByte: Int64
    public let line: Int64
    public let frame: Rect
    public let rightToLeft: Bool

    public init(startByte: Int64, endByte: Int64, line: Int64, frame: Rect, rightToLeft: Bool) {
        if (startByte < 0 || endByte < startByte || line < 0 ||
            !semanticGlyphFinite(frame.x) || !semanticGlyphFinite(frame.y) ||
            !semanticGlyphFinite(frame.w) || !semanticGlyphFinite(frame.h) ||
            frame.w < 0.0 || frame.h <= 0.0 || !semanticGlyphFinite(frame.right()) ||
            !semanticGlyphFinite(frame.bottom())) {
            throw IllegalArgumentException("semantic glyph needs ordered bytes and finite logical bounds")
        }
        this.startByte = startByte; this.endByte = endByte; this.line = line
        this.frame = frame; this.rightToLeft = rightToLeft
    }
}

/**
 * Immutable native-layout evidence for an exact value. Private storage prevents
 * later caller mutation from changing committed snapshots. Includes a zero-byte
 * final glyph only for an empty document/final hard line, to retain its bounds.
 */
public class SemanticTextLayout {
    public let value: String
    private let stored: Array<SemanticTextGlyph>
    public prop count: Int64 { get() { stored.size } }

    public init(value: String, glyphs: Array<SemanticTextGlyph>) {
        if (value.size > 1024 * 1024 || value.contains("\u{0}") ||
            value.replace("\r\n", "").contains("\r")) {
            throw IllegalArgumentException("semantic text layout value is unsupported")
        }
        let index = GraphemeIndex(value)
        let emptyFinal = value.isEmpty() || value.endsWith("\n")
        let expected = if (emptyFinal) { index.count + 1 } else { index.count }
        if (glyphs.size != expected) { throw IllegalArgumentException("semantic glyph count differs from editor spans") }
        var row: Int64 = 0
        for (i in 0..index.count) {
            let glyph = glyphs[i]
            if (glyph.startByte != index.boundary(i) || glyph.endByte != index.boundary(i + 1) || glyph.line != row) {
                throw IllegalArgumentException("semantic glyph boundaries differ from editor spans")
            }
            if (value[glyph.startByte..glyph.endByte].endsWith("\n")) { row++ }
        }
        if (row >= 4096) { throw IllegalArgumentException("semantic text layout exceeds line limit") }
        if (emptyFinal) {
            let last = glyphs[glyphs.size - 1]
            if (last.startByte != value.size || last.endByte != value.size || last.line != row || last.frame.w != 0.0) {
                throw IllegalArgumentException("semantic empty final line has invalid bounds")
            }
        }
        this.value = value; this.stored = glyphs.clone()
    }

    public func glyph(index: Int64): SemanticTextGlyph { stored[index] }

    public func same(other: SemanticTextLayout): Bool {
        if (value != other.value || count != other.count) { return false }
        for (i in 0..count) {
            let a = stored[i]; let b = other.glyph(i)
            if (a.startByte != b.startByte || a.endByte != b.endByte || a.line != b.line ||
                a.rightToLeft != b.rightToLeft || a.frame.x != b.frame.x || a.frame.y != b.frame.y ||
                a.frame.w != b.frame.w || a.frame.h != b.frame.h) { return false }
        }
        true
    }
}

/** Per-frame origin over immutable relative glyph data; scrolling does not reshape text. */
public struct SemanticTextGeometry {
    public let layout: SemanticTextLayout
    public let x: Float32
    public let y: Float32
    public init(layout: SemanticTextLayout, x: Float32, y: Float32) {
        if (!semanticGlyphFinite(x) || !semanticGlyphFinite(y)) {
            throw IllegalArgumentException("semantic text origin must be finite")
        }
        this.layout = layout; this.x = x; this.y = y
    }
}

private func semanticGlyphFinite(value: Float32): Bool { value >= -Float32.Max && value <= Float32.Max }

internal func checkedSemanticTextGeometry(role: String, value: String,
    geometry: ?SemanticTextGeometry): ?SemanticTextGeometry {
    if (role == "password") { return None }
    if (let Some(actual) <- geometry) {
        if ((role != "textfield" && role != "textarea") || value != actual.layout.value ||
            (role == "textfield" && value.contains("\n"))) {
            throw IllegalArgumentException("semantic geometry does not match the text control value")
        }
    }
    geometry
}

internal func sameSemanticTextGeometry(a: ?SemanticTextGeometry, b: ?SemanticTextGeometry): Bool {
    if (let Some(left) <- a) {
        if (let Some(right) <- b) { return left.x == right.x && left.y == right.y && left.layout.same(right.layout) }
        return false
    }
    b.isNone()
}
