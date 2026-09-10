package chui.desktop

import sdl.Rect

private class ImeAnchorCounter { var value: Int64 = 0 }

@Test
func desktopImeAnchorRetriesAnUnacknowledgedRectangle(): Unit {
    let state = TextInputAnchorState()
    let rect = Rect(10.0, 20.0, 1.5, 24.0)
    let calls = ImeAnchorCounter()
    let send = {_: Rect =>
        calls.value += 1
        if (calls.value == 1) { throw IllegalStateException("transient platform refusal") }
    }
    state.update(Some(rect), send)
    state.update(Some(rect), send)
    state.update(Some(rect), send)
    @Expect(calls.value, Int64(2))
}

@Test
func desktopImeAnchorReappliesAfterNoFocusedTextAnchor(): Unit {
    let state = TextInputAnchorState()
    let rect = Rect(10.0, 20.0, 1.5, 24.0)
    let calls = ImeAnchorCounter()
    let send = {_: Rect => calls.value += 1}
    state.update(Some(rect), send)
    state.update(None, send)
    state.update(Some(rect), send)
    @Expect(calls.value, Int64(2))
}

@Test
func desktopImeAnchorInvalidationReappliesUnchangedLogicalCoordinates(): Unit {
    let state = TextInputAnchorState()
    let rect = Rect(10.0, 20.0, 1.5, 24.0)
    let calls = ImeAnchorCounter()
    let send = {_: Rect => calls.value += 1}
    state.update(Some(rect), send)
    state.update(Some(rect), send)
    state.invalidate()
    state.update(Some(rect), send)
    @Expect(calls.value, Int64(2))
}

@Test
func desktopImeAnchorFailureInvalidatesPreviouslyAcknowledgedArea(): Unit {
    let state = TextInputAnchorState()
    let first = Rect(10.0, 20.0, 1.5, 24.0)
    let second = Rect(30.0, 20.0, 1.5, 24.0)
    let calls = ImeAnchorCounter()
    let send = {rect: Rect =>
        calls.value += 1
        if (rect.x == 30.0) { throw IllegalStateException("platform state unknown after failure") }
    }
    state.update(Some(first), send)
    state.update(Some(second), send)
    state.update(Some(first), send)
    state.update(Some(first), send)
    @Expect(calls.value, Int64(3))
}

@Test
func desktopImeAnchorStateIsWindowLocalAndDeduplicatesOnlySuccess(): Unit {
    let first = TextInputAnchorState()
    let second = TextInputAnchorState()
    let rect = Rect(10.0, 20.0, 1.5, 24.0)
    let firstCalls = ImeAnchorCounter()
    let secondCalls = ImeAnchorCounter()
    let sendFirst = {_: Rect => firstCalls.value += 1}
    let sendSecond = {_: Rect => secondCalls.value += 1}
    first.update(Some(rect), sendFirst)
    second.update(Some(rect), sendSecond)
    first.update(Some(rect), sendFirst)
    second.invalidate()
    first.update(Some(rect), sendFirst)
    second.update(Some(rect), sendSecond)
    @Expect(firstCalls.value, Int64(1))
    @Expect(secondCalls.value, Int64(2))
}
