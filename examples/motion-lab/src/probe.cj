package canghui_motion_lab

import chui.*
import chui.kmode.macros.*

public func motionStudyProbe(script: String, width: Float32, family: Int64,
    dark!: Bool = false, reduced!: Bool = false): String {
    let state = MotionLabState()
    state.width.value = width; state.family.value = family; state.dark.value = dark
    state.reduced.value = reduced
    ComponentProbe("motion.studio", width: width, height: 900.0, theme: motionLabTheme(state)).run(script) {
        motionLabView(state)
    }
}

@CuiProbe["motion.bounce"]
func bounceProbe(script: String): String { motionStudyProbe(script, 1060.0, 0) }
@CuiProbe["motion.digital"]
func digitalProbe(script: String): String { motionStudyProbe(script, 1060.0, 1, dark: true) }
@CuiProbe["motion.light"]
func lightProbe(script: String): String { motionStudyProbe(script, 1060.0, 2) }
@CuiProbe["motion.sequence"]
func sequenceProbe(script: String): String { motionStudyProbe(script, 1060.0, 3) }
@CuiProbe["motion.archive"]
func archiveProbe(script: String): String { motionStudyProbe(script, 1060.0, 4) }
@CuiProbe["motion.compact"]
func compactMotionProbe(script: String): String { motionStudyProbe(script, 390.0, 4) }
