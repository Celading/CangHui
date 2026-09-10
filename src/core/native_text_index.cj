package chui.core

/**
 * Optional encoding bridge for native UTF-16 text APIs; editing stays UTF-8.
 * Reuses the Unicode grapheme owner instead of segmenting native text separately.
 * Construct only for a retained native layout, not each scalar/caret lookup.
 */
protected class NativeTextIndex {
    public let graphemes: GraphemeIndex
    private let utf16Offsets: Array<Int64>

    public init(text: String) {
        this.graphemes = GraphemeIndex(text)
        let offsets = Array<Int64>(graphemes.count + 1, {_ => 0})
        var ordinal: Int64 = 1
        var bytePosition: Int64 = 0
        var nativePosition: Int64 = 0
        for (rune in text.toRuneArray()) {
            let point = UInt32(rune)
            bytePosition += if (point <= UInt32(0x7F)) { 1 } else if (point <= UInt32(0x7FF)) { 2 }
                else if (point <= UInt32(0xFFFF)) { 3 } else { 4 }
            nativePosition += if (point <= UInt32(0xFFFF)) { 1 } else { 2 }
            if (ordinal <= graphemes.count && bytePosition == graphemes.boundary(ordinal)) {
                offsets[ordinal] = nativePosition
                ordinal++
            }
        }
        this.utf16Offsets = offsets
    }

    // An interior surrogate, combining sequence or ZWJ is never an editor position.
    // Forward means logical rounding, NOT bidi affinity. The native provider must
    // preserve its primary/secondary visual positions independently of this mapping.
    public func byteOffsetForUtf16(position: Int64, forward!: Bool = false): Int64 {
        var low: Int64 = 0
        var high = graphemes.count
        while (low < high) {
            let mid = low + (high - low + 1) / 2
            if (utf16Offsets[mid] <= position) { low = mid } else { high = mid - 1 }
        }
        let selected = if (forward && utf16Offsets[low] < position) {
            min(graphemes.count, low + 1)
        } else { low }
        graphemes.boundary(selected)
    }

    public func utf16OffsetForByte(position: Int64, forward!: Bool = false): Int64 {
        let ordinal = graphemes.ordinalFloor(position)
        let selected = if (forward && graphemes.boundary(ordinal) < position) {
            min(graphemes.count, ordinal + 1)
        } else { ordinal }
        utf16Offsets[selected]
    }
}
