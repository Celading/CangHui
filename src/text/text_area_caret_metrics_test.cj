package chui.text

import chui.core.{CUI_SMALL_H, State, Theme, UiContext}
import sdl.{FontSizes, Fonts, FrameInfo, Rect, Renderer, SdlWindow, WindowSpec,
    TextCompositionEvent, TextCompositionPhase, UiEvent}
import std.math.abs

@Test
func wrappedCaretMetricsMatchGlyphsAndUnwrappedArea(): Unit {
    for (source in ["", "abc DEF", "中文，Latin", "é👩‍💻"]) {
        for (mode in [TextAreaWrapMode.SoftWrap, TextAreaWrapMode.NoWrap]) {
            let renderer = Renderer.recordingHeadless()
            let ctx = UiContext(renderer, Theme.light())
            let value = State<String>(source)
            let cursor = State<Int64>(source.size)
            let anchor = State<Int64>(0)
            let area = TextArea(value, key: "metric-area", cursor: Some(cursor),
                anchor: Some(anchor), wrapMode: mode)
            area.layout(ctx, Rect(10.0, 20.0, 320.0, 100.0))
            ctx.focus("metric-area")
            area.draw(ctx)
            let caret = ctx.textInputAnchorRect().getOrThrow()
            @Expect(caret.h, min(renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H))
            @Expect(caret.h > 0.0 && caret.h <= CUI_SMALL_H)
            @Expect(value.value, source)
            @Expect(cursor.value, source.size)
            @Expect(anchor.value, Int64(0))
        }
    }
}

@Test
func wrappedCaretPaintAndImeAnchorShareMetricsAcrossBlink(): Unit {
    for (clock in [UInt64(0), UInt64(530)]) {
        let renderer = Renderer.recordingHeadless()
        let ctx = UiContext(renderer, Theme.light())
        ctx.frame = FrameInfo(clock, UInt64(0))
        let layout = TextAreaWrapLayout(ctx, "你abc", 120.0)
        drawWrappedTextArea(ctx, Rect(4.0, 6.0, 120.0, 80.0), "你abc", layout,
            0.0, 3, 0, 0, [], TextAreaDisplayProjection("你abc", UInt64(0), TextCompositionSnapshot()),
            true, true)
        let caret = ctx.textInputAnchorRect().getOrThrow()
        @Expect(caret.h, min(renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H))
        @Expect(caret.y, Float32(6.0))
        var paintedCaret = false
        for (command in renderer.drawIr()) {
            if (command.kind == "paint.fill" && command.data.contains("\"width\":1.500000")) {
                paintedCaret = true
                @Expect(command.data.contains("\"height\":" + caret.h.toString()))
                @Expect(command.data.contains("\"y\":" + caret.y.toString()))
            }
        }
        @Expect(paintedCaret, clock == UInt64(0))
    }
}

@Test
func wrappedCaretResizeAndScrollKeepRowGeometryAndSourceOffsets(): Unit {
    let source = "abc中文defghijklmnopqrstuvwxyz\n尾行"
    for (width in [Float32(44.0), Float32(96.0)]) {
        for (scroll in [Float32(0.0), Float32(14.0), Float32(28.0)]) {
            let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
            let layout = TextAreaWrapLayout(ctx, source, width)
            let row = Int64(1)
            let offset = layout.lines[row].startByte
            drawWrappedTextArea(ctx, Rect(5.0, 9.0, width, 100.0), source, layout, scroll,
                offset, 0, offset, [], TextAreaDisplayProjection(source, UInt64(0), TextCompositionSnapshot()),
                true, true)
            let caret = ctx.textInputAnchorRect().getOrThrow()
            @Expect(caret.y, Float32(9.0) + CUI_SMALL_H - scroll)
            @Expect(caret.h, min(ctx.renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H))
            @Expect(layout.rowForOffset(offset), row)
            @Expect(layout.text, source)
        }
    }
}

