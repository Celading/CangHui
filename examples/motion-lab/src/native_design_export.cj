package canghui_motion_lab

import chui.*
import std.fs.File

/** Source-owned, deterministic sampling through a borrowed native renderer. */
public func exportNativeMotionDesign(directory: String): Unit {
    for (width in [Int32(390), Int32(1060)]) {
        let window = SdlWindow(WindowSpec("Motion design capture", width, 900, supersample: 1))
        try {
            window.renderer.setDrawIrRecording(true)
            for (family in 0..5) {
                for (dark in [false, true]) {
                    for (reduced in [false, true]) {
                        for (time in [Int64(0), Int64(160), Int64(480), Int64(1600)]) {
                            let state = MotionLabState()
                            state.width.value = Float32(width); state.height.value = 900.0
                            state.family.value = family; state.dark.value = dark; state.reduced.value = reduced
                            let script = "@cui-design-snapshot-v2-computed\nmove 760 290\nadvance ${time}"
                            let snapshot = ComponentProbe("motion.${family}", width: Float32(width), height: 900.0,
                                theme: motionLabTheme(state), renderer: Some(window.renderer)).run(script) {
                                motionLabView(state)
                            }
                            let key = "family-${family}-w${width}-dark${dark}-reduced${reduced}-t${time}"
                            File.writeTo(directory + "/" + key + ".json", snapshot.toArray())
                            if (time == 1600) { window.renderer.captureBmp(directory + "/" + key + ".bmp") }
                        }
                    }
                }
            }
        } finally { window.close() }
    }
}
