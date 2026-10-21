package chui.text

import chui.core.{GraphemeIndex, UiContext, CUI_SMALL_H}
import sdl.{FontSizes, Rect}
import std.collection.ArrayList

/** One measured visual row produced by TextArea soft wrapping. */
public struct TextAreaVisualLine {
    public let logicalLine: Int64
    public let startByte: Int64
    public let endByte: Int64
    public let width: Float32
    public let hardBreak: Bool

    public init(
        logicalLine!: Int64,
        startByte!: Int64,
        endByte!: Int64,
        width!: Float32,
        hardBreak!: Bool = false
    ) {
        this.logicalLine = logicalLine
        this.startByte = startByte
        this.endByte = endByte
        this.width = max(Float32(0.0), width)
        this.hardBreak = hardBreak
    }
}

internal class TextAreaWrapLayout {
    let text: String
    let width: Float32
    let lines: Array<TextAreaVisualLine>

    init(ctx: UiContext, text: String, width: Float32) {
        this.text = text
        this.width = max(Float32(1.0), width)
        let built = ArrayList<TextAreaVisualLine>()
        let boundaries = GraphemeIndex(text)
        var logicalStart: Int64 = 0
        var logicalLine: Int64 = 0
        while (logicalStart <= text.size) {
            let logicalEnd = lineEndAfterOrAt(text, logicalStart)
            let contentEnd = if (logicalEnd > logicalStart && logicalEnd < text.size &&
                text[logicalEnd - 1] == UInt8(13) && text[logicalEnd] == UInt8(10)) {
                logicalEnd - 1
            } else { logicalEnd }
            if (logicalStart == contentEnd) {
                built.add(TextAreaVisualLine(logicalLine: logicalLine, startByte: logicalStart,
                    endByte: contentEnd, width: 0.0, hardBreak: logicalEnd < text.size))
            } else {
                var segmentStart = logicalStart
                var cursor = logicalStart
                while (cursor < contentEnd) {
                    let next = min(contentEnd, boundaries.next(cursor))
                    let candidate = text[segmentStart..next]
                    let candidateWidth = ctx.renderer.textWidth(candidate, pointSize: FontSizes.BODY)
                    if (cursor > segmentStart && candidateWidth > this.width) {
                        let value = text[segmentStart..cursor]
                        built.add(TextAreaVisualLine(logicalLine: logicalLine, startByte: segmentStart,
                            endByte: cursor,
                            width: ctx.renderer.textWidth(value, pointSize: FontSizes.BODY),
                            hardBreak: false))
                        segmentStart = cursor
                    } else {
                        cursor = next
                    }
                }
                let value = text[segmentStart..contentEnd]
                built.add(TextAreaVisualLine(logicalLine: logicalLine, startByte: segmentStart,
                    endByte: contentEnd,
                    width: ctx.renderer.textWidth(value, pointSize: FontSizes.BODY),
                    hardBreak: logicalEnd < text.size))
            }
            if (logicalEnd >= text.size) { break }
            logicalStart = nextTextBoundary(text, logicalEnd)
            logicalLine += 1
        }
        this.lines = built.toArray()
    }

    func rowForOffset(offset: Int64): Int64 {
        if (lines.isEmpty()) { return 0 }
        let value = min(max(offset, Int64(0)), text.size)
        for (i in 0..lines.size) {
            let line = lines[i]
            if (value < line.endByte || (value == line.endByte &&
                (i + 1 == lines.size || lines[i + 1].startByte != value))) {
                return i
            }
        }
        lines.size - 1
    }

    func caretX(ctx: UiContext, row: Int64, offset: Int64): Float32 {
        if (lines.isEmpty()) { return 0.0 }
        let line = lines[min(max(row, Int64(0)), lines.size - 1)]
        let end = min(max(offset, line.startByte), line.endByte)
        ctx.renderer.textWidth(text[line.startByte..end], pointSize: FontSizes.BODY)
    }

    func hit(ctx: UiContext, row: Int64, x: Float32): Int64 {
        if (lines.isEmpty()) { return 0 }
        let line = lines[min(max(row, Int64(0)), lines.size - 1)]
        let value = text[line.startByte..line.endByte]
        let index = GraphemeIndex(value)
        var current = line.startByte
        var previous: Float32 = 0.0
        var ordinal: Int64 = 1
        while (ordinal <= index.count) {
            let next = line.startByte + index.boundary(ordinal)
            let nextWidth = ctx.renderer.textWidth(text[line.startByte..next], pointSize: FontSizes.BODY)
            if (x < (previous + nextWidth) / 2.0) {
                return current
            }
            current = next
            previous = nextWidth
            ordinal += 1
        }
        line.endByte
    }
}

