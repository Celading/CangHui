package canghui_kit

import chui.*

private let KIT_DIGITS: Array<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

// Only per-column positions are floating point. The authoritative number and
// every sign/digit remain the original Int64 string, including Int64.Min.
internal class KitNumberMotion {
    private let columns = Array<MotionValue>(19, {_ => MotionValue(0.0)})
    private let goals = Array<Float32>(19, {_ => 0.0})
    private let digits = Array<Int64>(19, {_ => 0})
    private var target = ""

    func prepare(text: String): Unit {
        if (text == target) { return }
        target = text
        let count = text.size - if (text.startsWith("-")) {1} else {0}
        for (i in 0..count) {
            let digit = Int64(text[text.size - 1 - i]) - 48
            if (digit == digits[i]) { continue }
            if (columns[i].settled()) {
                columns[i].reset(Float32(Int64(columns[i].value) % 10))
            }
            var goal = Float32(Int64(columns[i].value / 10.0) * 10 + digit)
            if (goal < columns[i].value) { goal += 10.0 }
            goals[i] = goal
            digits[i] = digit
        }
    }

    func sample(ctx: UiContext, column: Int64): Float32 {
        columns[column].animate(ctx, target: goals[column],
            spec: AnimationSpec.automatic(duration: 460, easing: Easing.EaseOutCubic))
    }

    func semanticValue(): String { target }
}

/** Exact numeric semantics with independently rolling decorative digit slots.
 * Font family, size and style inherit normally; long numbers fit the available
 * width using real font measurements. Signs do not spin. Updates replace the
 * target immediately and continue from each column's visible position.
 */
public func kitRollingNumber(key: String, value: Int64, palette: KitMotionPalette,
    fontSize!: ?Length = None): Widget {
    let text = value.toString()
    let motion = rememberState<KitNumberMotion>("KitRollingNumber:${key}") {KitNumberMotion()}.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        let environment = ctx.typographyEnvironment()
        let requested = match (fontSize) {
            case Some(length) => max(1.0, ctx.resolve(length))
            case None => match (environment.fontSize) {
                case Some(length) => max(1.0, ctx.resolve(length))
                case None => Float32(48.0)
            }
        }
        let style = environment.resolvedFontStyle()
        let font = environment.fontFamily
        let negative = text.startsWith("-")
        let count = text.size - if (negative) {1} else {0}
        var size = requested
        var cell: Float32 = 0.0
        var sign: Float32 = 0.0
        let available = max(1.0, rect.w - 24.0)
        for (_ in 0..4) {
            cell = 0.0
            for (digit in KIT_DIGITS) {
                cell = max(cell, ctx.renderer.textWidth(digit, pointSize: size, style: style, font: font))
            }
            sign = if (negative) {
                ctx.renderer.textWidth("-", pointSize: size, style: style, font: font)
            } else {Float32(0.0)}
            let width = cell * Float32(count) + sign
            if (width <= available || size <= 1.0) { break }
            size = max(1.0, size * available / max(1.0, width) * 0.98)
        }
        let height = ctx.renderer.textHeight(pointSize: size, style: style, font: font)
        let y = rect.centerY() - height / 2.0
        let right = rect.right() - 12.0
        motion.prepare(text)
        recordControlSemantics(ctx, rect, "KitRollingNumber", ControlSemantics("text",
            label: "Number", value: text, action: "", shortcut: "", actionOwner: key,
            readOnly: Some(true), editable: Some(false)))
        for (i in 0..count) {
            let position = motion.sample(ctx, i)
            let whole = Int64(position)
            let fraction = position - Float32(whole)
            let x = right - Float32(i + 1) * cell
            ctx.renderer.pushClip(Rect(x, y, cell, height))
            try {
                drawKitDigit(ctx, KIT_DIGITS[whole % 10], x, y - fraction * height,
                    cell, size, style, font, palette.ink)
                if (fraction > 0.0001) {
                    drawKitDigit(ctx, KIT_DIGITS[(whole + 1) % 10], x, y + (1.0 - fraction) * height,
                        cell, size, style, font, palette.ink)
                }
            } finally { ctx.renderer.popClip() }
        }
        if (negative) {
            ctx.renderer.text("-", right - Float32(count) * cell - sign, y, palette.ink,
                pointSize: size, style: style, font: font)
        }
    }, transparent: true).probe(key, "KitRollingNumber", [ProbeProperty("number", text)])
}

private func drawKitDigit(ctx: UiContext, text: String, x: Float32, y: Float32, cell: Float32,
    size: Float32, style: FontStyle, font: ?String, color: Color): Unit {
    let width = ctx.renderer.textWidth(text, pointSize: size, style: style, font: font)
    ctx.renderer.text(text, x + (cell - width) / 2.0, y, color, pointSize: size, style: style, font: font)
}
