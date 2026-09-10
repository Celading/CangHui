package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Color, FontSizes, Fonts, SdlWindow, WindowSpec, Rect, Key, MouseButton, UiEvent,
    TextCompositionEvent, TextCompositionPhase}
import sdl.text.{NativeTextLineSpec, NativeTextColorSpan}
import std.math.abs

@When[os == "macOS"]
@Test
func textAreaNativeRtlCaretUsesCompleteLineInsteadOfEmptyPrefix(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Native TextArea geometry", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let ctx = UiContext(r, Theme.light())
        let value = State<String>("אבג abc DEF")
        let area = TextArea(value, key: "native-area", cursor: Some(State<Int64>(0)),
            anchor: Some(State<Int64>(0)))
        area.layout(ctx, Rect(0.0, 0.0, 400.0, 160.0))
        ctx.focus("native-area")
        area.draw(ctx)
        let expected = r.textCaretPositionsUtf16(NativeTextLineSpec(value.value), 0,
            pointSize: FontSizes.BODY).getOrThrow()[0]
        @Expect(expected > 20.0)
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - expected) < 0.1)
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}

private func withNativeAreaContext(body: (UiContext) -> Unit): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Native TextArea flow", 520, 260, supersample: 1))
    try {
        window.renderer.setScale(1.0)
        @Expect(window.renderer.usePlatformTextLayout(true))
        body(UiContext(window.renderer, Theme.light()))
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}

@When[os == "macOS"]
@Test
func textAreaNativeClickVisualArrowsEditUndoAndRowMotionAgree(): Unit {
    withNativeAreaContext { ctx =>
        let original = "abc אבג def\nאבג"
        let value = State<String>(original)
        let cursor = State<Int64>(0)
        let anchor = State<Int64>(0)
        let area = TextArea(value, key: "native.flow", cursor: Some(cursor), anchor: Some(anchor))
        area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0))
        let r = ctx.renderer
        let spec = NativeTextLineSpec("abc אבג def")
        let boundary = r.textCaretPositionsUtf16(spec, Int64(4)).getOrThrow()
        @Expect(abs(boundary[0] - boundary[1]) > 10.0)
        @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + boundary[1], 15.0)))
        area.draw(ctx)
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - boundary[1]) < 0.1)
        let interior = r.textCaretPositionsUtf16(spec, Int64(5)).getOrThrow()[0]
        @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + interior, 15.0)))
        @Expect(cursor.value, Int64(6))
        @Expect(area.handle(ctx, UiEvent.TextInput("X")))
        @Expect(value.value, "abc אXבג def\nאבג")
        area.undo()
        @Expect(value.value, original)
        area.redo()
        @Expect(value.value, "abc אXבג def\nאבג")
        value.value = "אבג\nאבג"; cursor.value = 0; anchor.value = 0
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
        @Expect(cursor.value, Int64(2))
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
        @Expect(cursor.value, Int64(9))
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
        @Expect(cursor.value, Int64(2))
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
        @Expect(cursor.value, Int64(0))
        // Plain arrows collapse an existing selection to its visual edge;
        // they must not first move one character inside the selected range.
        cursor.value = 6; anchor.value = 0
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
        @Expect(cursor.value, Int64(0))
        @Expect(anchor.value, Int64(0))
        cursor.value = 6; anchor.value = 0
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
        @Expect(cursor.value, Int64(6))
        @Expect(anchor.value, Int64(6))
    }
}

@When[os == "macOS"]
@Test
func textAreaNativeCompositionUsesDisplayedLineWithDurableOffsets(): Unit {
    withNativeAreaContext { ctx =>
        let value = State<String>("a原\n字b😀")
        let cursor = State<Int64>(8)
        let anchor = State<Int64>(1)
        let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
        let area = TextArea(value, key: "native.preedit", cursor: Some(cursor), anchor: Some(anchor),
            composition: Some(composition))
        area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0))
        ctx.focus("native.preedit")
        @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(TextCompositionPhase.Begin,
            text: "אבג", selectionStart: 2))))
        area.draw(ctx)
        let shown = NativeTextLineSpec("aאבגb😀")
        let expected = ctx.renderer.textCaretPositionsUtf16(shown, Int64(3)).getOrThrow()[0]
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - expected) < 0.1)
        @Expect(value.value, "a原\n字b😀")
        @Expect(cursor.value, Int64(8))
        @Expect(anchor.value, Int64(1))
        @Expect(area.handle(ctx, UiEvent.TextInput("拼")))
        @Expect(value.value, "a拼b😀")
        area.undo()
        @Expect(value.value, "a原\n字b😀")
    }
}

