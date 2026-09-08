package chui.text

import chui.core.UiContext
import sdl.Rect

internal func drawTextFieldPreeditUnderline(ctx: UiContext, frame: Rect, text: String,
    start: Int64, end: Int64, shift: Float32, typography: TextFieldTypography): Unit {
    if (start >= end) { return }
    let height = ctx.renderer.textHeight(pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    let y = frame.centerY() + height / 2.0
    if (ctx.renderer.platformTextLayoutEnabled() && (typography.style.ttfFlags() & 0x0E) == 0) {
        let index = nativeIndex(text, typography)
        if (let Some(spans) <- ctx.renderer.textSelectionSpansUtf16(text,
            index.utf16OffsetForByte(start), index.utf16OffsetForByte(end, forward: true),
            pointSize: typography.pointSize, style: typography.style, font: typography.font)) {
            for ((left, right) in spans) {
                ctx.renderer.fill(Rect(frame.x + 8.0 - shift + left, y, max(0.0, right - left), 1.0), ctx.theme.accent)
            }
            return
        }
    }
    let left = textCaretOffset(ctx, text, start, typography: typography)
    let right = textCaretOffset(ctx, text, end, typography: typography)
    ctx.renderer.fill(Rect(frame.x + 8.0 - shift + min(left, right), y,
        max(1.0, max(left, right) - min(left, right)), 1.0), ctx.theme.accent)
}
