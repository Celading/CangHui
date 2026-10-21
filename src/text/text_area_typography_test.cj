package chui.text

import chui.core.{State, Theme, TypographyEnvironment, UiContext, Length, LengthUnit}
import sdl.{FontStyle, MouseButton, Rect, Renderer, UiEvent}
import std.math.abs

@Test
func textAreaInheritedTypographyControlsPaintCaretAndHitTogether(): Unit {
    for (size in [Float32(12.0), Float32(32.0)]) {
        for (mode in [TextAreaWrapMode.NoWrap, TextAreaWrapMode.SoftWrap]) {
            let renderer = Renderer.recordingHeadless()
            let ctx = UiContext(renderer, Theme.light())
            let source = State<String>("a你éb\n尾行")
            let cursor = State<Int64>(4)
            let area = TextArea(source, key: "inherited-area", cursor: Some(cursor),
                anchor: Some(State<Int64>(4)), wrapMode: mode)
            ctx.withTypographyEnvironment(TypographyEnvironment(fontSize: Length(size, LengthUnit.Fp),
                fontFamily: "Custom test face", bold: true)) {=>
                area.layout(ctx, Rect(0.0, 0.0, 500.0, 200.0))
                ctx.focus("inherited-area")
                area.draw(ctx)
                let height = renderer.textHeight(pointSize: size, style: FontStyle(bold: true),
                    font: "Custom test face")
                let width = renderer.textWidth("a你", pointSize: size, style: FontStyle(bold: true),
                    font: "Custom test face")
                let caret = ctx.textInputAnchorRect().getOrThrow()
                @Expect(abs(caret.h - height) < 0.01)
                @Expect(abs(caret.x - (8.0 + width)) < 0.01)
                var sawText = false
                for (command in renderer.drawIr()) {
                    if (command.kind == "text") {
                        sawText = true
                        @Expect(command.data.contains("\"pointSize\":" + size.toString()))
                        @Expect(command.data.contains("Custom test face"))
                    }
                }
                @Expect(sawText)
                let first = renderer.textWidth("a", pointSize: size, style: FontStyle(bold: true),
                    font: "Custom test face")
                @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + first, 9.0)))
                @Expect(cursor.value, Int64(1))
                @Expect(source.value, "a你éb\n尾行")
            }
        }
    }
}

@Test
func textAreaLineHeightDrivesRowsSelectionHitAndImeWithoutChangingText(): Unit {
    for (mode in [TextAreaWrapMode.NoWrap, TextAreaWrapMode.SoftWrap]) {
        let renderer = Renderer.recordingHeadless()
        let ctx = UiContext(renderer, Theme.light())
        let source = State<String>("a你\nb好\n尾行")
        let cursor = State<Int64>(5)
        let anchor = State<Int64>(0)
        let area = TextArea(source, key: "row-height", cursor: Some(cursor), anchor: Some(anchor),
            wrapMode: mode).lineHeight(Length(52.0, LengthUnit.Vp))
        ctx.focus("row-height")
        area.layout(ctx, Rect(0.0, 0.0, 400.0, 200.0))
        area.draw(ctx)
        @Expect(ctx.textInputAnchorRect().getOrThrow().y, Float32(60.0))
        @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 8.0 + 52.0 + 2.0)))
        @Expect(cursor.value, Int64(5))
        @Expect(anchor.value, Int64(5))
        @Expect(source.value, "a你\nb好\n尾行")
    }
}

@Test
func textAreaFontHeightIsLowerBoundForExplicitRowPitch(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    ctx.withTypographyEnvironment(TypographyEnvironment(fontSize: Length(48.0, LengthUnit.Fp))) {=>
        let metrics = resolveTextAreaTypography(ctx, rowHeight: Length(1.0, LengthUnit.Vp))
        @Expect(metrics.rowHeight >= ctx.renderer.textHeight(pointSize: 48.0))
        let source = State<String>("a\nb")
        let area = TextArea(source, key: "large-row", cursor: Some(State<Int64>(2)))
            .lineHeight(Length(1.0, LengthUnit.Vp))
        area.layout(ctx, Rect(0.0, 0.0, 500.0, 250.0))
        ctx.focus("large-row")
        area.draw(ctx)
        let caret = ctx.textInputAnchorRect().getOrThrow()
        @Expect(abs(caret.y - 8.0 - metrics.rowHeight) < 0.01)
        @Expect(abs(caret.h - ctx.renderer.textHeight(pointSize: 48.0)) < 0.01)
    }
}

@Test
func textAreaTypographyChangeRevealsUnchangedCaretAndRewrapsSameEditor(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let text = State<String>("abcdefghijklmnopqrstuvwxyz\n尾行")
    let cursor = State<Int64>(26)
    let horizontal = State<Float32>(0.0)
    let area = TextArea(text, key: "dynamic-font", cursor: Some(cursor),
        horizontalScroll: Some(horizontal))
    ctx.focus("dynamic-font")
    for (size in [Float32(12.0), Float32(40.0), Float32(12.0)]) {
        ctx.withTypographyEnvironment(TypographyEnvironment(fontSize: Length(size, LengthUnit.Fp))) {=>
            area.layout(ctx, Rect(0.0, 0.0, 180.0, 150.0))
            area.draw(ctx)
            let caret = ctx.textInputAnchorRect().getOrThrow()
            @Expect(caret.x >= 8.0 && caret.right() <= 172.01)
            @Expect(abs(caret.h - ctx.renderer.textHeight(pointSize: size)) < 0.01)
            @Expect(cursor.value, Int64(26))
        }
    }
    area.wrapMode(TextAreaWrapMode.SoftWrap)
    let previousRows = State<Int64>(0)
    for (size in [Float32(12.0), Float32(40.0)]) {
        ctx.withTypographyEnvironment(TypographyEnvironment(fontSize: Length(size, LengthUnit.Fp))) {=>
            let rows = area.visualLines(ctx, 150.0)
            @Expect(rows.size > previousRows.value)
            previousRows.value = rows.size
        }
    }
}

@Test
func textAreaRejectsInvalidExplicitRowHeight(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    for (height in [Float32(0.0), Float32(-1.0), Float32(1000001.0)]) {
        var rejected = false
        try {
            TextArea(State<String>("a"), key: "invalid-row")
                .lineHeight(Length(height, LengthUnit.Vp)).layout(ctx, Rect(0.0, 0.0, 100.0, 100.0))
        } catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}
