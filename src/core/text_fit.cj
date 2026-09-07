package chui.core

import std.collection.ArrayList
import sdl.FontStyle

private let TEXT_ELLIPSIS = "…"

// The gallop bracket start (covers most lines at UI widths in one probe) and the remainder length
// up to which a single whole-run probe is still the cheapest opening move.
private let WRAP_GALLOP_SEED: Int64 = 32
private let WRAP_GALLOP_THRESHOLD: Int64 = 512

/*
 * Text fitting shared by single-line ellipsis and multi-line wrapping. Prefix widths are
 * found with binary search over extended-grapheme boundaries, so the cost per line is O(log n) renderer
 * measurements instead of one per character.
 */

/** Returns `text` unchanged when it fits, otherwise the widest `prefix + …` that fits. */
protected func ellipsize(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    style!: FontStyle = FontStyle.regular,
    font!: ?String = None
): String {
    if (ctx.renderer.textWidth(text, pointSize: ps, style: style, font: font) <= maxWidth) {
        return text
    }
    if (ctx.renderer.textWidth(TEXT_ELLIPSIS, pointSize: ps, style: style, font: font) > maxWidth) {
        return ""
    }
    let index = GraphemeIndex(text)
    let measure = {prefix: String =>
        ctx.renderer.textWidth(prefix + TEXT_ELLIPSIS, pointSize: ps, style: style, font: font)}
    let take = maxGraphemesFitting(text, index, 0, maxWidth, measure)
    text[0..index.boundary(take)] + TEXT_ELLIPSIS
}

/**
 * Breaks `text` into at most `maxLines` display lines that fit `maxWidth`, preferring
 * space boundaries and falling back to whole extended graphemes. The last
 * line is ellipsized when text remains.
 */
protected func wrapText(
    ctx: UiContext,
    text: String,
    maxWidth: Float32,
    ps: Float32,
    maxLines: Int64,
    style!: FontStyle = FontStyle.regular,
    font!: ?String = None
): Array<String> {
    let index = GraphemeIndex(text)
    let measure = {s: String => ctx.renderer.textWidth(s, pointSize: ps, style: style, font: font)}
    let lines = ArrayList<String>()
    var start: Int64 = 0
    while (start < index.count && lines.size < maxLines) {
        if (lines.size == maxLines - 1) {
            lines.add(ellipsize(ctx, text[index.boundary(start)..text.size], maxWidth, ps, style: style, font: font))
            return lines.toArray()
        }
        // An oversized cluster stays whole; fitting must still make progress.
        var take = max(1, maxGraphemesFitting(text, index, start, maxWidth, measure))
        if (start + take < index.count && !graphemeIsSpace(text, index, start + take)) {
            var back = take - 1
            while (back > 0) {
                if (graphemeIsSpace(text, index, start + back)) {
                    take = back + 1
                    break
                }
                back -= 1
            }
        }
        var lineEnd = start + take
        while (lineEnd > start && graphemeIsSpace(text, index, lineEnd - 1)) { lineEnd -= 1 }
        lines.add(text[index.boundary(start)..index.boundary(lineEnd)])
        start += take
        while (start < index.count && graphemeIsSpace(text, index, start)) { start += 1 }
    }
    if (lines.isEmpty()) { lines.add("") }
    lines.toArray()
}

private func graphemeIsSpace(text: String, index: GraphemeIndex, ordinal: Int64): Bool {
    let start = index.boundary(ordinal)
    index.boundary(ordinal + 1) == start + 1 && text[start] == UInt8(32)
}

// One precomputed index per paragraph: never re-segment the full text per display line.
private func maxGraphemesFitting(text: String, index: GraphemeIndex, start: Int64,
    width: Float32, measure: (String) -> Float32): Int64 {
    let remaining = index.count - start
    if (remaining <= 0 || width <= 0.0) { return 0 }
    let begin = index.boundary(start)
    var high = remaining
    var low: Int64 = 0
    if (remaining > WRAP_GALLOP_THRESHOLD) {
        high = min(WRAP_GALLOP_SEED, remaining)
        while (high < remaining && measure(text[begin..index.boundary(start + high)]) <= width) {
            low = high
            high = min(high * 4, remaining)
        }
    } else if (measure(text[begin..index.boundary(start + remaining)]) <= width) {
        return remaining
    }
    while (low < high) {
        let mid = low + (high - low + 1) / 2
        if (measure(text[begin..index.boundary(start + mid)]) <= width) { low = mid }
        else { high = mid - 1 }
    }
    low
}

/*
 * The largest rune count k in [1, remaining] with measure(runes[start..start+k]) <= maxW; 0 if even
 * one rune does not fit (or there is no width / no runes left). Retained for rune-based consumers
 * such as probe summaries. Label and RichText fitting instead use
 * extended-grapheme boundaries. Do not describe this helper as grapheme-safe.
 */
protected func maxRunesFitting(runes: Array<Rune>, start: Int64, maxW: Float32, measure: (String) -> Float32): Int64 {
    let n = runes.size - start
    if (n <= 0 || maxW <= 0.0) {
        return 0
    }
    // Short remainders keep the single whole-run probe: one measurement settles the common case
    // (a label that simply fits). Long remainders must not — probing the full text again on every
    // line is what made wrapping a 20000-rune document quadratic in string builds — so they gallop
    // for a bracket first, keeping every measured prefix within a few line-lengths.
    if (n <= WRAP_GALLOP_THRESHOLD) {
        if (measure(runeSlice(runes, start, start + n)) <= maxW) {
            return n
        }
        return largestFitting(runes, start, 0, n - 1, measure, maxW)
    }
    var fits = 0
    var probe = WRAP_GALLOP_SEED
    while (probe < n) {
        if (measure(runeSlice(runes, start, start + probe)) <= maxW) {
            fits = probe
            probe *= 4
        } else {
            return largestFitting(runes, start, fits, probe - 1, measure, maxW)
        }
    }
    if (measure(runeSlice(runes, start, start + n)) <= maxW) {
        return n
    }
    largestFitting(runes, start, fits, n - 1, measure, maxW)
}

// Binary search for the largest fitting count inside (knownFit, hi]; `knownFit` already fits (or
// is 0). Same monotone predicate as before, so the result is identical to the full-range search.
private func largestFitting(
    runes: Array<Rune>,
    start: Int64,
    knownFit: Int64,
    hi: Int64,
    measure: (String) -> Float32,
    maxW: Float32
): Int64 {
    var lo = knownFit + 1
    var high = hi
    var answer = knownFit
    while (lo <= high) {
        let mid = (lo + high) / 2
        if (measure(runeSlice(runes, start, start + mid)) <= maxW) {
            answer = mid
            lo = mid + 1
        } else {
            high = mid - 1
        }
    }
    answer
}

// Module-visible so RichText's layout engine shares this one slice helper instead of keeping a copy.
protected func runeSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var i = start
    while (i < end) {
        builder.append(runes[i])
        i += 1
    }
    builder.toString()
}
