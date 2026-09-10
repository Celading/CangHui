package chui.desktop

@When[debug]
import chui.core.{State, Theme, UiContext, VStack}
@When[debug]
import sdl.{Key, Renderer, UiEvent}
@When[debug]
import chui.text.TextField
@When[debug]
import sdl.Rect

@When[debug]
@Test
func debugUiCancelHasNoCoordinatesAndDoesNotAcceptExtraArguments(): Unit {
    let root = VStack {}
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let cancels = State<Int64>(0)
    let runner = DebugUiScriptRunner("cancel")
    runner.observe(root, ctx, 400, 200)
    runner.executeNext(ctx, {event => match (event) {
        case UiEvent.PointerCancelled => cancels.value += 1
        case _ => @Fail("Cancel must not dispatch mouse release")
    }})
    @Expect(cancels.value, 1)
    let bad = DebugUiScriptRunner("cancel 10 20")
    bad.observe(root, ctx, 400, 200)
    bad.executeNext(ctx, {_ => cancels.value += 1})
    var rejected = false
    try { bad.executeNext(ctx, {_ => cancels.value += 1}) }
    catch (e: Exception) { rejected = e.message.contains("invalid argument count") }
    @Expect(rejected)
    @Expect(cancels.value, 1)
}

@When[debug]
@Test
func debugUiFailureStopsDispatchAndFailsCompletion(): Unit {
    let runner = DebugUiScriptRunner("key unsupported\ntext must-not-run")
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let root = VStack {}
    let dispatches = State<Int64>(0)
    runner.observe(root, ctx, 400, 200)
    runner.executeNext(ctx, {_ => dispatches.value++})
    @Expect(runner.active())
    @Expect(!ctx.shouldClose)
    runner.observe(root, ctx, 400, 200)
    var rejected = false
    try { runner.executeNext(ctx, {_ => dispatches.value++}) }
    catch (e: Exception) { rejected = e.message.contains("unsupported key") }
    @Expect(rejected)
    @Expect(!runner.active())
    @Expect(ctx.shouldClose)
    @Expect(dispatches.value, 0)
    // Completed failure is terminal, not emitted or dispatched a second time.
    runner.executeNext(ctx, {_ => dispatches.value++})
    @Expect(dispatches.value, 0)
}

@When[debug]
@Test
func debugUiDispatchExceptionIsStickyAndSuccessRemainsSuccessful(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let root = VStack {}
    let failed = DebugUiScriptRunner("text x\ntext y")
    failed.observe(root, ctx, 400, 200)
    failed.executeNext(ctx, {_ => throw Exception("consumer failure")})
    var rejected = false
    try { failed.executeNext(ctx, {_ => ()}) }
    catch (e: Exception) { rejected = e.message.contains("consumer failure") }
    @Expect(rejected)
    let goodCtx = UiContext(Renderer.headless(), Theme.light())
    let good = DebugUiScriptRunner("key Home\ntext x")
    let dispatches = State<Int64>(0)
    good.observe(root, goodCtx, 400, 200)
    good.executeNext(goodCtx, {_ => dispatches.value++})
    good.observe(root, goodCtx, 400, 200)
    good.executeNext(goodCtx, {_ => dispatches.value++})
    @Expect(good.active())
    good.executeNext(goodCtx, {_ => dispatches.value++})
    @Expect(!good.active())
    @Expect(goodCtx.shouldClose)
    @Expect(dispatches.value, 3) // KeyDown + KeyUp + TextInput.
}

@When[debug]
@Test
func debugUiNamedKeyCaseUsesNativeUppercaseLetterCodes(): Unit {
    @Expect(match (parseDebugUiKey("HOME")) { case Key.Home => true; case _ => false })
    @Expect(match (parseDebugUiKey("Left")) { case Key.Left => true; case _ => false })
    @Expect(match (parseDebugUiKey("A")) { case Key.Letter(c) => c == UInt8(65); case _ => false })
    @Expect(match (parseDebugUiKey("a")) { case Key.Letter(c) => c == UInt8(65); case _ => false })
}

@When[debug]
@Test
func debugUiReceiptEscapesControlCharactersWithoutChangingUnicode(): Unit {
    @Expect(debugUiJsonQuote("\u{0}\u{1}\u{8}\u{c}\u{1f}仓"),
        "\"\\u0000\\u0001\\u0008\\u000c\\u001f仓\"")
    @Expect(debugUiJsonQuote("\n\r\t\"\\"), "\"\\n\\r\\t\\\"\\\\\"")
}

@When[debug]
@Test
func debugUiScriptParserKeepsOnlyBoundedCommands(): Unit {
    let commands = parseDebugUiScript("click 12 20\n\n focus field \n")

    @Expect(commands.size, 2)
    @Expect(commands[0], "click 12 20")
    @Expect(commands[1], "focus field")
}

@When[debug]
@Test
func debugUiKeyboardWorkflowUsesExplicitModifiersForRealTextField(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("a你b")
    let field = TextField(text, key: "field")
    field.layout(ctx, Rect(0.0, 0.0, 320.0, 40.0))
    ctx.focus("field", viaKeyboard: true)
    let runner = DebugUiScriptRunner("key ctrl+a\ntext 替换\nkey ctrl+z")
    for (i in 0..3) {
        runner.observe(field, ctx, 320, 40)
        runner.executeNext(ctx, { event => let _ = field.handle(ctx, event) })
        if (i == 1) { @Expect(text.value, "替换") }
    }
    runner.executeNext(ctx, {_ => ()})
    @Expect(text.value, "a你b")
    @Expect(!runner.active())
}

@When[debug]
@Test
func debugScriptMasksOverrideAmbientScopeAndRestoreAfterFailure(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let root = VStack {}
    let runner = DebugUiScriptRunner("key Shift+End\nkey End")
    let calls = State<Int64>(0)
    let _ = ctx.withEventModifiers(Some(UInt16(256)), {=>
        for (i in 0..2) {
            runner.observe(root, ctx, 320, 100)
            runner.executeNext(ctx, {_ =>
                @Expect(ctx.keyModifiers().raw, if (i == 0) { UInt16(1) } else { UInt16(0) })
                calls.value += 1
            })
            @Expect(ctx.keyModifiers().raw, UInt16(256))
        }
        let bad = DebugUiScriptRunner("key Ctrl+A")
        bad.observe(root, ctx, 320, 100)
        bad.executeNext(ctx, {_ => throw Exception("deliberate input failure")})
        @Expect(ctx.keyModifiers().raw, UInt16(256))
        true
    })
    @Expect(calls.value, 4)
}

@When[debug]
@Test
func debugUiObservationDiffReportsFocusAndNodeChanges(): Unit {
    let before = DebugUiObservation(UInt64(1), 640, 480, "first", ["first"], ["first"])
    let after = DebugUiObservation(UInt64(2), 640, 480, "second", ["second"], ["second", "event"])

    let diff = after.diffJson(before)

    @Expect(diff.contains("\"changed\":true"))
    @Expect(diff.contains("\"added\":[\"second\"]"))
    @Expect(diff.contains("\"removed\":[\"first\"]"))
    @Expect(diff.contains("\"interactive\":{\"added\":[\"second\",\"event\"]"))
}
