package chui.text

import sdl.{FontStyle, FrameInfo, MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{Length, LengthUnit, State, Theme, TypographyEnvironment, UiContext}

/*
 * The headless renderer measures text as bytes * pointSize * 0.55, so with BODY = 15
 * every ASCII byte is 8.25 logical pixels wide and a CJK character (3 bytes) is 24.75.
 * That makes measurement-based hit positions exactly assertable.
 */
@Test
func clickMapsToNearestTextBoundaryForAsciiAndCjk(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(0.0, 0.0, 200.0, 38.0)

    // 12px 落在 'a'(8.25) 与 'ab'(16.5) 中点 12.375 之前 → 光标停在字节 1
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 8.0 + 12.0), 1)
    // 点在整行文字右侧 → 光标到末尾
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 8.0 + 100.0), 3)
    // CJK：30px 在 '你'(24.75) 与 '你好'(49.5) 中点 37.125 之前 → 第一个字符之后（字节 3）
    @Expect(textFieldCursorForPoint(ctx, frame, "你好", 8.0 + 30.0), 3)
    // 空文本安全返回 0
    @Expect(textFieldCursorForPoint(ctx, frame, "", 8.0 + 10.0), 0)
    // 点击 x 在文本起点左侧 → 光标 0
    @Expect(textFieldCursorForPoint(ctx, frame, "abc", 0.0), 0)
}

@Test
func textFieldHitTestingUsesResolvedTypographyMetrics(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(0.0, 0.0, 200.0, 38.0)
    let small = TextFieldTypography(pointSize: 10.0)
    let large = TextFieldTypography(pointSize: 20.0, style: FontStyle(bold: true))

    // The same visual x lands later in a small run than a large bold run. Both
    // remain valid UTF-8 byte boundaries because the midpoint walk is unchanged.
    let targetX = Float32(22.0)
    let smallCursor = textFieldCursorForPoint(ctx, frame, "abcd", targetX, typography: small)
    let largeCursor = textFieldCursorForPoint(ctx, frame, "abcd", targetX, typography: large)
    @Expect(smallCursor, Int64(3))
    @Expect(largeCursor, Int64(1))
}

@Test
func textFieldSelectionAndCaretShareResolvedTypographyMetrics(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let frame = Rect(10.0, 20.0, 200.0, 50.0)
    let typography = TextFieldTypography(pointSize: 24.0, style: FontStyle(bold: true),
        font: "CangHui Typography Probe")
    let expectedPrefix = renderer.textWidth("ab", pointSize: typography.pointSize,
        style: typography.style, font: typography.font)
    let expectedHeight = renderer.textHeight(pointSize: typography.pointSize,
        style: typography.style, font: typography.font)

    drawTextFieldSelection(ctx, frame, "abcd", 0, 2, typography: typography)
    let selection = renderer.drawIr()[0]
    @Expect(selection.kind, "paint.fill")
    @Expect(selection.data.contains("\"width\":"))
    @Expect(selection.data.contains("\"height\":" + expectedHeight.toString()))
    let defaultRenderer = Renderer.recordingHeadless()
    drawTextFieldSelection(UiContext(defaultRenderer, Theme.light()), frame, "abcd", 0, 2)
    @Expect(selection.data != defaultRenderer.drawIr()[0].data)

    ctx.focus("typed-field")
    drawTextFieldCursor(ctx, frame, "typed-field", "abcd", 2, typography: typography)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x, frame.x + Float32(8.0) + expectedPrefix)
    @Expect(caret.h, expectedHeight)
}

@Test
func textFieldValueAndPlaceholderPaintInheritedTypography(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let value = TextField(State<String>("value"), key: "typed-value")
    let placeholder = TextField(State<String>(""), key: "typed-placeholder", placeholder: "hint")
    value.layout(ctx, Rect(0.0, 0.0, 240.0, 44.0))
    placeholder.layout(ctx, Rect(0.0, 50.0, 240.0, 44.0))

    ctx.withTypographyEnvironment(TypographyEnvironment(
        fontFamily: "CangHui Typography Probe",
        fontSize: Length(18.0, LengthUnit.Fp),
        bold: true
    )) {=> value.draw(ctx) }
    ctx.withTypographyEnvironment(TypographyEnvironment(
        fontFamily: "CangHui Typography Probe",
        fontSize: Length(27.0, LengthUnit.Fp),
        italic: true
    )) {=> placeholder.draw(ctx) }

    var sawValue = false
    var sawPlaceholder = false
    for (command in renderer.drawIr()) {
        if (command.kind == "text" && command.data.contains("\"text\":\"value\"")) {
            sawValue = command.data.contains("\"pointSize\":18.000000") &&
                command.data.contains("\"font\":\"CangHui Typography Probe\"") &&
                command.data.contains("\"bold\":true")
        }
        if (command.kind == "text" && command.data.contains("\"text\":\"hint\"")) {
            sawPlaceholder = command.data.contains("\"pointSize\":27.000000") &&
                command.data.contains("\"font\":\"CangHui Typography Probe\"") &&
                command.data.contains("\"italic\":true")
        }
    }
    @Expect(sawValue)
    @Expect(sawPlaceholder)
}

