package chui.text

import sdl.{Fonts, Key, MouseButton, Rect, SdlWindow, UiEvent, WindowSpec}
import chui.core.{State, Theme, UiContext}
import std.math.abs

@Test
func nativeBoundaryMappingIsLazyPerControlAndResetsAffinityOnTextChange(): Unit {
    let cache = TextBoundaryCache()
    let _ = cache.index("hello")
    @Expect(cache.nativeRebuildCount(), UInt64(0))
    let first = cache.nativeIndex("👩‍👩‍👧‍👦x")
    @Expect(first.graphemes.count, Int64(2))
    cache.rememberAffinity(0, true)
    for (_ in 0..100) { let _ = cache.nativeIndex("👩‍👩‍👧‍👦x") }
    @Expect(cache.nativeRebuildCount(), UInt64(1))
    @Expect(cache.usesSecondary(0))
    let _ = cache.nativeIndex("changed")
    @Expect(cache.nativeRebuildCount(), UInt64(2))
    @Expect(!cache.usesSecondary(0))
}

@When[os == "macOS"]
@Test
func nativeTextFieldClickCaretEditingAndVisualArrowsAgree(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Native TextField flow", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let ctx = UiContext(r, Theme.light())
        let original = "abc אבג def"
        let value = State<String>(original)
        let cursor = State<Int64>(0)
        let anchor = State<Int64>(0)
        let field = TextField(value, key: "native.field", cursor: Some(cursor), anchor: Some(anchor))
        let frame = Rect(0.0, 0.0, 380.0, 38.0)
        field.layout(ctx, frame)
        let target = r.createTargetTexture(420.0, 180.0)
        try {
            let boundary = r.textCaretPositionsUtf16(original, Int64(4)).getOrThrow()
            @Expect(abs(boundary[0] - boundary[1]) > 10.0)
            @Expect(field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + boundary[1], 20.0)))
            r.renderToTexture(target, 420.0, 180.0, ctx.theme.bg) { field.draw(ctx) }
            @Expect(abs(ctx.textInputAnchorRect().getOrThrow().x - 8.0 - boundary[1]) < 0.1)
            let interior = r.textCaretPositionsUtf16(original, Int64(5)).getOrThrow()[0]
            @Expect(field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + interior, 20.0)))
            @Expect(cursor.value, Int64(6)) // UTF8 bytes, not UTF16 index5.
            @Expect(field.handle(ctx, UiEvent.TextInput("X")))
            @Expect(value.value, "abc אXבג def")
            field.undo()
            @Expect(value.value, original)
            field.redo()
            @Expect(value.value, "abc אXבג def")
            value.value = "אבג"; cursor.value = 0; anchor.value = 0
            @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
            @Expect(cursor.value, Int64(2))
            @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
            @Expect(cursor.value, Int64(0))
            @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
            @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
            @Expect(value.value, "בג")
        } finally { target.close() }
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}

@When[os == "macOS"]
@Test
func nativeTextFieldRetainsGraphemeSecureAndScaleBoundaries(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Native TextField boundaries", 420, 180, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let ctx = UiContext(r, Theme.light())
        let cache = TextBoundaryCache()
        let typography = TextFieldTypography(pointSize: 24.0, boundaries: Some(cache))
        let text = "👩‍👩‍👧‍👦x"
        let frame = Rect(0.0, 0.0, 400.0, 38.0)
        for (x in 0..80) {
            let hit = textFieldCursorForPoint(ctx, frame, text, Float32(x), typography: typography)
            @Expect(hit == 0 || hit == text.size - 1 || hit == text.size)
        }
        @Expect(cache.nativeRebuildCount(), UInt64(1))
        let original = r.textCaretPositionsUtf16("سلام", Int64(2), pointSize: 24.0).getOrThrow()[0]
        let prefix = r.textWidth("سل", pointSize: 24.0)
        @Expect(abs(original - prefix) > 3.0) // Reproduces the old prefix-width defect.
        let target = r.createTargetTexture(420.0, 180.0)
        try {
            r.renderToTexture(target, 210.0, 180.0, ctx.theme.bg) {
                let scaled = textCaretOffset(ctx, "سلام", 4, typography: typography)
                @Expect(abs(scaled - original) < 1.0)
            }
        } finally { target.close() }
        let value = State<String>(text)
        let cursor = State<Int64>(0)
        let field = TextField(value, key: "native.secret", cursor: Some(cursor)).secureEntry()
        field.layout(ctx, frame)
        @Expect(field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 390.0, 20.0)))
        @Expect(cursor.value, text.size)
        @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
        @Expect(cursor.value, text.size - 1)
    } finally { window.close(); Fonts.clearBundledFallbackOverride() }
}
