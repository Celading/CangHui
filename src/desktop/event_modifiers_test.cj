package chui.desktop

import std.collection.ArrayList
import sdl.{SdlEventEnvelope, UiEvent, Key, WindowId, WindowSpec}
import chui.core.{State, Theme, VStack, Button}
import chui.text.TextField
import chui.controls.Modal

private class ModifierSession <: DesktopWindowSession & DesktopWindowInputSession {
    let identity: WindowId
    let masks = ArrayList<?UInt16>()
    var legacyCalls: Int64 = 0
    init(id: UInt32) { identity = WindowId(id) }
    public func windowId(): WindowId { identity }
    public func dispatch(_: UiEvent): Bool { legacyCalls += 1; false }
    public func dispatchInput(_: UiEvent, mask: ?UInt16): Bool { masks.add(mask); true }
    public func requestClose(): Unit { () }
}

@Test
func windowRegistryCarriesModifierFactsOnlyToTheAddressedSession(): Unit {
    let registry = WindowRegistry()
    let first = ModifierSession(UInt32(1))
    let second = ModifierSession(UInt32(2))
    @Expect(registry.register(first))
    @Expect(registry.register(second))
    @Expect(registry.dispatch(SdlEventEnvelope(Some(first.identity), UiEvent.KeyDown(Key.End, false),
        modifierMask: Some(UInt16(1)))).consumed)
    @Expect(registry.dispatch(SdlEventEnvelope(Some(second.identity), UiEvent.KeyDown(Key.End, false),
        modifierMask: Some(UInt16(0)))).consumed)
    @Expect(registry.dispatch(SdlEventEnvelope(Some(first.identity), UiEvent.KeyUp(Key.End),
        modifierMask: Some(UInt16(0)))).consumed)
    @Expect(first.masks.toArray(), [Some(UInt16(1)), Some(UInt16(0))])
    @Expect(second.masks.toArray(), [Some(UInt16(0))])
    @Expect(first.legacyCalls + second.legacyCalls, Int64(0))
    let collected = DesktopCollectedEvent(UiEvent.KeyDown(Key.End, false), UInt64(1),
        modifierMask: Some(UInt16(1)))
    @Expect(collected.validAt(UInt64(2)))
    @Expect(collected.modifierMask, Some(UInt16(1)))
}

@Test
func managedWindowsAndModalUseEventMasksForSelectionShortcutsAndTab(): Unit {
    let app = DesktopApplication()
    let firstCaret = State<Int64>(0)
    let firstAnchor = State<Int64>(0)
    let secondCaret = State<Int64>(0)
    let secondAnchor = State<Int64>(0)
    let open = State<Bool>(true)
    try {
        let first = app.openWindow(WindowSpec("Modifier modal A", 320, 220, vsync: false, supersample: 1), {=>
            Modal(open) {
                TextField(State<String>("a你b"), key: "first", cursor: Some(firstCaret), anchor: Some(firstAnchor)).autofocus()
                Button("One", {=> ()}).key("one")
                Button("Last", {=> ()}).key("last")
            }
        }, theme: Theme.light(reduceMotion: true))
        let second = app.openWindow(WindowSpec("Modifier window B", 320, 220, vsync: false, supersample: 1), {=>
            VStack {
                TextField(State<String>("a你b"), key: "second", cursor: Some(secondCaret), anchor: Some(secondAnchor)).autofocus()
                Button("Peer last", {=> ()}).key("peer-last")
            }
        })
        @Expect(app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.End, false), modifierMask: Some(UInt16(1)))).consumed)
        @Expect(app.route(SdlEventEnvelope(Some(second), UiEvent.KeyDown(Key.End, false), modifierMask: Some(UInt16(0)))).consumed)
        @Expect(firstCaret.value, Int64(5))
        @Expect(firstAnchor.value, Int64(0))
        @Expect(secondCaret.value, Int64(5))
        @Expect(secondAnchor.value, Int64(5))
        @Expect(app.route(SdlEventEnvelope(Some(second), UiEvent.KeyDown(Key.Letter(UInt8(65)), false), modifierMask: Some(UInt16(64)))).consumed)
        @Expect(secondAnchor.value, Int64(0))
        @Expect(app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(1)))).consumed)
        @Expect(app.windowState(first).getOrThrow().focusId, "last")
        @Expect(app.windowState(second).getOrThrow().focusId, "second")
        let _ = app.route(SdlEventEnvelope(Some(first), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(0))))
        @Expect(app.windowState(first).getOrThrow().focusId, "first")
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(1))))
        @Expect(app.windowState(second).getOrThrow().focusId, "peer-last")
        let _ = app.route(SdlEventEnvelope(Some(second), UiEvent.KeyDown(Key.Tab, false), modifierMask: Some(UInt16(0))))
        @Expect(app.windowState(second).getOrThrow().focusId, "second")
    } finally { app.close() }
}
