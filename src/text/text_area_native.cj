package chui.text

import chui.core.{NativeTextIndex, NativeTextScalarIndex, UiContext, CUI_SMALL_H}
import sdl.{Color, FontSizes, Rect, Size}
import sdl.text.{NativeTextColorSpan, NativeTextLineSpec}
import std.collection.ArrayList
import std.math.abs

// One immutable displayed line: paint ranges use exact scalars, editing uses
// graphemes. Every native request below uses THIS spec, including its colors.
internal class TextAreaNativeLine {
    let start: Int64
    let end: Int64
    let spec: NativeTextLineSpec
    let scalar: NativeTextScalarIndex
    let editor: NativeTextIndex
    let runs: Array<TextAreaDecorationRun>

    init(text: String, start: Int64, runs: Array<TextAreaDecorationRun>, color: Color) {
        this.start = start
        this.end = start + text.size
        this.scalar = NativeTextScalarIndex(text)
        this.editor = NativeTextIndex(text)
        this.runs = runs
        let colors = ArrayList<NativeTextColorSpan>()
        for (run in runs) {
            if (let Some(foreground) <- run.style.foreground) {
                let a = max(start, run.startByte)
                let b = min(end, run.endByte)
                if (a < b) {
                    colors.add(NativeTextColorSpan(scalar.utf16OffsetForByte(a - start).getOrThrow(),
                        scalar.utf16OffsetForByte(b - start).getOrThrow(),
                        foreground.r, foreground.g, foreground.b, foreground.a))
                }
            }
        }
        this.spec = NativeTextLineSpec(text, colors: colors.toArray(), red: color.r,
            green: color.g, blue: color.b, alpha: color.a)
    }

    func size(ctx: UiContext): Size {
        match (ctx.renderer.textSize(spec, pointSize: FontSizes.BODY)) {
            case Some(value) => value
            case None => throw IllegalStateException("Native TextArea line measurement unavailable")
        }
    }

    func caret(ctx: UiContext, position: Int64, affinity: TextBoundaryCache): Float32 {
        let local = min(max(position - start, Int64(0)), spec.text.size)
        let offset = scalar.utf16OffsetForByte(local).getOrThrow()
        let positions = ctx.renderer.textCaretPositionsUtf16(spec, offset,
            pointSize: FontSizes.BODY).getOrThrow()
        if (affinity.usesSecondary(position)) { positions[1] } else { positions[0] }
    }

    func spans(ctx: UiContext, a: Int64, b: Int64): Array<(Float32, Float32)> {
        let left = max(start, a)
        let right = min(end, b)
        if (left >= right) { return [] }
        ctx.renderer.textSelectionSpansUtf16(spec,
            scalar.utf16OffsetForByte(left - start).getOrThrow(),
            scalar.utf16OffsetForByte(right - start).getOrThrow(), pointSize: FontSizes.BODY).getOrThrow()
    }

    func hit(ctx: UiContext, x: Float32, affinity: TextBoundaryCache): Int64 {
        let raw = ctx.renderer.textHitUtf16(spec, x, pointSize: FontSizes.BODY).getOrThrow()
        let floor = editor.byteOffsetForUtf16(raw)
        let ceil = editor.byteOffsetForUtf16(raw, forward: true)
        var chosen = floor
        var second = false
        var distance: Float32 = 1.0e30
        for (candidate in [floor, ceil, Int64(0), spec.text.size]) {
            let positions = ctx.renderer.textCaretPositionsUtf16(spec,
                editor.utf16OffsetForByte(candidate), pointSize: FontSizes.BODY).getOrThrow()
            for ((point, secondary) in [(positions[0], false), (positions[1], true)]) {
                let delta = abs(point - x)
                if (delta < distance) { distance = delta; chosen = candidate; second = secondary }
            }
        }
        affinity.rememberAffinity(start + chosen, second)
        start + chosen
    }

    // Visual arrow movement compares whole-line native positions, not logical
    // byte ordering. A boundary can have two valid bidi affinities.
    func visual(ctx: UiContext, position: Int64, right: Bool, affinity: TextBoundaryCache): ?Int64 {
        let count = editor.graphemes.count + 1
        let indices = Array<Int64>(count, {i => editor.utf16OffsetForByte(editor.graphemes.boundary(i))})
        let positions = ctx.renderer.textCaretPositionsUtf16(spec, indices,
            pointSize: FontSizes.BODY).getOrThrow()
        let x = caret(ctx, position, affinity)
        var distance: Float32 = 1.0e30
        var chosen: Int64 = -1
        var second = false
        for (i in 0..count) {
            for ((point, secondary) in [(positions[i][0], false), (positions[i][1], true)]) {
                let delta = if (right) { point - x } else { x - point }
                if (delta > 0.01 && delta < distance) {
                    distance = delta; chosen = editor.graphemes.boundary(i); second = secondary
                }
            }
        }
        if (chosen < 0) { return None }
        affinity.rememberAffinity(start + chosen, second)
        Some(start + chosen)
    }
}

