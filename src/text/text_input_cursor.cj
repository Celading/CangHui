package chui.text

import sdl.{FontSizes, FontStyle, Point, Rect}
import chui.core.{CUI_SMALL_H, GraphemeIndex, NativeTextIndex, UiContext, scrollLineIndex, scrollLineRemainder}
import std.math.abs

private let TEXT_CURSOR_W: Float32 = 1.5
private let TEXT_FIELD_PAD_X: Float32 = 8.0
/* Half a standard blink cycle: the caret is visible for this long, then hidden as long. */
private let TEXT_CURSOR_BLINK_MS: UInt64 = 530

/*
 * One resolved typography snapshot shared by every glyph-dependent TextField
 * operation in a lifecycle pass. Keeping the values together prevents measurement,
 * hit-testing, selection and paint from silently resolving different environments.
 */
internal struct TextFieldTypography {
    let pointSize: Float32
    let style: FontStyle
    let font: ?String
    let boundaries: ?TextBoundaryCache

    init(
        pointSize!: Float32 = FontSizes.BODY,
        style!: FontStyle = FontStyle.regular,
        font!: ?String = None<String>,
        boundaries!: ?TextBoundaryCache = None
    ) {
        this.pointSize = pointSize
        this.style = style
        this.font = font
        this.boundaries = boundaries
    }
}

internal func nativeIndex(text: String, typography: TextFieldTypography): NativeTextIndex {
    match (typography.boundaries) {
        case Some(cache) => cache.nativeIndex(text)
        case None => NativeTextIndex(text)
    }
}

