package chui.controls

import sdl.{Color, FontStyle, IconName, Key, MouseButton, Rect, Renderer, Size, UiEvent}
import chui.core.{GraphemeIndex, State, Theme, UiContext}

private func graphemeRichLayout(spans: Array<RichSpan>, width: Float32): RichLayout {
    layoutResolvedRichSpans(spans, Array<Float32>(spans.size, {_ => 15.0}),
        Array<FontStyle>(spans.size, {i => spans[i].style}),
        Array<?String>(spans.size, {_ => None<String>}), width, 16.0, 3.0,
        {text, _, _, _ => Float32(text.toRuneArray().size) * 10.0}, {_, _, _ => 20.0})
}

@Test
func richGraphemeWrapKeepsAccentAndEmojiWhole(): Unit {
    let accent = graphemeRichLayout([RichSpan.text("e\u{301}x")], 10.0)
    @Expect(accent.items.size, Int64(2))
    @Expect(accent.items[0].width, Float32(20.0))
    @Expect(accent.items[1].line, Int64(1))
    let flag = graphemeRichLayout([RichSpan.text("🇨🇳x")], 10.0)
    @Expect(flag.items.size, Int64(2))
    @Expect(flag.items[0].width, Float32(20.0))
}

@Test
func richGraphemeCrossSpanReservesContinuationBeforeWrap(): Unit {
    let color = Color.rgb(200, 30, 40)
    let layout = graphemeRichLayout([RichSpan.text("Xe"),
        RichSpan.text("\u{301}", color: color).bold().onTap({=> ()}), RichSpan.text("z")], 20.0)
    @Expect(layout.items.size, Int64(4))
    @Expect(layout.items[0].line, Int64(0)) // X alone, not Xe.
    @Expect(layout.items[0].width, Float32(10.0))
    @Expect(layout.items[1].line, Int64(1)) // e+accent stays together.
    @Expect(layout.items[2].line, Int64(1))
    @Expect(layout.items[2].spanIndex, Int64(1))
    @Expect(layout.items[2].style.bold)
    @Expect(layout.items[2].color.isSome())
    @Expect(layout.items[2].onTap.isSome())
    @Expect(layout.items[3].line, Int64(2))
}

@Test
func richGraphemeCrossSpanOversizedFamilyNeverSplitsLines(): Unit {
    let layout = graphemeRichLayout([RichSpan.text("👩"), RichSpan.text("\u{200D}"),
        RichSpan.text("👩"), RichSpan.text("\u{200D}"), RichSpan.text("👧"),
        RichSpan.text("\u{200D}"), RichSpan.text("👦"), RichSpan.text("x")], 15.0)
    @Expect(layout.items.size, Int64(8))
    for (i in 0..7) { @Expect(layout.items[i].line, Int64(0)) }
    @Expect(layout.items[7].line, Int64(1))
    @Expect(layout.lineWidths[0], Float32(70.0))
}

@Test
func richGraphemeEmptySpansAndIconReset(): Unit {
    let empty = graphemeRichLayout([RichSpan.text("Xe"), RichSpan.text(""),
        RichSpan.text("\u{301}"), RichSpan.text("z")], 20.0)
    @Expect(empty.items.size, Int64(4))
    @Expect(empty.items[1].line, Int64(1))
    @Expect(empty.items[2].line, Int64(1))
    @Expect(empty.items[2].spanIndex, Int64(2))
    let icon = graphemeRichLayout([RichSpan.text("e"), RichSpan.icon(IconName.Save),
        RichSpan.text("\u{301}")], 16.0)
    @Expect(icon.items.size, Int64(3))
    @Expect(icon.items[0].line, Int64(0))
    @Expect(icon.items[1].line, Int64(1))
    @Expect(icon.items[2].line, Int64(2))
    @Expect(graphemeRichLayout([], 10.0).items.size, Int64(0))
    @Expect(graphemeRichLayout([RichSpan.text("")], 10.0).lines, Int64(0))
}

@Test
func richGraphemeStyledContinuationUsesItsOwnMetrics(): Unit {
    let spans = [RichSpan.text("Xe"), RichSpan.text("\u{301}").bold()]
    let result = layoutResolvedRichSpans(spans, [15.0, 30.0],
        Array<FontStyle>(2, {i => spans[i].style}), [None<String>, Some("accent-face")],
        30.0, 16.0, 3.0,
        {s, size, _, _ => Float32(s.toRuneArray().size) * size / 1.5},
        {size, _, _ => size + 5.0})
    @Expect(result.items.size, Int64(3))
    @Expect(result.items[1].line, Int64(1))
    @Expect(result.items[2].line, Int64(1))
    @Expect(result.items[2].width, Float32(20.0))
    @Expect(result.items[2].height, Float32(35.0))
    @Expect(result.items[2].font, Some("accent-face"))
    @Expect(result.lineWidths[1], Float32(30.0))
}

