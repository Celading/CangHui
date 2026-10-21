package chui.text

import chui.core.{CUI_SMALL_H, Length, UiContext}
import sdl.{FontSizes, FontStyle}

// One input contract for editor paint, geometry and retained layout caches.
internal struct TextAreaTypography {
    let pointSize: Float32
    let style: FontStyle
    let font: ?String
    let rowHeight: Float32

    init(pointSize!: Float32 = FontSizes.BODY, style!: FontStyle = FontStyle.regular,
        font!: ?String = None, rowHeight!: Float32 = CUI_SMALL_H) {
        this.pointSize = pointSize
        this.style = style
        this.font = font
        this.rowHeight = rowHeight
    }

    func key(ctx: UiContext): String {
        "${pointSize}|${style.ttfFlags()}|${rowHeight}|${font}|" +
            ctx.renderer.textLayoutEnvironmentKey(font: font)
    }

    func field(): TextFieldTypography {
        TextFieldTypography(pointSize: pointSize, style: style, font: font)
    }
}

internal func resolveTextAreaTypography(ctx: UiContext, rowHeight!: ?Length = None): TextAreaTypography {
    let environment = ctx.typographyEnvironment()
    let size = match (environment.fontSize) {
        case Some(value) => max(1.0, ctx.resolve(value))
        case None => FontSizes.BODY
    }
    let style = environment.resolvedFontStyle()
    let height = ctx.renderer.textHeight(pointSize: size, style: style, font: environment.fontFamily)
    let requested = match (rowHeight) { case Some(value) => ctx.resolve(value) case None => CUI_SMALL_H }
    if (!(requested > 0.0 && requested <= 1000000.0)) {
        throw IllegalArgumentException("TextArea line height must be finite and positive")
    }
    TextAreaTypography(pointSize: size, style: style, font: environment.fontFamily,
        rowHeight: max(requested, height))
}
