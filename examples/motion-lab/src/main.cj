package canghui_motion_lab

import chui.*
import std.env.getCommandLine
import std.convert.*

private func motionArgument(name: String, fallback: String): String {
    let args = getCommandLine()
    for (i in 0..max(0, args.size - 1)) { if (args[i] == name) { return args[i + 1] } }
    fallback
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let designOutput = motionArgument("--export-native-design", "")
    if (!designOutput.isEmpty()) { exportNativeMotionDesign(designOutput); return 0 }
    let state = MotionLabState()
    state.family.value = min(Int64(4), max(Int64(0), Int64.parse(motionArgument("--family", "0"))))
    state.width.value = Float32.parse(motionArgument("--width", "1060"))
    state.height.value = Float32.parse(motionArgument("--height", "820"))
    state.dark.value = motionArgument("--theme", "light") == "dark"
    state.reduced.value = motionArgument("--reduced", "false") == "true"
    state.number.value = Int64.parse(motionArgument("--number", "128"))
    let scale = Float32.parse(motionArgument("--scale", "1"))
    let app = DesktopApp(WindowSpec("CangHui · Motion Studio", Int32(state.width.value),
        Int32(state.height.value), scale: scale), theme: motionLabTheme(state))
    app.setMinimumSize(320, 540)
    let pointerDemo = motionArgument("--pointer", "false") == "true"
    let pointerSamples = [0]
    let applied = [state.family.value, if (state.dark.value) {1} else {0}, if (state.reduced.value) {1} else {0}]
    let clock = [UInt64(0)]
    app.run {
        EventHandler(onEvent: {event =>
            match (event) {
                case UiEvent.WindowResized(w, h) =>
                    state.width.value = Float32(w); state.height.value = Float32(h)
                case UiEvent.Frame(info) =>
                    clock[0] = info.elapsedMs
                    if (pointerDemo && pointerSamples[0] < 4) {
                        app.queuePointerMove(state.width.value * 0.74,
                            if (state.width.value >= 760.0) {290.0} else {620.0})
                        pointerSamples[0] += 1
                    }
                    let dark = if (state.dark.value) {1} else {0}
                    let reduced = if (state.reduced.value) {1} else {0}
                    if (applied[0] != state.family.value || applied[1] != dark || applied[2] != reduced) {
                        app.setTheme(motionLabTheme(state))
                        applied[0] = state.family.value; applied[1] = dark; applied[2] = reduced
                    }
                case _ => ()
            }
            false
        }) { motionLabView(state) }
    }
    println("MOTION_STUDY_RESULT {\"family\":${state.family.value},\"number\":${state.number.value}," +
        "\"reduced\":${state.reduced.value},\"dark\":${state.dark.value},\"logicalTimeMs\":${clock[0]}}")
    0
}
