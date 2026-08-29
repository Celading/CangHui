# CangHui Liquid Glass Style

`canghui_style_liquid_glass` is an optional CangHui Multiplatform style pack.
It translates the public Liquid Glass design principles into CangHui's existing
`Theme`, `MaterialProvider`, `ButtonStyle`, and `ComponentTheme` extension
points without adding platform-specific policy to `chui`.

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_style_liquid_glass = { path = "../CangHui/packages/style-liquid-glass" }
```

```cangjie
import chui.*
import canghui_style_liquid_glass.*

let theme = LiquidGlass.dark()

Surface(
    shape: Shape.rounded(28.0),
    material: LiquidGlass.material(spec: LiquidGlassSpec(radius: 28.0)),
    painter: Some(LiquidGlass.surfacePainter(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        radius: 28.0,
        optics: LiquidGlassOptics(clarity: 0.94, haze: 0.18)
    )))
) {
    VStack { /* content */ }.padding(20.vp)
}
```

The first release includes light and dark palettes, regular, clear and vapor
material variants, optional tint, interactive state recipes, capsule controls,
and explicit reduced-transparency, increased-contrast, and reduced-motion
modes. `LiquidGlassOptics` separates clarity, haze, edge energy, chromatic edge
and deformation. The stock `SegmentedControl` and `TabView` retain layout,
input and focus ownership while their independently sprung lens edges stretch
and settle through the style hook.

## Rendering boundary

Liquid Glass is a dynamic optical material. CangHui's current portable SDL
renderer does not yet expose background sampling, blur, refraction, or
glass-shape union. This package therefore renders deterministic SDR optics
using gradients, mist, inner/outer highlight energy, chromatic edge hints,
shadows, semantic foregrounds and deforming foreground geometry. A future
renderer effect adapter can replace the sampled-background optical layer
without changing the public style recipe.

Use glass for navigation and important floating controls, not as the default
background for every content card. `reduceTransparency` intentionally replaces
translucent fills with opaque ones.

This package is inspired by publicly documented interaction and hierarchy
principles. It is not an Apple framework, does not include Apple assets, and
does not claim pixel identity with platform-native Liquid Glass.

Design references:

- [Apple Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
