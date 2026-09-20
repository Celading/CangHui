package canghui_macos_shell

import chui.*
import chui.kmode.macros.*

@CuiProbe["macos-shell.settings"]
func shellSettingsProbe(script: String): String {
    let radius = State<Float32>(18.0)
    let visible = State<Bool>(true)
    let message = State<String>("Native menus require a macOS desktop run.")
    ComponentProbe("macos-shell.settings", width: 620.0, height: 420.0).run(script) {
        content(radius, visible, message,
            {value: Float32 => radius.value = value},
            {=> visible.value = !visible.value},
            {=> message.value = "Close requested in probe."})
    }
}
