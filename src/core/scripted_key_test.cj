package chui.core

import sdl.Key
@When[debug]
import sdl.input.KeyModifiers

@Test
func scriptedPlainKeysMatchSdlCodesAndHaveNoModifiers(): Unit {
    for (name in ["a", "A"]) {
        let (key, mask) = parseScriptedKeyInput(name)
        @Expect(match (key) { case Key.Letter(c) => c == UInt8(65); case _ => false })
        @Expect(mask, UInt16(0))
    }
    let (key, _) = parseScriptedKeyInput("HOME")
    @Expect(match (key) { case Key.Home => true; case _ => false })
}

@When[debug]
@Test
func scriptedChordsAreStrictAndModifiersAreNotPersistent(): Unit {
    let (key, mask) = parseScriptedKeyInput("Control+Shift+a")
    @Expect(match (key) { case Key.Letter(c) => c == UInt8(65); case _ => false })
    let modifiers = KeyModifiers(mask)
    @Expect(modifiers.ctrl && modifiers.shift && !modifiers.gui && !modifiers.alt)
    let (_, plain) = parseScriptedKeyInput("a")
    @Expect(plain, UInt16(0))
    let (_, meta) = parseScriptedKeyInput("Cmd+Option+Left")
    @Expect(KeyModifiers(meta).gui && KeyModifiers(meta).alt)
    let (_, command) = parseScriptedKeyInput("CmdOrCtrl+a")
    @Expect(KeyModifiers(command).command && !KeyModifiers(command).shift && !KeyModifiers(command).alt)
    for (bad in ["", "Ctrl+", "Ctrl++A", "+A", "Ctrl+Control+A", "Cmd+Meta+A",
        "Shift", "A+B", "Ctrl+A+B", "Ctrl +A", "Ctrl+é"]) {
        var rejected = false
        try { let _ = parseScriptedKeyInput(bad) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}

@When[!debug]
@Test
func releaseOfflineProbeDoesNotGainChordExecution(): Unit {
    var rejected = false
    try { let _ = parseScriptedKeyInput("Ctrl+A") }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}
