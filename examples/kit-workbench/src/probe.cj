package canghui_kit_workbench

import chui.*
import chui.kmode.macros.*

func workbenchProbe(script: String, width: Float32, profile: Int64, dark: Bool): String {
    let state = WorkbenchState()
    state.width.value = width
    state.profile.value = profile
    state.dark.value = dark
    ComponentProbe("kit.workbench", width: width, height: 900.0, theme: workbenchTheme(state)).run(script) {
        workbenchView(state)
    }
}

@CuiProbe["kit.editorial"]
func editorialProbe(script: String): String { workbenchProbe(script, 1060.0, 0, false) }

@CuiProbe["kit.focused"]
func focusedProbe(script: String): String { workbenchProbe(script, 1060.0, 1, false) }

@CuiProbe["kit.guided"]
func guidedProbe(script: String): String { workbenchProbe(script, 1060.0, 2, true) }

@CuiProbe["kit.compact"]
func compactProbe(script: String): String { workbenchProbe(script, 390.0, 0, false) }