@When[os == "macOS"]
@Test
func textAreaNativeDecorationsShareExactScalarGeometryAndRepaint(): Unit {
    withNativeAreaContext { ctx =>
        let value = State<String>("אבג e\u{301}")
        let red = Color.rgb(210, 30, 40)
        let decorations = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(value.revision, [
            TextAreaDecoration(2, 4, TextAreaDecorationStyle(foreground: Some(red),
                background: Some(Color.rgba(30, 80, 200, 120)), underline: Some(red))),
            TextAreaDecoration(8, 10, TextAreaDecorationStyle(foreground: Some(red)))
        ]))
        let cursor = State<Int64>(2)
        let area = TextArea(value, key: "native.colors", cursor: Some(cursor),
            anchor: Some(State<Int64>(0)), decorations: Some(decorations))
        area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0))
        ctx.focus("native.colors")
        area.draw(ctx)
        let color = ctx.theme.text
        let spec = NativeTextLineSpec(value.value, colors: [
            NativeTextColorSpan(1, 2, red.r, red.g, red.b, red.a),
            NativeTextColorSpan(5, 6, red.r, red.g, red.b, red.a)],
            red: color.r, green: color.g, blue: color.b, alpha: color.a)
        let x = ctx.renderer.textCaretPositionsUtf16(spec, Int64(1)).getOrThrow()[0]
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - x) < 0.1)
        let shapes = ctx.renderer.textShapeCount()
        for (_ in 0..4) { area.draw(ctx) }
        @Expect(ctx.renderer.textShapeCount(), shapes)
        // A new source starts at the same revision: identity still matters.
        let replacement = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(value.revision, []))
        let _ = area.decorations(replacement)
        area.draw(ctx)
        let plain = NativeTextLineSpec(value.value, red: color.r, green: color.g, blue: color.b, alpha: color.a)
        let plainX = ctx.renderer.textCaretPositionsUtf16(plain, Int64(1)).getOrThrow()[0]
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - plainX) < 0.1)
    }
}

@When[os == "macOS"]
@Test
func textAreaNativeEmptyCrLfAndGraphemeBoundariesRemainEditable(): Unit {
    withNativeAreaContext { ctx =>
        let value = State<String>("")
        let cursor = State<Int64>(0)
        let anchor = State<Int64>(0)
        let area = TextArea(value, key: "native.empty", cursor: Some(cursor), anchor: Some(anchor))
        ctx.focus("native.empty")
        area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0))
        area.draw(ctx)
        @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0) < 0.1)
        @Expect(ctx.textInputAnchorRect().getOrThrow().h > 0.0)
        value.value = "a\r\n\r\n👩‍👩‍👧‍👦x"
        cursor.value = 5; anchor.value = 5
        area.draw(ctx)
        for (x in 0..70) {
            @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + Float32(x), 70.0)))
            @Expect(cursor.value == 5 || cursor.value == value.value.size - 1 || cursor.value == value.value.size)
        }
        cursor.value = value.value.size - 1; anchor.value = cursor.value
        @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
        @Expect(value.value, "a\r\n\r\nx")
    }
}

@Test
func textAreaNativeDecorationCacheRejectsDifferentSnapshotWithEqualRevision(): Unit {
    let value = State<String>("abc")
    let cache = TextAreaDecorationCache()
    let first = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(value.revision, [
        TextAreaDecoration(0, 1, TextAreaDecorationStyle(foreground: Some(Color.rgb(200, 20, 30))))]))
    let second = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(value.revision, [
        TextAreaDecoration(1, 3, TextAreaDecorationStyle(foreground: Some(Color.rgb(20, 200, 30))))]))
    @Expect(first.revision, second.revision)
    let before = cache.visibleRuns(value.value, value.revision, Some(first), 0, 1)
    let after = cache.visibleRuns(value.value, value.revision, Some(second), 0, 1)
    @Expect(before[0].startByte, Int64(0))
    @Expect(after[0].startByte, Int64(1))
    @Expect(after[0].endByte, Int64(3))
}

@Test
func textAreaNativeLineModelPreservesEmptyAndTerminalRows(): Unit {
    for ((text, count) in [("", Int64(1)), ("\n", 2), ("a\n\nb\n", 4), ("\r\n\r\n", 3)]) {
        let document = TextAreaNativeDocument(text, [], Color.rgb(0, 0, 0))
        @Expect(document.lines.size, count)
        @Expect(document.row(text.size), count - 1)
        @Expect(document.lines[document.lines.size - 1].start, text.size)
    }
}

@When[os == "macOS"]
@Test
func textAreaNativeLongDocumentDoesNotReshapeAllRowsOnEveryFrame(): Unit {
    withNativeAreaContext { ctx =>
        let out = StringBuilder()
        for (i in 0..200) { out.append("row ${i} · אבג · 仓绘\n") }
        let value = State<String>(out.toString())
        let area = TextArea(value, key: "native.long", cursor: Some(State<Int64>(0)),
            anchor: Some(State<Int64>(0)))
        ctx.focus("native.long")
        area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0))
        area.draw(ctx)
        let before = ctx.renderer.textShapeCount()
        for (_ in 0..5) { area.layout(ctx, Rect(0.0, 0.0, 480.0, 200.0)); area.draw(ctx) }
        @Expect(ctx.renderer.textShapeCount(), before)
        let oldKey = ctx.renderer.textLayoutEnvironmentKey()
        ctx.renderer.setScale(2.0)
        @Expect(oldKey != ctx.renderer.textLayoutEnvironmentKey())
        area.draw(ctx)
        @Expect(ctx.renderer.textShapeCount() > before)
        let scaled = ctx.renderer.textShapeCount()
        for (_ in 0..5) { area.draw(ctx) }
        @Expect(ctx.renderer.textShapeCount(), scaled)
    }
}