@Test
func wrappedCaretSelectionReplacementRetainsUndoRedoTransaction(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let source = "a你b\n尾行"
    let text = State<String>(source)
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let area = TextArea(text, key: "caret-edit", cursor: Some(cursor), anchor: Some(anchor),
        wrapMode: TextAreaWrapMode.SoftWrap)
    area.layout(ctx, Rect(0.0, 0.0, 64.0, 140.0))
    ctx.focus("caret-edit")
    area.draw(ctx)
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(1))
    @Expect(area.handle(ctx, UiEvent.TextInput("好")))
    @Expect(text.value, "a好b\n尾行")
    area.draw(ctx)
    area.undo()
    @Expect(text.value, source)
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(1))
    area.redo()
    @Expect(text.value, "a好b\n尾行")
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(4))
}

@Test
func wrappedCaretPreeditDrawDoesNotCommitOrSplitHistory(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let source = "a你b"
    let text = State<String>(source)
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "caret-ime", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition), wrapMode: TextAreaWrapMode.SoftWrap)
    area.layout(ctx, Rect(0.0, 0.0, 70.0, 140.0))
    ctx.focus("caret-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "pin", selectionStart: 3))))
    area.draw(ctx)
    @Expect(text.value, source)
    @Expect(cursor.value, Int64(4))
    @Expect(anchor.value, Int64(1))
    @Expect(composition.value.active)
    @Expect(ctx.textInputAnchorRect().getOrThrow().h,
        min(ctx.renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H))
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Cancel))))
    @Expect(text.value, source)
    @Expect(!composition.value.active)
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "zhong", selectionStart: 5))))
    area.draw(ctx)
    @Expect(area.handle(ctx, UiEvent.TextInput("中")))
    @Expect(text.value, "a中b")
    @Expect(!composition.value.active)
    area.undo()
    @Expect(text.value, source)
    area.redo()
    @Expect(text.value, "a中b")
    area.wrapMode(TextAreaWrapMode.NoWrap)
    area.wrapMode(TextAreaWrapMode.SoftWrap)
    @Expect(text.value, "a中b")
}

@Test
func wrappedReadOnlyCaretDoesNotPublishEditableImeAnchor(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    let layout = TextAreaWrapLayout(ctx, "只读", 100.0)
    drawWrappedTextArea(ctx, Rect(0.0, 0.0, 100.0, 80.0), "只读", layout, 0.0,
        0, 0, 0, [], TextAreaDisplayProjection("只读", UInt64(0), TextCompositionSnapshot()), true, false)
    @Expect(ctx.textInputAnchorRect().isNone())
}

@When[os == "macOS"]
@Test
func wrappedCaretNativeAndFallbackFontMetricsKeepInputTransactions(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("TextArea caret metrics", 420, 220, supersample: 1))
    try {
        let renderer = window.renderer
        renderer.setScale(1.0)
        for (native in [false, true]) {
            @Expect(renderer.usePlatformTextLayout(native))
            let ctx = UiContext(renderer, Theme.light())
            let value = State<String>("中文 abc\n尾行")
            let cursor = State<Int64>(6)
            let anchor = State<Int64>(0)
            let area = TextArea(value, key: "native-caret-height", cursor: Some(cursor),
                anchor: Some(anchor), wrapMode: TextAreaWrapMode.SoftWrap)
            area.layout(ctx, Rect(0.0, 0.0, 180.0, 160.0))
            ctx.focus("native-caret-height")
            area.draw(ctx)
            let caret = ctx.textInputAnchorRect().getOrThrow()
            @Expect(abs(caret.h - min(renderer.textHeight(pointSize: FontSizes.BODY), CUI_SMALL_H)) < 0.01)
            @Expect(value.value, "中文 abc\n尾行")
            @Expect(area.handle(ctx, UiEvent.TextInput("字")))
            @Expect(value.value, "字 abc\n尾行")
            area.undo()
            @Expect(value.value, "中文 abc\n尾行")
            area.redo()
            @Expect(value.value, "字 abc\n尾行")
        }
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}
