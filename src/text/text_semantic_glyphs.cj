package chui.text

import chui.core.{NativeTextIndex, SemanticTextGlyph, SemanticTextLayout, SemanticTextGeometry, UiContext}
import sdl.Rect
import sdl.text.NativeTextLineSpec
import std.collection.ArrayList

// A retained control cache, not another text model. Native line identity remains
// in Renderer; only copied relative glyph evidence is held here across frames.
internal class NativeSemanticGlyphCache {
    private var content = ""
    private var environment = ""
    private var ready = false
    private var layout: ?SemanticTextLayout = None
    private var builds: UInt64 = 0

    func resolve(ctx: UiContext, text: String, typography: TextFieldTypography): ?SemanticTextLayout {
        if (!ctx.renderer.platformTextLayoutEnabled() || (typography.style.ttfFlags() & 0x0E) != 0 ||
            !semanticGlyphValueSupported(text) || text.contains("\n")) { return None }
        let key = ctx.renderer.textLayoutEnvironmentKey(font: typography.font) +
            "|${typography.pointSize}|${typography.style.ttfFlags()}"
        if (ready && content == text && environment == key) { return layout }
        let glyphs = ArrayList<SemanticTextGlyph>()
        let height = ctx.renderer.textSize(text, pointSize: typography.pointSize,
            style: typography.style, font: typography.font).h
        layout = if (appendNativeSemanticGlyphs(ctx, glyphs, text, 0, text.size, 0, 0.0, height, typography)) {
            Some(SemanticTextLayout(text, glyphs.toArray()))
        } else { None }
        content = text; environment = key; ready = true; builds++
        layout
    }

    func rebuildCount(): UInt64 { builds }
}

internal func semanticGlyphValueSupported(text: String): Bool {
    text.size <= 1024 * 1024 && !text.contains("\u{0}") && !text.replace("\r\n", "").contains("\r")
}

// Each interval comes from the actual shaped selection of one editor grapheme.
// Adjacent paint runs can be joined; disconnected glyph islands are not replaced
// by a guessed enclosing hit rectangle. Such a line has no geometric projection.
internal func appendNativeSemanticGlyphs(ctx: UiContext, result: ArrayList<SemanticTextGlyph>,
    text: String, start: Int64, breakEnd: Int64, row: Int64, y: Float32, height: Float32,
    typography: TextFieldTypography, paint!: ?NativeTextLineSpec = None): Bool {
    let index = NativeTextIndex(text)
    let count = index.graphemes.count
    let indices = Array<Int64>(count, {i => index.utf16OffsetForByte(index.graphemes.boundary(i))})
    let directions = match (paint) {
        case Some(spec) => ctx.renderer.textRightToLeftUtf16(spec, indices, pointSize: typography.pointSize,
            style: typography.style, font: typography.font).getOrThrow()
        case None => ctx.renderer.textRightToLeftUtf16(text, indices, pointSize: typography.pointSize,
            style: typography.style, font: typography.font).getOrThrow()
    }
    for (i in 0..count) {
        let a = indices[i]
        let b = index.utf16OffsetForByte(index.graphemes.boundary(i + 1))
        let spans = match (paint) {
            case Some(spec) => ctx.renderer.textSelectionSpansUtf16(spec, a, b, pointSize: typography.pointSize,
                style: typography.style, font: typography.font).getOrThrow()
            case None => ctx.renderer.textSelectionSpansUtf16(text, a, b, pointSize: typography.pointSize,
                style: typography.style, font: typography.font).getOrThrow()
        }
        var left: Float32 = 0.0; var right: Float32 = 0.0
        if (spans.isEmpty()) {
            let caret = semanticGlyphCaret(ctx, text, a, typography, paint)
            left = caret; right = caret
        } else {
            left = spans[0][0]; right = spans[0][1]
            for (j in 1..spans.size) {
                if (spans[j][0] > right + 0.01 || spans[j][1] < left - 0.01) { return false }
                left = min(left, spans[j][0]); right = max(right, spans[j][1])
            }
        }
        result.add(SemanticTextGlyph(start + index.graphemes.boundary(i),
            start + index.graphemes.boundary(i + 1), row, Rect(left, y, right - left, height), directions[i]))
    }
    let end = start + text.size
    if (breakEnd > end || text.isEmpty()) {
        let x = semanticGlyphCaret(ctx, text, index.utf16OffsetForByte(text.size), typography, paint)
        result.add(SemanticTextGlyph(end, breakEnd, row, Rect(x, y, 0.0, height),
            if (directions.isEmpty()) { false } else { directions[count - 1] }))
    }
    true
}

private func semanticGlyphCaret(ctx: UiContext, text: String, offset: Int64,
    typography: TextFieldTypography, paint: ?NativeTextLineSpec): Float32 {
    match (paint) {
        case Some(spec) => ctx.renderer.textCaretPositionsUtf16(spec, offset, pointSize: typography.pointSize,
            style: typography.style, font: typography.font).getOrThrow()[0]
        case None => ctx.renderer.textCaretPositionsUtf16(text, offset, pointSize: typography.pointSize,
            style: typography.style, font: typography.font).getOrThrow()[0]
    }
}
