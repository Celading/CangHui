package canghui_kit_parity

import chui.*
import chui.kmode.macros.*

func flowProbe(script: String, style: Int64, width: Float32): String {
    let model = LibraryFlow()
    model.style.value = style
    model.width.value = width
    ComponentProbe("kit-parity", width: width, height: 760.0, theme: flowTheme(model)).run(script) { flowView(model) }
}

@CuiProbe["parity.base"]
func baseProbe(script: String): String { flowProbe(script, 0, 960.0) }
@CuiProbe["parity.editorial"]
func editorialProbe(script: String): String { flowProbe(script, 1, 960.0) }
@CuiProbe["parity.glass"]
func glassProbe(script: String): String { flowProbe(script, 2, 960.0) }
@CuiProbe["parity.compact"]
func compactProbe(script: String): String { flowProbe(script, 2, 360.0) }