internal func textCaretOffset(ctx: UiContext, text: String, position: Int64,
    typography!: TextFieldTypography = TextFieldTypography()): Float32 {
    if (ctx.renderer.platformTextLayoutEnabled() && (typography.style.ttfFlags() & 0x0E) == 0) {
        let index = nativeIndex(text, typography)
        let byte = index.graphemes.floor(position)
        if (let Some((primary, secondary)) <- ctx.renderer.textCaretPositionsUtf16(text,
            index.utf16OffsetForByte(byte), pointSize: typography.pointSize,
            style: typography.style, font: typography.font)) {
            if (let Some(cache) <- typography.boundaries) {
                if (cache.usesSecondary(byte)) { return secondary }
            }
            return primary
        }
    }
    ctx.renderer.textWidth(text[0..normalizedTextCursor(text, position)], pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
}

private func nativeCursorForOffset(ctx: UiContext, text: String, targetX: Float32,
    typography: TextFieldTypography): ?Int64 {
    if (let Some(raw) <- ctx.renderer.textHitUtf16(text, targetX, pointSize: typography.pointSize,
        style: typography.style, font: typography.font)) {
        let index = nativeIndex(text, typography)
        let floor = index.byteOffsetForUtf16(raw)
        let ceil = index.byteOffsetForUtf16(raw, forward: true)
        var selected = floor
        var useSecondary = false
        var distance: Float32 = 1.0e30
        for (candidate in [floor, ceil, Int64(0), text.size]) {
            if (let Some((primary, secondary)) <- ctx.renderer.textCaretPositionsUtf16(text,
                index.utf16OffsetForByte(candidate), pointSize: typography.pointSize,
                style: typography.style, font: typography.font)) {
                for ((x, second) in [(primary, false), (secondary, true)]) {
                    let delta = abs(x - targetX)
                    if (delta < distance) { distance = delta; selected = candidate; useSecondary = second }
                }
            }
        }
        if (let Some(cache) <- typography.boundaries) { cache.rememberAffinity(selected, useSecondary) }
        return Some(selected)
    }
    None
}

// One batched native query avoids rebuilding/hash-copying a full-line cache key per boundary.
internal func textVisualCursor(ctx: UiContext, text: String, cursor: Int64, right: Bool,
    typography: TextFieldTypography): ?Int64 {
    if (!ctx.renderer.platformTextLayoutEnabled() || (typography.style.ttfFlags() & 0x0E) != 0) { return None }
    let index = nativeIndex(text, typography)
    let indices = Array<Int64>(index.graphemes.count + 1, {i =>
        index.utf16OffsetForByte(index.graphemes.boundary(i)) })
    if (let Some(positions) <- ctx.renderer.textCaretPositionsUtf16(text, indices,
        pointSize: typography.pointSize, style: typography.style, font: typography.font)) {
        let x = textCaretOffset(ctx, text, cursor, typography: typography)
        var distance: Float32 = 1.0e30
        var selected = index.graphemes.floor(cursor)
        var second = false
        var changed = false
        for (i in 0..positions.size) {
            for ((candidate, affinity) in [(positions[i][0], false), (positions[i][1], true)]) {
                let delta = if (right) { candidate - x } else { x - candidate }
                if (delta > 0.01 && delta < distance) {
                    selected = index.graphemes.boundary(i); second = affinity
                    distance = delta; changed = true
                }
            }
        }
        if (changed) {
            if (let Some(cache) <- typography.boundaries) { cache.rememberAffinity(selected, second) }
        }
        return Some(selected)
    }
    None
}

internal struct TextAreaContent {
    let text: String
    let cursor: Int64
    let scroll: Float32
    let horizontalScroll: Float32

    init(text: String, cursor: Int64, scroll: Float32, horizontalScroll!: Float32 = 0.0) {
        this.text = text
        this.cursor = cursor
        this.scroll = scroll
        this.horizontalScroll = horizontalScroll
    }
}

internal func textInputViewport(frame: Rect): Rect {
    frame.inset(8.0)
}

/*
 * The caret blinks on the shared frame clock. The UI redraws every frame, so phase
 * toggling is enough; no per-control timer state is needed.
 */
internal func textCursorVisible(ctx: UiContext): Bool {
    (ctx.frame.elapsedMs / TEXT_CURSOR_BLINK_MS) % UInt64(2) == UInt64(0)
}

/*
 * Byte offset for a click at `targetX` (relative to where the line's text starts).
 * Native TextField queries the complete shaped line. The legacy prefix-width path
 * remains for other callers; it does not provide contextual shaping or bidi geometry.
 */
private func textCursorForOffset(
    ctx: UiContext,
    text: String,
    lineStart: Int64,
    lineEnd: Int64,
    targetX: Float32,
    typography!: TextFieldTypography = TextFieldTypography(),
    nativeField!: Bool = false
): Int64 {
    // Index only this line once. It starts after LF, an unconditional grapheme
    // boundary, so segmentation context cannot leak from the previous line.
    let contentEnd = if (lineEnd > lineStart && lineEnd < text.size &&
        text[lineEnd] == UInt8(10) && text[lineEnd - 1] == UInt8(13)) { lineEnd - 1 } else { lineEnd }
    // TextArea must migrate hit/caret/selection together, not inherit only native hit testing.
    if (nativeField) {
        if (let Some(offset) <- nativeCursorForOffset(ctx, text[lineStart..contentEnd], targetX, typography)) {
            return lineStart + offset
        }
    }
    let boundaries = GraphemeIndex(text[lineStart..contentEnd])
    var ordinal: Int64 = 0
    var current = lineStart
    var previousWidth: Float32 = 0.0
    while (current < contentEnd) {
        ordinal += 1
        let next = lineStart + boundaries.boundary(ordinal)
        let nextWidth = ctx.renderer.textWidth(text[lineStart..next], pointSize: typography.pointSize,
            style: typography.style, font: typography.font)
        if (targetX < (previousWidth + nextWidth) / 2.0) {
            return current
        }
        previousWidth = nextWidth
        current = next
    }
    contentEnd
}

// `xShift` is the field's horizontal follow offset: the text window slides left by this many
// pixels when the caret runs past the inner width, so hit-testing adds it back.
internal func textFieldCursorForPoint(ctx: UiContext, frame: Rect, text: String, x: Float32,
    xShift!: Float32 = 0.0,
    typography!: TextFieldTypography = TextFieldTypography()): Int64 {
    let lineEnd = lineEndAfterOrAt(text, 0)
    textCursorForOffset(ctx, text, 0, lineEnd, x - frame.x - TEXT_FIELD_PAD_X + xShift,
        typography: typography, nativeField: true)
}

internal func textAreaCursorForPoint(
    ctx: UiContext,
    frame: Rect,
    content: TextAreaContent,
    point: Point
): Int64 {
    let viewport = textInputViewport(frame)
    let line = Int64(max(0.0, point.y - viewport.y + content.scroll) / CUI_SMALL_H)
    let lineStart = startOfTextLine(content.text, line)
    let lineEnd = lineEndAfterOrAt(content.text, lineStart)
    textCursorForOffset(ctx, content.text, lineStart, lineEnd,
        point.x - viewport.x + content.horizontalScroll)
}

/*
 * Paints logical selection behind a single-line field. The native line can return
 * disconnected visual spans. Legacy mode retains prefix widths; the fill is translucent.
 */
internal func drawTextFieldSelection(ctx: UiContext, frame: Rect, text: String, selStart: Int64, selEnd: Int64,
    xShift!: Float32 = 0.0,
    typography!: TextFieldTypography = TextFieldTypography()): Unit {
    if (selStart >= selEnd) {
        return
    }
    if (ctx.renderer.platformTextLayoutEnabled() && (typography.style.ttfFlags() & 0x0E) == 0) {
        let index = nativeIndex(text, typography)
        if (let Some(spans) <- ctx.renderer.textSelectionSpansUtf16(text,
            index.utf16OffsetForByte(selStart), index.utf16OffsetForByte(selEnd, forward: true),
            pointSize: typography.pointSize, style: typography.style, font: typography.font)) {
            let height = ctx.renderer.textHeight(pointSize: typography.pointSize,
                style: typography.style, font: typography.font)
            for ((left, right) in spans) {
                ctx.renderer.fill(Rect(frame.x + TEXT_FIELD_PAD_X - xShift + left,
                    frame.centerY() - height / 2.0, right - left, height), ctx.theme.accent.withAlpha(115))
            }
            return
        }
    }
    let startW = ctx.renderer.textWidth(text[0..selStart], pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    let endW = ctx.renderer.textWidth(text[0..selEnd], pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    let xStart = frame.x + TEXT_FIELD_PAD_X - xShift + startW
    let xEnd = frame.x + TEXT_FIELD_PAD_X - xShift + endW
    let lineHeight = ctx.renderer.textHeight(pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    // Opaque enough to read as a selection over the focused field's tinted surface, still
    // translucent so the glyphs drawn on top stay legible.
    ctx.renderer.fill(Rect(xStart, frame.centerY() - lineHeight / 2.0, xEnd - xStart, lineHeight),
        ctx.theme.accent.withAlpha(115))
}

internal func drawTextFieldCursor(ctx: UiContext, frame: Rect, id: String, text: String, cursor: Int64,
    xShift!: Float32 = 0.0,
    typography!: TextFieldTypography = TextFieldTypography()): Unit {
    if (!ctx.hasFocus(id)) {
        return
    }
    // A focused field blinks its caret on the frame clock, so keep frames flowing even while the
    // screen is otherwise idle; without this the dirty-frame loop (档 0) would freeze the blink.
    ctx.requestFrame()
    let position = normalizedTextCursor(text, cursor)
    let prefixW = textCaretOffset(ctx, text, position, typography: typography)
    let x = frame.x + TEXT_FIELD_PAD_X - xShift + prefixW
    // The caret spans exactly the glyph row: same height and vertical center as the
    // text the field draws, instead of the field's padding box.
    let lineHeight = ctx.renderer.textHeight(pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    let caret = Rect(x, frame.centerY() - lineHeight / 2.0, TEXT_CURSOR_W, lineHeight)
    // The IME anchors its candidate window at the caret whenever the field has focus;
    // the blink phase only gates painting.
    ctx.setTextInputAnchor(caret)
    if (!textCursorVisible(ctx)) {
        return
    }
    ctx.renderer.fill(caret, ctx.theme.accent)
}

/*
 * Paints the selection across the visible lines of a text area. Each line contributes the
 * band covering its selected bytes; a line whose trailing newline is inside the selection
 * extends to the viewport's right edge, giving the familiar full-width look for interior
 * and blank lines. Offsets use the same prefix-width measurement as the caret.
 */
internal func drawTextAreaSelection(
    ctx: UiContext,
    viewport: Rect,
    content: TextAreaContent,
    selStart: Int64,
    selEnd: Int64
): Unit {
    if (selStart >= selEnd) {
        return
    }
    let text = content.text
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    var lineStart = startOfTextLine(text, scrollLineIndex(content.scroll))
    var y = viewport.y - scrollLineRemainder(content.scroll)
    while (y < viewport.bottom()) {
        let lineEnd = lineEndAfterOrAt(text, lineStart)
        let a = max(selStart, lineStart)
        let b = min(selEnd, lineEnd)
        let newlineSelected = lineEnd < text.size && selStart <= lineEnd && selEnd > lineEnd
        if (a < b || newlineSelected) {
            let xA = viewport.x - content.horizontalScroll +
                ctx.renderer.textWidth(text[lineStart..a], pointSize: FontSizes.BODY)
            let xB = if (newlineSelected) {
                viewport.right()
            } else {
                viewport.x - content.horizontalScroll +
                    ctx.renderer.textWidth(text[lineStart..b], pointSize: FontSizes.BODY)
            }
            if (xB > xA) {
                ctx.renderer.fill(Rect(xA, y, xB - xA, lineHeight), ctx.theme.accent.withAlpha(115))
            }
        }
        if (lineEnd >= text.size) {
            break
        }
        lineStart = nextTextBoundary(text, lineEnd)
        y += CUI_SMALL_H
    }
}

internal func drawTextAreaCursor(
    ctx: UiContext,
    viewport: Rect,
    id: String,
    content: TextAreaContent
): Unit {
    if (!ctx.hasFocus(id)) {
        return
    }
    // A focused area blinks its caret on the frame clock; keep frames flowing so the dirty-frame
    // loop (档 0) does not freeze the blink even when nothing else changes.
    ctx.requestFrame()
    let position = normalizedTextCursor(content.text, content.cursor)
    let line = textCursorLineIndex(content.text, position)
    let lineStart = lineStartBeforeOrAt(content.text, position)
    let x = viewport.x - content.horizontalScroll +
        ctx.renderer.textWidth(content.text[lineStart..position], pointSize: FontSizes.BODY)
    let y = viewport.y + Float32(line) * CUI_SMALL_H - content.scroll
    if (y + CUI_SMALL_H < viewport.y || y > viewport.bottom() ||
        x + TEXT_CURSOR_W < viewport.x || x > viewport.right()) {
        return // an off-screen caret leaves the last visible IME anchor standing
    }
    // Rows are drawn from the top of each CUI_SMALL_H cell, so the caret matches the
    // glyph row exactly rather than filling the whole cell.
    let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.BODY)
    let caret = Rect(x, y, TEXT_CURSOR_W, min(lineHeight, CUI_SMALL_H))
    // The IME anchors its candidate window at the caret whenever the area has focus;
    // the blink phase only gates painting.
    ctx.setTextInputAnchor(caret)
    if (!textCursorVisible(ctx)) {
        return
    }
    ctx.renderer.fill(caret, ctx.theme.accent)
}