@Test
func secureTextFieldInheritedTypographyKeepsSourceByteOffsets(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("你a")
    let cursor = State<Int64>(0)
    let anchor = State<Int64>(0)
    let widget = TextField(text, key: "secure-typed", cursor: Some(cursor), anchor: Some(anchor))
        .secureEntry()
        .fontSize(30.0)
    let _ = widget.measure(ctx, Size(220.0, 50.0))
    widget.layout(ctx, Rect(0.0, 0.0, 220.0, 50.0))

    // The masked bullet is measured at 30fp, while the resulting cursor is mapped
    // back to the source string: after 你 is byte 3, not display byte 3 by accident.
    @Expect(widget.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 38.0, 20.0)))
    @Expect(cursor.value, Int64(3))
    @Expect(anchor.value, Int64(3))
}

@Test
func cursorBlinksInPhaseWithSharedFrameClock(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())

    // 530ms 相位：[0, 530) 可见，[530, 1060) 隐藏，然后循环
    ctx.frame = FrameInfo(UInt64(0), UInt64(0))
    @Expect(textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(529), UInt64(0))
    @Expect(textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(530), UInt64(0))
    @Expect(!textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(1059), UInt64(0))
    @Expect(!textCursorVisible(ctx))
    ctx.frame = FrameInfo(UInt64(1060), UInt64(0))
    @Expect(textCursorVisible(ctx))
}

// A focused text control reports its caret rectangle as the IME anchor during draw — in
// BOTH blink phases (the phase only gates painting) — so the shell can keep the candidate
// window at the caret. Without focus nothing is reported.
@Test
func focusedCaretReportsImeAnchorInBothBlinkPhases(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(10.0, 20.0, 200.0, 38.0)

    // Unfocused: no anchor.
    drawTextFieldCursor(ctx, frame, "field", "abc", 3)
    @Expect(ctx.textInputAnchorRect().isNone())

    // Focused, visible phase: the anchor is the caret rect (x = 10 + 8 pad + 3*8.25).
    ctx.focus("field")
    ctx.frame = FrameInfo(UInt64(0), UInt64(0))
    drawTextFieldCursor(ctx, frame, "field", "abc", 3)
    let visiblePhase = ctx.textInputAnchorRect().getOrThrow()
    @Expect(visiblePhase.x, Float32(42.75))

    // Hidden phase: painting is skipped but the anchor is still reported.
    ctx.clearTextInputAnchor()
    ctx.frame = FrameInfo(UInt64(530), UInt64(530))
    drawTextFieldCursor(ctx, frame, "field", "abc", 3)
    let hiddenPhase = ctx.textInputAnchorRect().getOrThrow()
    @Expect(hiddenPhase.x, Float32(42.75))

    // The anchor follows the caret byte position.
    ctx.clearTextInputAnchor()
    drawTextFieldCursor(ctx, frame, "field", "abc", 1)
    @Expect(ctx.textInputAnchorRect().getOrThrow().x, Float32(26.25))
}

// A focused caret blinks on the frame clock, so drawing it must request the next frame — otherwise the
// dirty-frame loop (档 0) would idle and freeze the blink. An unfocused field asks for nothing.
@Test
func focusedCaretRequestsContinuousFrame(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(0.0, 0.0, 200.0, 38.0)

    let _ = ctx.takeFrameRequest()
    drawTextFieldCursor(ctx, frame, "field", "abc", 1)
    @Expect(!ctx.takeFrameRequest()) // unfocused: no request

    ctx.focus("field")
    let _ = ctx.takeFrameRequest()
    drawTextFieldCursor(ctx, frame, "field", "abc", 1)
    @Expect(ctx.takeFrameRequest()) // focused: keep frames flowing for the blink
}
