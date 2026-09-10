package sdl

foreign {
    func SDL_TextInputActive(window: CPointer<Unit>): Bool
}

@When[os == "macOS"]
@Test
func nativeTextSessionPreservesRawWindowDefaultAndRejectsClosedOwner(): Unit {
    let legacy = SdlWindow(WindowSpec("Legacy text session", 120, 80, supersample: 1))
    try { @Expect(unsafe { SDL_TextInputActive(legacy.windowPtr) }) }
    finally { legacy.close() }
    let controlled = SdlWindow(WindowSpec("Controlled text session", 120, 80,
        supersample: 1), textInput: false)
    try {
        @Expect(!unsafe { SDL_TextInputActive(controlled.windowPtr) })
        controlled.setTextInputEnabled(true)
        controlled.setTextInputEnabled(true)
        @Expect(unsafe { SDL_TextInputActive(controlled.windowPtr) })
        controlled.setTextInputEnabled(false)
        controlled.setTextInputEnabled(false)
        @Expect(!unsafe { SDL_TextInputActive(controlled.windowPtr) })
    } finally { controlled.close() }
    var rejected = false
    try { controlled.setTextInputEnabled(false) }
    catch (_: IllegalStateException) { rejected = true }
    @Expect(rejected)
}
