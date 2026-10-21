package canghui_motion_lab

import chui.*
import std.env.getVariable
import std.fs.File

@Test
func sourceOwnedMotionDesignExportsPreserveObservedScenes(): Unit {
    match (getVariable("CANGHUI_MOTION_DESIGN_OUTPUT")) {
        case Some(directory) =>
            for (index in 0..5) {
                for (width in [Float32(390.0), Float32(1060.0)]) {
                    let state = MotionLabState()
                    state.width.value = width; state.family.value = index
                    let snapshot = ComponentProbe("motion.${index}", width: width, height: 900.0,
                        theme: motionLabTheme(state)).run("@cui-design-snapshot-v2-computed\nadvance 1600") {
                        motionLabView(state)
                    }
                    @Expect(snapshot.contains("canghui.design-snapshot/v2"))
                    File.writeTo(directory + "/family-${index}-w${Int64(width)}.json", snapshot.toArray())
                }
            }
        case None => ()
    }
}
