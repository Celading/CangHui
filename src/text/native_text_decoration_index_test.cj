package chui.text

import chui.core.{NativeTextIndex, NativeTextScalarIndex, State}
import sdl.{Color, Fonts, SdlWindow, WindowSpec}
import sdl.text.{NativeTextColorSpan, NativeTextLineSpec}

// Deliberately uses the real normalized decoration owner, not a replacement
// tokenizer or hard-coded native offsets in the handoff to the native spec.
private func scalarDecorationFixture(): NativeTextLineSpec {
    let text = State<String>("A😀e\u{301}👩\u{200D}👧אבג")
    let color = Color.rgb(210, 30, 40)
    let source = State<TextAreaDecorationSnapshot>(TextAreaDecorationSnapshot(text.revision, [
        TextAreaDecoration(6, 8, TextAreaDecorationStyle(foreground: Some(color))),
        TextAreaDecoration(12, 15, TextAreaDecorationStyle(foreground: Some(color))),
        TextAreaDecoration(19, 21, TextAreaDecorationStyle(foreground: Some(color)))
    ]))
    let runs = TextAreaDecorationCache().visibleRuns(text.value, text.revision, Some(source), 0, 1)
    let index = NativeTextScalarIndex(text.value)
    let spans = Array<NativeTextColorSpan>(runs.size, {i =>
        NativeTextColorSpan(index.utf16OffsetForByte(runs[i].startByte).getOrThrow(),
            index.utf16OffsetForByte(runs[i].endByte).getOrThrow(), 210, 30, 40, 255)
    })
    NativeTextLineSpec(text.value, colors: spans, red: 30, green: 30, blue: 30)
}

@Test
func nativeScalarDecorationRangesPreserveRealTextAreaCodePointContract(): Unit {
    let spec = scalarDecorationFixture()
    let spans = spec.colors()
    @Expect(spans.size, Int64(3))
    for ((i, start, end) in [(Int64(0), Int64(4), Int64(5)), (1, 7, 8), (2, 10, 11)]) {
        @Expect(spans[i].start, start)
        @Expect(spans[i].end, end)
    }
    // Using editor rounding would silently enlarge/shrink these paint ranges.
    let editor = NativeTextIndex(spec.text)
    @Expect(editor.utf16OffsetForByte(6), Int64(3))
    @Expect(editor.utf16OffsetForByte(12), Int64(5))
}

@When[os == "macOS"]
@Test
func nativeScalarDecorationMappingFeedsOneActualStyledLine(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Native scalar decoration ranges", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let spec = scalarDecorationFixture()
        let index = NativeTextScalarIndex(spec.text)
        r.resetTextMeasureCount()
        @Expect(r.textSize(spec, pointSize: 24.0).getOrThrow().w > 20.0)
        for (span in spec.colors()) {
            let bytes = index.byteOffsetForUtf16(span.start).getOrThrow()
            @Expect(index.utf16OffsetForByte(bytes), Some(span.start))
            @Expect(r.textCaretPositionsUtf16(spec, span.start, pointSize: 24.0).isSome())
            @Expect(r.textSelectionSpansUtf16(spec, span.start, span.end, pointSize: 24.0).isSome())
        }
        @Expect(r.text(spec, 10.0, 10.0, pointSize: 24.0))
        @Expect(r.textShapeCount(), UInt64(1))
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}
