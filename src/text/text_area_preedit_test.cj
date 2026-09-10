package chui.text

import sdl.{Rect, Renderer, TextCompositionEvent, TextCompositionPhase, UiEvent}
import chui.core.{State, Theme, UiContext}

@Test
func preeditProjectionMapsBothSidesOfCollapsedCrLf(): Unit {
    let expected = [Int64(0), 1, 2, 2, 3]
    for (i in 0..expected.size) {
        let result = TextAreaPreeditProjection("a\r\nb", i, 0)
        @Expect(result.text, "a b")
        @Expect(result.selectionStartByte, expected[i])
        @Expect(result.selectionEndByte, expected[i])
    }
    let selected = TextAreaPreeditProjection("a\r\nb", 1, 2)
    @Expect(selected.selectionStartByte, Int64(1))
    @Expect(selected.selectionEndByte, Int64(2))
    @Expect(TextAreaPreeditProjection("\r\r\n\n", 4, 0).text, "   ")
}

@Test
func preeditProjectionPreservesScalarRatherThanGraphemeCoordinates(): Unit {
    let value = "é👩‍👩‍👧‍👦你"
    // e, combining accent, woman, ZWJ, woman, ZWJ, girl, ZWJ, boy, CJK.
    let expected = [Int64(0), 1, 3, 7, 10, 14, 17, 21, 24, 28, 31]
    for (i in 0..expected.size) {
        let result = TextAreaPreeditProjection(value, i, 0)
        @Expect(result.text, value)
        @Expect(result.selectionStartByte, expected[i])
        @Expect(result.selectionEndByte, expected[i])
    }
    let selected = TextAreaPreeditProjection(value, 2, 7)
    @Expect(selected.selectionStartByte, Int64(3))
    @Expect(selected.selectionEndByte, Int64(28))
}

@Test
func preeditProjectionClampsEndpointsWithoutIntegerOverflow(): Unit {
    let huge: Int64 = 9223372036854775807
    let beyond = TextAreaPreeditProjection("你\r\nx", huge, huge)
    @Expect(beyond.selectionStartByte, Int64(5))
    @Expect(beyond.selectionEndByte, Int64(5))
    let extended = TextAreaPreeditProjection("你\r\nx", 1, huge)
    @Expect(extended.selectionStartByte, Int64(3))
    @Expect(extended.selectionEndByte, Int64(5))
    let negative = TextAreaPreeditProjection("你", -1, -1)
    @Expect(negative.selectionStartByte, Int64(0))
    @Expect(negative.selectionEndByte, Int64(0))
    @Expect(TextAreaPreeditProjection("", huge, huge).selectionEndByte, Int64(0))
}

@Test
func textAreaPreeditAnchorUsesProjectedOffsetsAndLeavesTransactionRaw(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    let text = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let area = TextArea(text, key: "projected-ime", cursor: Some(cursor), anchor: Some(anchor),
        composition: Some(composition))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 90.0))
    ctx.focus("projected-ime")
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Begin, text: "p\r\nin", selectionStart: 3, selectionLength: 0))))
    area.draw(ctx)
    @Expect(text.value, "a你b")
    @Expect(composition.value.preedit, "p\r\nin")
    @Expect(composition.value.selectionStart, Int64(3))
    match (ctx.textInputAnchorRect()) {
        case Some(rect) => @Expect(rect.x, Float32(8.0 + 8.25 * 3.0))
        case None => @Expect(false)
    }
    @Expect(area.handle(ctx, UiEvent.TextComposition(TextCompositionEvent(
        TextCompositionPhase.Update, text: "é👩‍👩‍👧‍👦你", selectionStart: 9, selectionLength: 1))))
    @Expect(composition.value.selectionStart, Int64(9))
    @Expect(composition.value.selectionLength, Int64(1))
    @Expect(area.handle(ctx, UiEvent.TextInput("拼\n音")))
    @Expect(text.value, "a拼\n音b")
    @Expect(!composition.value.active)
    area.undo()
    @Expect(text.value, "a你b")
}
