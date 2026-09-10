package chui.text

import chui.core.{State, Theme, UiContext}
import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}

@Test
func textEditingDoesNotSplitExtendedGraphemes(): Unit {
    for (cluster in ["e\u{301}", "🇨🇳", "👩‍👩‍👧‍👦", "क्\u{937}", "각", "\r\n"]) {
        let edit = TextEditState("x" + cluster + "y")
        edit.moveLeft()
        @Expect(edit.cursor.value, Int64(1) + cluster.size)
        edit.moveLeft()
        @Expect(edit.cursor.value, Int64(1))
        edit.deleteForward()
        @Expect(edit.text.value, "xy")
        let reverse = TextEditState("x" + cluster)
        reverse.backspace()
        @Expect(reverse.text.value, "x")
    }
}

@Test
func textGraphemeHitTestingChoosesClusterMidpoint(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let frame = Rect(0.0, 0.0, 200.0, 38.0)
    // Headless measures bytes: the three-byte cluster midpoint is12.375px.
    @Expect(textFieldCursorForPoint(ctx, frame, "e\u{301}x", 18.0), Int64(0))
    @Expect(textFieldCursorForPoint(ctx, frame, "e\u{301}x", 25.0), Int64(3))
    @Expect(textFieldCursorForPoint(ctx, frame, "a\r\nb", 190.0), Int64(1))
    @Expect(textFieldCursorForPoint(ctx, frame, "a\r", 190.0), Int64(2))
}

@Test
func graphemeEditingFullControlUndoRedoAndSecureMapping(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("e\u{301}🇨🇳")
    let field = TextField(body, key: "grapheme-field")
    field.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    ctx.focus("grapheme-field")
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(body.value, "e\u{301}")
    field.undo()
    @Expect(body.value, "e\u{301}🇨🇳")
    field.redo()
    @Expect(body.value, "e\u{301}")

    let areaBody = State<String>("first\ne\u{301}🇨🇳")
    let area = TextArea(areaBody, key: "grapheme-area")
    area.layout(ctx, Rect(0.0, 0.0, 300.0, 150.0))
    ctx.focus("grapheme-area")
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(areaBody.value, "first\ne\u{301}")
    area.undo()
    @Expect(areaBody.value, "first\ne\u{301}🇨🇳")
    area.redo()
    @Expect(areaBody.value, "first\ne\u{301}")

    let secret = State<String>("e\u{301}🇨🇳")
    let secretCaret = State<Int64>(secret.value.size)
    let password = TextField(secret, key: "grapheme-secret", cursor: Some(secretCaret)).secureEntry()
    password.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    ctx.focus("grapheme-secret")
    @Expect(password.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 35.0, 16.0)))
    @Expect(secretCaret.value, Int64(3)) // First masked cluster maps back to three UTF-8 bytes.
    let _ = password.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 35.0, 16.0))
    @Expect(password.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(password.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(secretCaret.value, Int64(3))
    @Expect(password.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(secret.value, "🇨🇳")
    password.undo() // Secure entry still has no plaintext undo history.
    @Expect(secret.value, "🇨🇳")
}

@Test
func graphemeRetainedIndexReusesUnchangedTextAndRefreshesBindings(): Unit {
    let cache = TextBoundaryCache()
    let text = State<String>("e\u{301}🇨🇳")
    for (_ in 0..100) {
        let edit = TextEditState(text, State<Int64>(text.value.size), State<Int64>(text.value.size), cache)
        edit.moveLeft()
        @Expect(edit.cursor.value, Int64(3))
        edit.normalizeCursor()
    }
    @Expect(cache.rebuildCount(), UInt64(1))
    let replacement = State<String>("👩‍👩‍👧‍👦x")
    let edit = TextEditState(replacement, State<Int64>(replacement.value.size), State<Int64>(replacement.value.size), cache)
    edit.moveLeft()
    edit.backspace()
    @Expect(replacement.value, "x")
    @Expect(text.value, "e\u{301}🇨🇳") // No retained stale binding.
    @Expect(cache.rebuildCount(), UInt64(3))
}

@Test
func graphemeEditNormalizesJoiningMutationsAndVerticalOffsets(): Unit {
    let edit = TextEditState("eX\u{301}")
    edit.moveTo(1)
    edit.deleteForward() // X+accent is one cluster.
    @Expect(edit.text.value, "e")
    let join = TextEditState("\u{301}x")
    join.moveToStart()
    join.insert("e")
    @Expect(join.text.value, "e\u{301}x")
    @Expect(join.cursor.value, Int64(3))
    let lines = TextEditState("ab\ne\u{301}x")
    lines.moveTo(1)
    lines.moveLineDown()
    @Expect(lines.cursor.value, Int64(3)) // byte column1 snaps to the whole cluster.
    lines.moveToLineEnd()
    @Expect(lines.cursor.value, lines.text.value.size)
}

@Test
func textGraphemeStateRefreshAndInteriorSelection(): Unit {
    let text = State<String>("e\u{301}x")
    let cursor = State<Int64>(1)
    let edit = TextEditState(text, cursor: Some(cursor))
    @Expect(cursor.value, Int64(0))
    edit.extendRight()
    @Expect(edit.selectedText(), "e\u{301}")
    text.value = "🇨🇳z"
    edit.moveTo(4)
    @Expect(cursor.value, Int64(0))
    edit.extendRight()
    @Expect(edit.selectedText(), "🇨🇳")
}
