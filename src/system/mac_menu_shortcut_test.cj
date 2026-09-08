package chui.system

@Test
func macMenuShortcutsPreserveCommandControlAndShiftMeaning(): Unit {
    let empty = macMenuShortcut(None)
    @Expect(empty[0], ""); @Expect(empty[1], Int64(0))
    let command = macMenuShortcut(Some("CmdOrCtrl+O"))
    @Expect(command[0], "o"); @Expect(command[1], Int64(1048576))
    let control = macMenuShortcut(Some("Ctrl+Shift+O"))
    @Expect(control[0], "o"); @Expect(control[1], Int64(393216))
    let plus = macMenuShortcut(Some("Cmd+Option+Plus"))
    @Expect(plus[0], "+"); @Expect(plus[1], Int64(1572864))
    let enter = macMenuShortcut(Some("Cmd+Enter"))
    @Expect(enter[0], "\r"); @Expect(enter[1], Int64(1048576))
    let space = macMenuShortcut(Some("Space"))
    @Expect(space[0], " "); @Expect(space[1], Int64(0))
}

@Test
func macMenuShortcutsRejectIncompleteUnknownAndDuplicateModifiers(): Unit {
    for (text in ["", "Cmd+", "Cmd+Meta+K", "Super+K", "Ctrl++K", "Control+Ctrl+K", "Command+UnknownKey", "\u{0}"]) {
        var threw = false
        try { let _ = macMenuShortcut(Some(text)) } catch (_: IllegalArgumentException) { threw = true }
        @Expect(threw)
    }
}
