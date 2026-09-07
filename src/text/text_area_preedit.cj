package chui.text

// IME offsets count source Unicode scalars. Display normalization is not an edit:
// keep both selection endpoints in the projected UTF-8 coordinate space, including
// the two source boundaries around LF in a collapsed CRLF pair.
internal struct TextAreaPreeditProjection {
    let text: String
    let selectionStartByte: Int64
    let selectionEndByte: Int64

    init(source: String, selectionStart: Int64, selectionLength: Int64) {
        let start = max(Int64(0), selectionStart)
        let length = max(Int64(0), selectionLength)
        let builder = StringBuilder()
        var offset: Int64 = 0
        var ordinal: Int64 = 0
        var displaySize: Int64 = 0
        var startByte: Int64 = 0
        var endByte: Int64 = 0
        var previousCR = false
        while (offset < source.size) {
            let next = nextTextBoundary(source, offset)
            let byte = source[offset]
            if (byte == UInt8(13) || (byte == UInt8(10) && !previousCR)) {
                builder.append(" ")
                displaySize += 1
            } else if (byte != UInt8(10)) {
                builder.append(source[offset..next])
                displaySize += next - offset
            }
            if (ordinal < start) { startByte = displaySize }
            // Subtraction after the ordered comparison avoids start+length overflow.
            if (ordinal < start || ordinal - start < length) { endByte = displaySize }
            previousCR = byte == UInt8(13)
            offset = next
            ordinal += 1
        }
        this.text = builder.toString()
        this.selectionStartByte = startByte
        this.selectionEndByte = endByte
    }
}
