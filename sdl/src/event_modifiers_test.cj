package sdl

@Test
func keyboardEnvelopeRetainsEachEventMaskAfterKeyReleaseAndScaling(): Unit {
    let down = modifierEnvelope(SDL_EVENT_KEY_DOWN, UInt16(1))
    let up = modifierEnvelope(SDL_EVENT_KEY_UP, UInt16(0))
    @Expect(down.modifierMask, Some(UInt16(1)))
    @Expect(up.modifierMask, Some(UInt16(0)))
    @Expect(scaleEventEnvelope(down, 2.0).modifierMask, Some(UInt16(1)))
    @Expect(scaleEventEnvelope(up, 1.5).modifierMask, Some(UInt16(0)))
    @Expect(down.windowId.getOrThrow(), WindowId(UInt32(7)))
    @Expect(SdlEventEnvelope(None<WindowId>, UiEvent.KeyDown(Key.End, false)).modifierMask.isNone())
    for (mask in [UInt16(64), UInt16(1024), UInt16(8192)]) {
        @Expect(modifierEnvelope(SDL_EVENT_KEY_DOWN, mask).modifierMask, Some(mask))
    }
}

private func modifierEnvelope(eventType: UInt32, mask: UInt16): SdlEventEnvelope {
    let eventPtr = unsafe { LibC.malloc<SdlEvent>() }
    var envelope = SdlEventEnvelope(None<WindowId>, UiEvent.Unknown(UInt32(0)))
    try (eventResource = eventPtr.asResource()) {
        var raw = SdlKeyboardEvent()
        raw.eventType = eventType
        raw.windowID = UInt32(7)
        raw.scancode = Int32(77)
        raw.mod = mask
        unsafe { CPointer<SdlKeyboardEvent>(eventResource.value).write(raw) }
        envelope = decodeEventEnvelope(unsafe { eventResource.value.read() })
    }
    envelope
}
