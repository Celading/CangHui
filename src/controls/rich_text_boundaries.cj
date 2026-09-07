package chui.controls

import std.collection.ArrayList
import sdl.FontStyle
import chui.core.GraphemeIndex

// A style boundary may cut a grapheme, but is never by itself permission to wrap.
// Keep rendering in original spans; this view only governs line-break decisions.
class RichSpanBoundaries {
    let text: String
    let offsets: Array<Int64>
    let joinedStart: Bool
    let joinedEnd: Bool
    let continuationWidth: Float32

    init(text: String, offsets: Array<Int64>, joinedStart: Bool, joinedEnd: Bool, continuationWidth: Float32) {
        this.text = text
        this.offsets = offsets
        this.joinedStart = joinedStart
        this.joinedEnd = joinedEnd
        this.continuationWidth = continuationWidth
    }

    prop count: Int64 { get() { offsets.size - 1 } }
    func slice(start: Int64, end: Int64): String { text[offsets[start]..offsets[end]] }
    func space(at: Int64): Bool {
        // A styled space prefix plus a later combining mark is not a discardable whole space.
        !(at == 0 && joinedStart) && !(at + 1 == count && joinedEnd) && slice(at, at + 1) == " "
    }
    func word(at: Int64): Bool {
        let part = slice(at, at + 1)
        part.size == 1 && part[0] > 32 && part[0] <= 126
    }
    func wordEnd(start: Int64): Int64 {
        var end = start
        while (end < count && word(end)) { end += 1 }
        end
    }

    func width(start: Int64, end: Int64, measure: (String) -> Float32): Float32 {
        measure(slice(start, end)) + if (end == count) { continuationWidth } else { 0.0 }
    }

    // Bounded prefix probes preserve long-paragraph behavior without a suffix scan on each line.
    func fitting(start: Int64, available: Float32, measure: (String) -> Float32): Int64 {
        let remaining = count - start
        if (remaining <= 0 || available <= 0.0) { return 0 }
        var high = remaining
        var low: Int64 = 0
        if (remaining > 512) {
            high = min(32, remaining)
            while (high < remaining && width(start, start + high, measure) <= available) {
                low = high
                high = min(high * 4, remaining)
            }
        } else if (width(start, count, measure) <= available) { return remaining }
        while (low < high) {
            let mid = low + (high - low + 1) / 2
            if (width(start, start + mid, measure) <= available) { low = mid }
            else { high = mid - 1 }
        }
        low
    }
}

// One global segmentation gives RI parity, Indic and emoji context across arbitrary style spans.
// NUL is a control boundary on both sides of each icon; it is never passed to the renderer.
func richSpanBoundaries(spans: Array<RichSpan>, sizes: Array<Float32>, styles: Array<FontStyle>,
    fonts: Array<?String>, measure: (String, Float32, FontStyle, ?String) -> Float32): Array<RichSpanBoundaries> {
    let joined = StringBuilder()
    let starts = Array<Int64>(spans.size + 1, {_ => 0})
    let texts = Array<String>(spans.size, {_ => ""})
    for (i in 0..spans.size) {
        match (spans[i].kind) {
            case RichSpanKind.SpanText(text) =>
                texts[i] = text
                joined.append(text)
                starts[i + 1] = starts[i] + text.size
            case RichSpanKind.SpanIcon(_) =>
                joined.append("\u{0}")
                starts[i + 1] = starts[i] + 1
        }
    }
    let index = GraphemeIndex(joined.toString())
    let tails = Array<Float32>(spans.size, {_ => 0.0})
    // Suffix advances computed once, including empty style spans inside a joined cluster.
    var i = spans.size - 2
    while (i >= 0) {
        let end = starts[i + 1]
        let clusterEnd = index.ceil(end)
        if (clusterEnd > end) {
            let nextEnd = min(clusterEnd, starts[i + 2])
            let prefix = texts[i + 1][0..(nextEnd - end)]
            tails[i] = if (prefix.isEmpty()) { 0.0 }
                else { measure(prefix, sizes[i + 1], styles[i + 1], fonts[i + 1]) }
            if (starts[i + 2] < clusterEnd) { tails[i] += tails[i + 1] }
        }
        i -= 1
    }
    Array<RichSpanBoundaries>(spans.size, {si =>
        let start = starts[si]
        let end = start + texts[si].size
        let bounds = ArrayList<Int64>()
        bounds.add(0)
        var ordinal = index.ordinalFloor(start) + 1
        while (index.boundary(ordinal) < end) {
            bounds.add(index.boundary(ordinal) - start)
            ordinal += 1
        }
        if (end > start) { bounds.add(end - start) }
        RichSpanBoundaries(texts[si], bounds.toArray(), index.floor(start) != start,
            index.ceil(end) != end, tails[si])
    })
}
