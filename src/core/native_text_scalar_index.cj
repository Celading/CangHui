package chui.core

/**
 * Exact UTF-8 / UTF-16 scalar boundaries for native paint and interop ranges.
 * Unlike NativeTextIndex, this does NOT round to editor graphemes. A color range
 * may start between a base character and its combining mark or inside a ZWJ
 * sequence. Byte interiors, surrogate interiors and out-of-range values fail.
 *
 * Construct once per retained source line when scalar ranges are needed. This
 * optional immutable index is not allocated by ordinary grapheme/caret queries.
 * It performs encoding conversion, not another grapheme segmentation algorithm.
 */
protected class NativeTextScalarIndex {
    private let byteOffsets: Array<Int64>
    private let utf16Offsets: Array<Int64>

    public init(text: String) {
        let runes = text.toRuneArray()
        let bytes = Array<Int64>(runes.size + 1, {_ => 0})
        let native = Array<Int64>(runes.size + 1, {_ => 0})
        for (i in 0..runes.size) {
            let point = UInt32(runes[i])
            bytes[i + 1] = bytes[i] + if (point <= UInt32(0x7F)) { 1 }
                else if (point <= UInt32(0x7FF)) { 2 }
                else if (point <= UInt32(0xFFFF)) { 3 } else { 4 }
            native[i + 1] = native[i] + if (point <= UInt32(0xFFFF)) { 1 } else { 2 }
        }
        this.byteOffsets = bytes
        this.utf16Offsets = native
    }

    /** Empty text still has the exact boundary 0. No clamping or rounding. */
    public func utf16OffsetForByte(position: Int64): ?Int64 {
        exactNativeScalarOffset(byteOffsets, utf16Offsets, position)
    }

    /** A UTF-16 surrogate interior is never an exact scalar boundary. */
    public func byteOffsetForUtf16(position: Int64): ?Int64 {
        exactNativeScalarOffset(utf16Offsets, byteOffsets, position)
    }
}

// Both arrays include zero and the terminal boundary and are strictly ordered.
// Binary lookup keeps many decoration queries linearithmic even when a single
// grapheme contains thousands of combining marks.
private func exactNativeScalarOffset(source: Array<Int64>, target: Array<Int64>,
    position: Int64): ?Int64 {
    if (position < 0 || position > source[source.size - 1]) { return None }
    var low: Int64 = 0
    var high = source.size - 1
    while (low < high) {
        let mid = low + (high - low) / 2
        if (source[mid] < position) { low = mid + 1 } else { high = mid }
    }
    if (source[low] == position) { Some(target[low]) } else { None }
}
