package chui.desktop

import sdl.system.{HintPriority, SdlHint, SdlHintSetting, SdlHints}

/** TextArea/TextField render preedit, but native IMEs still own candidate lists.
 * SDL needs this declaration before video initialization (not on first focus).
 * Hints are process-wide: preserve even an explicit empty/"none" host value.
 */
internal func applyDesktopImeDefault(): Unit {
    SdlHints.apply(desktopImeDefaults(SdlHints.get(SdlHint.ImeImplementedUi)))
}

internal func desktopImeDefaults(configured: ?String): Array<SdlHintSetting> {
    match (configured) {
        case Some(_) => []
        case None => [SdlHintSetting(SdlHint.ImeImplementedUi, "composition", priority: HintPriority.Default)]
    }
}
