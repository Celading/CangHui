package chui.desktop

import sdl.system.{HintPriority, SdlHint}

@Test
func desktopImeDeclaresOnlyTheUiItActuallyRenders(): Unit {
    let settings = desktopImeDefaults(None)
    @Expect(settings.size, Int64(1))
    @Expect(settings[0].value, "composition")
    match (settings[0].hint) {
        case SdlHint.ImeImplementedUi => ()
        case _ => @Fail("desktop IME default must target IME UI capabilities")
    }
    match (settings[0].priority) {
        case HintPriority.Default => ()
        case _ => @Fail("framework default must not override host policy")
    }
}

@Test
func desktopImePreservesEveryExplicitHostPolicy(): Unit {
    for (value in ["", "none", "0", "composition", "candidates", "composition,candidates"]) {
        @Expect(desktopImeDefaults(Some(value)).isEmpty())
    }
}