// Per-control retained model; no native CTLine ownership escapes the existing
// Renderer cache. Only the displayed text and decoration snapshot rebuild it.
internal class TextAreaNativeDocument {
    let text: String
    let lines: Array<TextAreaNativeLine>
    private var widthEnvironment = ""
    private var cachedWidth: Float32 = 0.0

    init(text: String, runs: Array<TextAreaDecorationRun>, color: Color) {
        this.text = text
        let built = ArrayList<TextAreaNativeLine>()
        var start: Int64 = 0
        var row: Int64 = 0
        var nextRun: Int64 = 0
        while (start <= text.size) {
            let logicalEnd = lineEndAfterOrAt(text, start)
            let raw = text[start..logicalEnd]
            // CRLF is one hard break, not a drawable CR glyph.
            let value = if (raw.endsWith("\r") && start + raw.size < text.size) {
                raw[0..raw.size - 1]
            } else { raw }
            let rowRuns = ArrayList<TextAreaDecorationRun>()
            while (nextRun < runs.size && runs[nextRun].lineIndex == row) {
                rowRuns.add(runs[nextRun]); nextRun += 1
            }
            built.add(TextAreaNativeLine(value, start, rowRuns.toArray(), color))
            if (logicalEnd >= text.size) { break }
            start = nextTextBoundary(text, logicalEnd)
            row += 1
        }
        this.lines = built.toArray()
    }

    func row(position: Int64): Int64 {
        var low: Int64 = 0
        var high = lines.size - 1
        while (low < high) {
            let mid = (low + high + 1) / 2
            if (lines[mid].start <= position) { low = mid } else { high = mid - 1 }
        }
        low
    }

    func width(ctx: UiContext): Float32 {
        let environment = ctx.renderer.textLayoutEnvironmentKey()
        if (environment == widthEnvironment) { return cachedWidth }
        var result: Float32 = 0.0
        for (line in lines) { result = max(result, line.size(ctx).w) }
        cachedWidth = result + 2.0
        widthEnvironment = environment
        cachedWidth
    }

    func caret(ctx: UiContext, position: Int64, affinity: TextBoundaryCache): Float32 {
        lines[row(position)].caret(ctx, position, affinity)
    }

    func hit(ctx: UiContext, row: Int64, x: Float32, affinity: TextBoundaryCache): Int64 {
        lines[min(max(row, Int64(0)), lines.size - 1)].hit(ctx, x, affinity)
    }

    func move(ctx: UiContext, position: Int64, horizontal: Bool, forward: Bool,
        affinity: TextBoundaryCache): Int64 {
        let current = row(position)
        if (horizontal) {
            if (let Some(next) <- lines[current].visual(ctx, position, forward, affinity)) { return next }
        }
        let next = current + if (forward) { 1 } else { -1 }
        if (next < 0 || next >= lines.size) { return position }
        let x: Float32 = if (horizontal) { if (forward) { -1.0 } else { lines[next].size(ctx).w + 1.0 } }
            else { lines[current].caret(ctx, position, affinity) }
        lines[next].hit(ctx, x, affinity)
    }

    func collapse(ctx: UiContext, start: Int64, end: Int64, right: Bool,
        affinity: TextBoundaryCache): Int64 {
        let line = lines[row(if (right) { end } else { start })]
        let spans = line.spans(ctx, start, end)
        var x = line.caret(ctx, if (right) { end } else { start }, affinity)
        if (!spans.isEmpty()) {
            x = if (right) { spans[0][1] } else { spans[0][0] }
            for ((left, high) in spans) { x = if (right) { max(x, high) } else { min(x, left) } }
        }
        line.hit(ctx, x, affinity)
    }

