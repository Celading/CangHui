package chui_liquid_glass_effects

import chui.*
import chui.kmode.macros.*
import canghui_style_liquid_glass.*

@CuiProbe["liquid-glass-effects"]
func liquidGlassEffectsProbe(script: String): String {
    ComponentProbe(
        "liquid-glass-effects",
        width: 920.0,
        height: 600.0,
        theme: LiquidGlass.light(tint: Color.rgb(55, 126, 246))
    ).run(script) {
        ProbeNode(
            "liquid-glass-effects-root",
            widgetType: "LiquidGlassEffectGallery",
            properties: [
                ProbeProperty("nativeProvider", "sdl-readback"),
                ProbeProperty("fallback", "deterministic-sdr"),
                ProbeProperty("shapeUnion", "unsupported"),
                ProbeProperty("frameGraph", "rev1-opt-in"),
                ProbeProperty("scene3dMode", "native-child-surface-barrier"),
                ProbeProperty("unifiedPixels", "false"),
                ProbeProperty("presentMode", "full")
            ]
        ) {
            effectGallery()
        }
    }
}
