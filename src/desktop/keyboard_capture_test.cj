package chui.desktop

import sdl.{Key, SdlEventEnvelope, UiEvent, WindowSpec, TextCompositionEvent, TextCompositionPhase}
import chui.core.{State, VStack, Button}
import chui.text.{TextField, TextCompositionSnapshot}

@Test
func managedWindowPhysicalTabReachesOptedInFocusedControlOnce(): Unit {
    let count = State<Int64>(0)
    let mask = State<UInt16>(0)
    let app = DesktopApplication()
    try {
        let id = app.openWindow(WindowSpec("Focused keyboard contract", 320, 200, vsync: false, supersample: 1), {=>
            VStack {
                TextField(State<String>(""), key: "terminal").autofocus().captureKeyboard({ctx, event =>
                    match (event) {
                        case UiEvent.KeyDown(Key.Tab, _) =>
                            count.value += 1
                            mask.value = ctx.keyModifiers().raw
                            true
                        case _ => false
                    }
                })
                Button("Next", {=> ()}).key("next")
            }
        })
        let _ = app.route(SdlEventEnvelope(Some(id), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(0))))
        @Expect(count.value, Int64(1))
        @Expect(app.windowState(id).getOrThrow().focusId, "terminal")
        let _ = app.route(SdlEventEnvelope(Some(id), UiEvent.KeyUp(Key.Tab), modifierMask: Some(UInt16(0))))
        let _ = app.route(SdlEventEnvelope(Some(id), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(1))))
        @Expect(count.value, Int64(2))
        @Expect(mask.value, UInt16(1))
        let _ = app.route(SdlEventEnvelope(Some(id), UiEvent.KeyUp(Key.Tab), modifierMask: Some(UInt16(0))))
        let _ = app.route(SdlEventEnvelope(Some(id), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(64))))
        @Expect(count.value, Int64(2))
        @Expect(app.windowState(id).getOrThrow().focusId, "next")
    } finally { app.close() }
}

@Test
func managedKeyboardCaptureSeparatesImeClipboardAndInactiveWindow(): Unit {
    let count = State<Int64>(0)
    let shortcut = State<Int64>(0)
    let text = State<String>("")
    let composition = State<TextCompositionSnapshot>(TextCompositionSnapshot())
    let app = DesktopApplication()
    try {
        let first = app.openWindow(WindowSpec("Captured IME", 320, 200, vsync: false, supersample: 1), {=>
            TextField(text, key: "terminal", composition: Some(composition)).autofocus()
                .captureKeyboard({ctx, event => match (event) {
                    case UiEvent.KeyDown(Key.Tab, _) => count.value += 1; true
                    case UiEvent.KeyDown(Key.Letter(letter), _) where ctx.keyModifiers().ctrl =>
                        if (letter == UInt8(67) || letter == UInt8(86)) { shortcut.value += 1; true } else { false }
                    case _ => false
                }})
        })
        let second = app.openWindow(WindowSpec("Ordinary field", 320, 200, vsync: false, supersample: 1), {=>
            VStack {
                TextField(State<String>(""), key: "ordinary").autofocus()
                Button("Next", {=> ()}).key("next")
            }
        })
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(0))))
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.WindowFocusChanged(false)))
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.WindowFocusChanged(true)))
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Tab, true)))
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(0))))
        @Expect(app.windowState(second).getOrThrow().focusId, "next")
        @Expect(count.value, 1)
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.WindowFocusChanged(true)))
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyUp(Key.Tab)))
        @Expect(count.value, 1)
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.TextComposition(
            TextCompositionEvent(TextCompositionPhase.Begin, text: "新"))))
        @Expect(composition.value.active)
        @Expect(text.value, "")
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.TextInput("新")))
        @Expect(text.value, "新")
        for (letter in [UInt8(67), UInt8(86)]) {
            let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Letter(letter), false),
                modifierMask: Some(UInt16(64))))
        }
        @Expect(shortcut.value, 2)
        @Expect(text.value, "新")
        @Expect(count.value, 1)
    } finally { app.close() }
}