    func draw(ctx: UiContext, viewport: Rect, content: TextAreaContent, id: String,
        selectionStart: Int64, selectionEnd: Int64, composition: TextAreaDisplayProjection,
        affinity: TextBoundaryCache, editable!: Bool = true): Unit {
        let first = max(Int64(0), Int64(content.scroll / CUI_SMALL_H))
        let last = min(lines.size, first + Int64(viewport.h / CUI_SMALL_H) + 2)
        let origin = viewport.x - content.horizontalScroll
        for (row in first..last) {
            let line = lines[row]
            let y = viewport.y + Float32(row) * CUI_SMALL_H - content.scroll
            let height = min(line.size(ctx).h, CUI_SMALL_H)
            for (run in line.runs) {
                if (let Some(color) <- run.style.background) {
                    paintNativeSpans(ctx, line.spans(ctx, run.startByte, run.endByte), origin, y, height, color)
                }
            }
            if (ctx.hasFocus(id)) {
                paintNativeSpans(ctx, line.spans(ctx, selectionStart, selectionEnd), origin, y,
                    height, ctx.theme.accent.withAlpha(115))
                if (row + 1 < lines.size && selectionStart <= line.end && selectionEnd > line.end) {
                    let x = origin + line.caret(ctx, line.end, affinity)
                    if (x < viewport.right()) {
                        ctx.renderer.fill(Rect(x, y, viewport.right() - x, height), ctx.theme.accent.withAlpha(115))
                    }
                }
            }
            if (!ctx.renderer.text(line.spec, origin, y, pointSize: FontSizes.BODY)) {
                throw IllegalStateException("Native TextArea line exceeds the renderer's drawable limits")
            }
            for (run in line.runs) {
                if (let Some(color) <- run.style.underline) {
                    for ((left, right) in line.spans(ctx, run.startByte, run.endByte)) {
                        drawTextAreaUnderline(ctx, origin + left, y + height - 1.0, right - left,
                            color, run.style.underlineShape)
                    }
                }
            }
            if (ctx.hasFocus(id) && composition.active) {
                for ((left, right) in line.spans(ctx, composition.preeditStart, composition.preeditEnd)) {
                    drawTextAreaUnderline(ctx, origin + left, y + height - 1.0, right - left,
                        ctx.theme.accent, TextAreaUnderlineShape.Straight)
                }
            }
        }
        if (ctx.hasFocus(id)) {
            ctx.requestFrame()
            let row = row(content.cursor)
            let line = lines[row]
            let caret = Rect(origin + line.caret(ctx, content.cursor, affinity),
                viewport.y + Float32(row) * CUI_SMALL_H - content.scroll,
                1.5, min(line.size(ctx).h, CUI_SMALL_H))
            if (caret.right() >= viewport.x && caret.x <= viewport.right() &&
                caret.bottom() >= viewport.y && caret.y <= viewport.bottom()) {
                if (editable) { ctx.setTextInputAnchor(caret) }
                if (textCursorVisible(ctx)) { ctx.renderer.fill(caret, ctx.theme.accent) }
            }
        }
    }
}

private func paintNativeSpans(ctx: UiContext, spans: Array<(Float32, Float32)>,
    x: Float32, y: Float32, height: Float32, color: Color): Unit {
    for ((left, right) in spans) {
        if (right > left) { ctx.renderer.fill(Rect(x + left, y, right - left, height), color) }
    }
}

internal class TextAreaNativeCache {
    var revision: UInt64 = 0
    private var document: ?TextAreaNativeDocument = None
    private var displayRevision: UInt64 = 0
    private var decorationRevision: UInt64 = 0
    private var color = Color.rgb(0, 0, 0)
    private var snapshot: ?TextAreaDecorationSnapshot = None

    func resolve(text: String, display: UInt64, decoration: UInt64, color: Color,
        snapshot: ?TextAreaDecorationSnapshot, buildRuns: () -> Array<TextAreaDecorationRun>,
        affinity: TextBoundaryCache): TextAreaNativeDocument {
        let sameSnapshot = match ((this.snapshot, snapshot)) {
            case (Some(previous), Some(current)) => refEq(previous, current)
            case (None, None) => true
            case _ => false
        }
        if (display == displayRevision && decoration == decorationRevision &&
            sameSnapshot &&
            this.color.r == color.r && this.color.g == color.g && this.color.b == color.b && this.color.a == color.a) {
            if (let Some(value) <- document) { return value }
        }
        let value = TextAreaNativeDocument(text, buildRuns(), color)
        document = Some(value)
        displayRevision = display; decorationRevision = decoration; this.color = color
        this.snapshot = snapshot
        revision += UInt64(1)
        affinity.clearAffinity()
        value
    }
}
