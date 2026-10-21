package canghui_motion_lab

import chui.*
import canghui_kit.*

public let MOTION_FAMILIES: Array<KitMotionFamily> = [KitMotionFamily.Bounce, KitMotionFamily.Digital,
    KitMotionFamily.FocusLight, KitMotionFamily.Choreography, KitMotionFamily.Archive]

public class MotionLabState {
    public let family = State<Int64>(0)
    public let replay = State<UInt64>(0)
    public let number = State<Int64>(128)
    public let shown = State<Bool>(true)
    public let dark = State<Bool>(false)
    public let reduced = State<Bool>(false)
    public let width = State<Float32>(1060.0)
    public let height = State<Float32>(820.0)

    public func repeat(): Unit {
        replay.value += 1
        shown.value = !shown.value
        number.value = if (number.value == Int64.Max) {0} else {number.value + 1}
    }
}

public func motionLabTheme(state: MotionLabState): Theme {
    let palette = kitMotionPalette(MOTION_FAMILIES[state.family.value], dark: state.dark.value)
    Theme(bg: palette.background, panel: palette.surface, panelEdge: palette.muted.withAlpha(45),
        text: palette.ink, mutedText: palette.muted, accent: palette.signal, accentText: palette.background,
        danger: Color(202, 73, 68), field: palette.surface, fieldActive: palette.surface,
        panelRaised: palette.surface, accentSoft: palette.signal.withAlpha(24),
        reduceMotion: state.reduced.value, radius: 16.0, controlRadius: 10.0)
}