@Test
func richGraphemeEveryRuneStyleSplitMatchesGlobalClusterLines(): Unit {
    // A line is narrower than any single rune. Each global cluster must therefore occupy one line,
    // independent of style cuts, including RI parity that cannot be decided from two nearby spans.
    for (text in ["e\u{301}x", "🇦🇧🇨🇩🇪", "👩\u{200D}👩\u{200D}👧\u{200D}👦x",
        "क्\u{200D}कx", "각x", "\u{600}ax", "a\u{200D}b", "a\u{301}\u{302}b"]) {
        let runes = text.toRuneArray()
        let spans = Array<RichSpan>(runes.size, {i => RichSpan.text(runes[i].toString())})
        let layout = graphemeRichLayout(spans, 5.0)
        let index = GraphemeIndex(text)
        @Expect(layout.lines, index.count)
        @Expect(layout.items.size, runes.size)
        var offset: Int64 = 0
        for (i in 0..runes.size) {
            @Expect(layout.items[i].line, index.ordinalFloor(offset))
            @Expect(layout.items[i].spanIndex, i)
            offset += runes[i].toString().size
        }
    }
}

@Test
func richGraphemeLongWrapBoundsMeasuredPrefixes(): Unit {
    let builder = StringBuilder()
    for (_ in 0..20000) { builder.append("e\u{301}") }
    let measuredBytes = State<Int64>(0)
    let result = layoutResolvedRichSpans([RichSpan.text(builder.toString())], [15.0],
        [FontStyle()], [None<String>], 80.0, 16.0, 3.0,
        {s, _, _, _ => measuredBytes.value += s.size; Float32(s.toRuneArray().size) * 10.0},
        {_, _, _ => 20.0})
    @Expect(result.lines, Int64(5000))
    @Expect(result.items.size, Int64(5000)) // Batch each line; not one draw per grapheme.
    @Expect(measuredBytes.value < 8000000)
    for (item in result.items) { @Expect(item.width, Float32(80.0)) }
}

@Test
func richGraphemeManyStyleCutsDoNotRescanSuffixes(): Unit {
    let spans = Array<RichSpan>(1024, {i => RichSpan.text(if (i == 0) { "a" } else { "\u{301}" })})
    let measuredRunes = State<Int64>(0)
    let result = layoutResolvedRichSpans(spans, Array<Float32>(1024, {_ => 15.0}),
        Array<FontStyle>(1024, {_ => FontStyle()}), Array<?String>(1024, {_ => None<String>}),
        5.0, 16.0, 3.0,
        {s, _, _, _ => let n = s.toRuneArray().size; measuredRunes.value += n; Float32(n) * 10.0},
        {_, _, _ => 20.0})
    @Expect(result.lines, Int64(1))
    @Expect(result.items.size, Int64(1024))
    @Expect(result.width, Float32(10240.0))
    @Expect(measuredRunes.value < 8192)
}

@Test
func richGraphemeStyledLinkKeepsPointerAndKeyboardOwnership(): Unit {
    let widths: Array<Float32> = [20.0, 80.0, 320.0]
    for (width in widths) {
        let renderer = Renderer.recordingHeadless()
        let ctx = UiContext(renderer, Theme.light())
        let hits = State<Int64>(0)
        let rich = RichText([RichSpan.text("e"),
            RichSpan.text("\u{301}").onTap({=> hits.value += 1})], key: "joined-link")
        let size = rich.measure(ctx, Size(width, 200.0))
        rich.layout(ctx, Rect(0.0, 0.0, width, size.h))
        rich.draw(ctx)
        @Expect(renderer.drawIr().size, Int64(2)) // Original style/action fragments retained.
        let base = renderer.textWidth("e", pointSize: 15.0)
        let accent = renderer.textWidth("\u{301}", pointSize: 15.0)
        let x = base + accent / 2.0
        @Expect(rich.handle(ctx, UiEvent.MouseDown(MouseButton.Left, x, size.h / 2.0)))
        @Expect(rich.handle(ctx, UiEvent.MouseUp(MouseButton.Left, x, size.h / 2.0)))
        @Expect(hits.value, Int64(1))
        let ids = rich.focusableIds()
        @Expect(ids.size, Int64(1))
        ctx.focus(ids[0])
        @Expect(rich.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
        @Expect(hits.value, Int64(2))
    }
}

@Test
func richGraphemeWrappedStyledSpaceIsNotDiscarded(): Unit {
    let spans = [RichSpan.text("A "), RichSpan.text("\u{301}")]
    let layout = graphemeRichLayout(spans, 10.0)
    @Expect(layout.items.size, Int64(3))
    @Expect(layout.items[0].line, Int64(0))
    @Expect(layout.items[1].line, Int64(1))
    @Expect(layout.items[1].width, Float32(10.0))
    @Expect(layout.items[2].line, Int64(1))
    // Joining is a Unicode property, independent of a font assigning the mark zero advance.
    let units = richSpanBoundaries(spans, [15.0, 15.0], [FontStyle(), FontStyle()],
        [None<String>, None<String>], {_, _, _, _ => 0.0})
    @Expect(!units[0].space(1))
    @Expect(units[0].joinedEnd)
}