internal func drawWrappedTextArea(
    ctx: UiContext,
    viewport: Rect,
    text: String,
    layout: TextAreaWrapLayout,
    scroll: Float32,
    cursor: Int64,
    selectionStart: Int64,
    selectionEnd: Int64,
    decorations: Array<TextAreaDecorationRun>,
    composition: TextAreaDisplayProjection,
    focused: Bool,
    editable: Bool
): Unit {
    let first = max(Int64(0), Int64(scroll / CUI_SMALL_H))
    let last = min(layout.lines.size, first + Int64(viewport.h / CUI_SMALL_H) + 2)
    for (row in first..last) {
        let line = layout.lines[row]
        let y = viewport.y + Float32(row) * CUI_SMALL_H - scroll
        if (focused && selectionStart < selectionEnd) {
            let left = max(selectionStart, line.startByte)
            let right = min(selectionEnd, line.endByte)
            if (left < right) {
                let x = viewport.x + ctx.renderer.textWidth(text[line.startByte..left], pointSize: FontSizes.BODY)
                let endX = viewport.x + ctx.renderer.textWidth(text[line.startByte..right], pointSize: FontSizes.BODY)
                ctx.renderer.fill(Rect(x, y, endX - x, CUI_SMALL_H), ctx.theme.accent.withAlpha(115))
            }
        }
        var current = line.startByte
        for (run in decorations) {
            if (run.endByte <= line.startByte || run.startByte >= line.endByte) { continue }
            let a = max(line.startByte, run.startByte)
            let b = min(line.endByte, run.endByte)
            if (current < a) {
                ctx.renderer.text(text[current..a], viewport.x +
                    ctx.renderer.textWidth(text[line.startByte..current], pointSize: FontSizes.BODY), y,
                    ctx.theme.text, pointSize: FontSizes.BODY)
            }
            let foreground = match (run.style.foreground) {
                case Some(color) => color
                case None => ctx.theme.text
            }
            match (run.style.background) {
                case Some(color) =>
                    let x = viewport.x + ctx.renderer.textWidth(text[line.startByte..a], pointSize: FontSizes.BODY)
                    let width = ctx.renderer.textWidth(text[a..b], pointSize: FontSizes.BODY)
                    if (width > 0.0) { ctx.renderer.fill(Rect(x, y, width, CUI_SMALL_H), color) }
                case None => ()
            }
            drawTextAreaSlice(ctx, viewport, text, line.startByte, a, b, y, foreground,
                run.style.underline, run.style.underlineShape, 0.0)
            current = b
        }
        if (current < line.endByte || line.startByte == line.endByte) {
            ctx.renderer.text(text[current..line.endByte], viewport.x +
                ctx.renderer.textWidth(text[line.startByte..current], pointSize: FontSizes.BODY), y,
                ctx.theme.text, pointSize: FontSizes.BODY)
        }
        if (focused && composition.active) {
            let a = max(line.startByte, composition.preeditStart)
            let b = min(line.endByte, composition.preeditEnd)
            if (a < b) {
                let x = viewport.x + ctx.renderer.textWidth(text[line.startByte..a], pointSize: FontSizes.BODY)
                let width = ctx.renderer.textWidth(text[a..b], pointSize: FontSizes.BODY)
                drawTextAreaUnderline(ctx, x, y + CUI_SMALL_H - 1.0, width,
                    ctx.theme.accent, TextAreaUnderlineShape.Straight)
            }
        }
    }
    if (focused) {
        ctx.requestFrame()
        let row = layout.rowForOffset(cursor)
        let x = viewport.x + layout.caretX(ctx, row, cursor)
        let y = viewport.y + Float32(row) * CUI_SMALL_H - scroll
        let caret = textAreaCaretRect(ctx, x, y)
        if (caret.right() >= viewport.x && caret.x <= viewport.right() &&
            caret.bottom() >= viewport.y && caret.y <= viewport.bottom()) {
            if (editable) { ctx.setTextInputAnchor(caret) }
            if (textCursorVisible(ctx)) { ctx.renderer.fill(caret, ctx.theme.accent) }
        }
    }
}
