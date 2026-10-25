package canghui_style_liquid_glass

import chui.*

/** Visual density of the optional glass material. */
public enum LiquidGlassVariant {
    | Regular
    | Clear
    | Vapor
}

/** Optical controls shared by the optional backdrop request and deterministic SDR fallback. */
public struct LiquidGlassOptics {
    public let clarity: Float32
    public let haze: Float32
    public let edgeEnergy: Float32
    public let chromaticEdge: Float32
    public let deformation: Float32
    /** Strength of the bounded local displacement field (0 = flat panel, 1 = strong lens). */
    public let displacement: Float32
    /** Lens radius as a fraction of the shorter surface edge. */
    public let lensRadius: Float32
    /** How far a capable provider may sample behind the shape, as a fraction of the surface. */
    public let sampleRadius: Float32
    /** Number of concentric edge rings used for contour depth; 1 keeps a single hairline. */
    public let edgeRings: Int64
    /** Tint strength mixed into the body independently of the backdrop. */
    public let tintStrength: Float32

    public init(
        clarity!: Float32 = 0.86,
        haze!: Float32 = 0.34,
        edgeEnergy!: Float32 = 0.88,
        chromaticEdge!: Float32 = 0.22,
        deformation!: Float32 = 0.82,
        displacement!: Float32 = 0.72,
        lensRadius!: Float32 = 0.46,
        sampleRadius!: Float32 = 0.5,
        edgeRings!: Int64 = 3,
        tintStrength!: Float32 = 0.0
    ) {
        this.clarity = clampUnit(clarity)
        this.haze = clampUnit(haze)
        this.edgeEnergy = clampUnit(edgeEnergy)
        this.chromaticEdge = clampUnit(chromaticEdge)
        this.deformation = clampUnit(deformation)
        this.displacement = clampUnit(displacement)
        this.lensRadius = clampUnit(lensRadius)
        this.sampleRadius = clampUnit(sampleRadius)
        this.edgeRings = max(1, min(6, edgeRings))
        this.tintStrength = clampUnit(tintStrength)
    }

    /** Per-variant optical profile; the three recipes must differ in optics, not only alpha. */
    public static func profile(variant: LiquidGlassVariant): LiquidGlassOptics {
        match (variant) {
            case LiquidGlassVariant.Regular => LiquidGlassOptics(
                clarity: 0.84, haze: 0.34, edgeEnergy: 0.88, chromaticEdge: 0.22,
                deformation: 0.82, displacement: 0.86, lensRadius: 0.23,
                sampleRadius: 0.5, edgeRings: 3, tintStrength: 0.10)
            case LiquidGlassVariant.Clear => LiquidGlassOptics(
                clarity: 0.97, haze: 0.10, edgeEnergy: 0.66, chromaticEdge: 0.30,
                deformation: 0.90, displacement: 1.00, lensRadius: 0.29,
                sampleRadius: 0.66, edgeRings: 2, tintStrength: 0.16)
            case LiquidGlassVariant.Vapor => LiquidGlassOptics(
                clarity: 0.62, haze: 0.72, edgeEnergy: 0.74, chromaticEdge: 0.12,
                deformation: 0.64, displacement: 0.44, lensRadius: 0.34,
                sampleRadius: 0.34, edgeRings: 4, tintStrength: 0.12)
        }
    }
}

/** User and host preferences that must win over decorative transparency and motion. */
public struct LiquidGlassPreferences {
    public let reduceTransparency: Bool
    public let increaseContrast: Bool
    public let reduceMotion: Bool

    public init(
        reduceTransparency!: Bool = false,
        increaseContrast!: Bool = false,
        reduceMotion!: Bool = false
    ) {
        this.reduceTransparency = reduceTransparency
        this.increaseContrast = increaseContrast
        this.reduceMotion = reduceMotion
    }
}

/** Immutable configuration shared by material, component and theme recipes. */
public struct LiquidGlassSpec {
    public let variant: LiquidGlassVariant
    public let tint: ?Color
    public let interactive: Bool
    public let radius: Float32
    public let preferences: LiquidGlassPreferences
    public let optics: LiquidGlassOptics

    /**
     * `optics` defaults to the variant's own profile rather than one shared struct. Sharing a
     * single default is what previously made Regular/Clear/Vapor differ mainly by alpha: the
     * optical controls never actually diverged.
     */
    public init(
        variant!: LiquidGlassVariant = LiquidGlassVariant.Regular,
        tint!: ?Color = None,
        interactive!: Bool = false,
        radius!: Float32 = 9999.0,
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        optics!: ?LiquidGlassOptics = None
    ) {
        let resolvedOptics = match (optics) {
            case Some(value) => value
            case None => LiquidGlassOptics.profile(variant)
        }
        this.variant = variant
        this.tint = tint
        this.interactive = interactive
        this.radius = max(0.0, radius)
        this.preferences = preferences
        this.optics = resolvedOptics
    }

    public func shape(): Shape { Shape.rounded(radius) }
}

/** Public Liquid Glass-inspired recipes with capability-gated backdrop effects and safe fallback. */
public class LiquidGlass {
    /** A material for `Surface`; state-aware tinting is enabled only when `spec.interactive` is true. */
    public static func material(spec!: LiquidGlassSpec = LiquidGlassSpec()): MaterialProvider {
        LiquidGlassMaterial(spec)
    }

    /** State-aware style for `Button` and `IconButton`. */
    public static func buttonStyle(spec!: LiquidGlassSpec = LiquidGlassSpec(interactive: true)): ButtonStyle {
        ButtonStyle(resolve: {theme, role, state => glassButtonAppearance(theme, role, state, spec)})
    }

    /** Morphing selection-lens style for the stock `SegmentedControl` and `TabView`. */
    public static func segmentedControlStyle(
        spec!: LiquidGlassSpec = LiquidGlassSpec(
            variant: LiquidGlassVariant.Clear,
            interactive: true
        )
    ): SegmentedControlStyle {
        SegmentedControlStyle(
            deformation: if (spec.preferences.reduceMotion) { 0.0 } else { spec.optics.deformation },
            paintIndicator: {ctx, rect, state =>
                let _ = paintOpticalGlass(ctx.renderer, rect, isDark(ctx.theme), spec, state.stretch)
            },
            foreground: {theme, selected =>
                if (selected) { theme.text } else { theme.mutedText }
            }
        )
    }

    /** Draws the first-version SDR optical approximation into an arbitrary rectangle. */
    public static func paint(
        renderer: Renderer,
        rect: Rect,
        dark!: Bool = false,
        spec!: LiquidGlassSpec = LiquidGlassSpec(),
        stretch!: Float32 = 0.0
    ): Unit {
        let _ = paintOpticalGlass(renderer, rect, dark, spec, clampUnit(stretch))
    }

    /** Paints the same material and returns the native-effect or fallback reason for diagnostics. */
    public static func paintWithReceipt(
        renderer: Renderer,
        rect: Rect,
        dark!: Bool = false,
        spec!: LiquidGlassSpec = LiquidGlassSpec(),
        stretch!: Float32 = 0.0
    ): RendererEffectReceipt {
        paintOpticalGlass(renderer, rect, dark, spec, clampUnit(stretch))
    }

    /** Optical background hook for the stock `Surface`; content and layout stay Surface-owned. */
    public static func surfacePainter(
        spec!: LiquidGlassSpec = LiquidGlassSpec()
    ): SurfacePainter {
        SurfacePainter(paint: {ctx, rect, shape, _ =>
            let resolved = LiquidGlassSpec(
                variant: spec.variant,
                tint: spec.tint,
                interactive: spec.interactive,
                radius: min(spec.radius, shape.cornerRadius()),
                preferences: spec.preferences,
                optics: Some(spec.optics)
            )
            let _ = paintOpticalGlass(ctx.renderer, rect, isDark(ctx.theme), resolved, 0.0)
        })
    }

    /** Component-wide recipe for buttons, chips, checkboxes, dropdowns, panels and control rhythm. */
    public static func components(
        spec!: LiquidGlassSpec = LiquidGlassSpec(interactive: true)
    ): ComponentTheme {
        ComponentTheme(
            buttonStyle: Some(buttonStyle(spec: spec)),
            buttonLayout: ButtonLayoutStyle(
                contentPadding: LengthInsets(15.vp, 0.vp),
                minWidth: 70.0,
                minHeight: 40.0
            ),
            controlStyle: Some(ComponentControlStyle(resolve: {
                theme, kind, state => glassControlAppearance(theme, kind, state, spec)
            })),
            typography: ComponentTypography(control: 15.fp),
            spacing: ComponentSpacing(
                compactPadding: LengthInsets(12.vp, 0.vp),
                controlPadding: LengthInsets(12.vp, 0.vp),
                selectionPadding: LengthInsets(top: 8.vp, right: 10.vp, bottom: 8.vp, left: 0.vp),
                inlineGap: 8.vp,
                compactMinHeight: 30.0,
                controlMinHeight: 40.0,
                indicatorSize: 18.0
            ),
            shape: ComponentShape(smallRadius: Some(10.0), controlRadius: Some(9999.0),
                pillRadius: Some(9999.0)),
            segmentedControlStyle: Some(segmentedControlStyle(spec: LiquidGlassSpec(
                variant: LiquidGlassVariant.Clear,
                tint: spec.tint,
                interactive: true,
                preferences: spec.preferences,
                optics: Some(spec.optics)
            )))
        )
    }

    /** Light content palette with glass component defaults. */
    public static func light(
        tint!: Color = Color.rgb(0, 122, 255),
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        motionLevel!: MotionLevel = MotionLevel.Standard
    ): Theme {
        let spec = LiquidGlassSpec(tint: Some(tint), interactive: true, preferences: preferences)
        Theme(
            bg: Color.rgb(226, 235, 246),
            panel: glassFill(false, LiquidGlassVariant.Regular, preferences),
            panelEdge: glassEdge(false, preferences),
            text: Color.rgb(24, 29, 38),
            mutedText: Color.rgb(83, 92, 108),
            accent: tint,
            accentText: Color.rgb(255, 255, 255),
            danger: Color.rgb(224, 54, 64),
            field: Color.rgba(255, 255, 255, if (preferences.reduceTransparency) { 255 } else { 116 }),
            fieldActive: tint.withAlpha(if (preferences.reduceTransparency) { 44 } else { 56 }),
            panelRaised: Color.rgba(255, 255, 255, if (preferences.reduceTransparency) { 255 } else { 166 }),
            accentSoft: tint.withAlpha(46),
            shadow: Color.rgba(26, 43, 69, 42),
            radius: 28.0,
            smallRadius: 10.0,
            controlRadius: 9999.0,
            borderWidth: if (preferences.increaseContrast) { 1.5 } else { 1.0 },
            motionLevel: motionLevel,
            reduceMotion: preferences.reduceMotion,
            components: components(spec: spec)
        )
    }

    /** Dark content palette with glass component defaults. */
    public static func dark(
        tint!: Color = Color.rgb(72, 156, 255),
        preferences!: LiquidGlassPreferences = LiquidGlassPreferences(),
        motionLevel!: MotionLevel = MotionLevel.Standard
    ): Theme {
        let spec = LiquidGlassSpec(tint: Some(tint), interactive: true, preferences: preferences)
        Theme(
            bg: Color.rgb(13, 18, 28),
            panel: glassFill(true, LiquidGlassVariant.Regular, preferences),
            panelEdge: glassEdge(true, preferences),
            text: Color.rgb(247, 249, 252),
            mutedText: Color.rgb(174, 183, 198),
            accent: tint,
            accentText: Color.rgb(6, 18, 34),
            danger: Color.rgb(255, 105, 112),
            field: Color.rgba(50, 58, 72, if (preferences.reduceTransparency) { 255 } else { 150 }),
            fieldActive: tint.withAlpha(if (preferences.reduceTransparency) { 54 } else { 68 }),
            panelRaised: Color.rgba(56, 64, 79, if (preferences.reduceTransparency) { 255 } else { 176 }),
            accentSoft: tint.withAlpha(52),
            shadow: Color.rgba(0, 0, 0, 92),
            radius: 28.0,
            smallRadius: 10.0,
            controlRadius: 9999.0,
            borderWidth: if (preferences.increaseContrast) { 1.5 } else { 1.0 },
            motionLevel: motionLevel,
            reduceMotion: preferences.reduceMotion,
            components: components(spec: spec)
        )
    }
}

private class LiquidGlassMaterial <: MaterialProvider {
    private let spec: LiquidGlassSpec

    init(spec: LiquidGlassSpec) { this.spec = spec }

    public func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial {
        let style = surfaceStyle(theme, state, spec)
        SurfaceMaterial(style, theme.text, supportingForeground: Some(theme.mutedText),
            ink: Some(theme.inkColor()))
    }
}

private func surfaceStyle(theme: Theme, state: SurfaceState, spec: LiquidGlassSpec): SurfaceStyle {
    let dark = isDark(theme)
    var fill = glassFill(dark, spec.variant, spec.preferences)
    match (spec.tint) {
        case Some(value) => fill = fill.lerp(value.withAlpha(fillAlpha(fill)), tintStrength(spec.variant))
        case None => ()
    }
    if (spec.interactive) {
        let hover: Float32 = if (state.hovered) { 0.14 } else { 0.0 }
        let press: Float32 = if (state.pressed) { 0.22 } else { 0.0 }
        fill = fill.lerp(theme.text.withAlpha(fillAlpha(fill)), hover)
        fill = fill.lerp(theme.accent.withAlpha(fillAlpha(fill)), press)
    }
    SurfaceStyle(
        fill,
        border: glassEdge(dark, spec.preferences),
        radius: spec.radius,
        borderWidth: if (spec.preferences.increaseContrast) { 1.5 } else { 1.0 },
        shadow: if (spec.preferences.reduceTransparency) {
            Color.rgba(0, 0, 0, 26)
        } else if (dark) {
            Color.rgba(0, 0, 0, 82)
        } else {
            Color.rgba(31, 50, 79, 46)
        },
        shadowOffsetY: match (spec.variant) {
            case LiquidGlassVariant.Clear => 3.0
            case LiquidGlassVariant.Regular => 5.0
            case LiquidGlassVariant.Vapor => 6.0
        }
    )
}

private func glassButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    spec: LiquidGlassSpec
): ButtonAppearance {
    let surfaceState = SurfaceState(focused: state.focused, hovered: state.hover > 0.001,
        pressed: state.press > 0.001)
    var style = surfaceStyle(theme, surfaceState, spec)
    let foreground = match (role) {
        case ButtonRole.Normal => theme.text
        case ButtonRole.Primary => theme.accentText
        case ButtonRole.Danger => theme.accentText
    }
    match (role) {
        case ButtonRole.Normal => ()
        case ButtonRole.Primary => style = style.withFill(theme.accent.withAlpha(
            if (spec.preferences.reduceTransparency) { 255 } else { 218 }))
        case ButtonRole.Danger => style = style.withFill(theme.danger.withAlpha(
            if (spec.preferences.reduceTransparency) { 255 } else { 218 }))
    }
    let ink = match (role) {
        case ButtonRole.Normal => theme.accent
        case _ => theme.accentText.withAlpha(84)
    }
    ButtonAppearance(surface: style, foreground: foreground,
        ink: ink,
        focusRadius: spec.radius)
}

private func glassControlAppearance(
    theme: Theme,
    kind: ComponentControlKind,
    state: ComponentControlState,
    spec: LiquidGlassSpec
): ComponentControlAppearance {
    let selected = state.selected || state.expanded || state.selection > 0.001
    let radius: Float32 = match (kind) {
        case ComponentControlKind.Checkbox => 10.0
        case _ => spec.radius
    }
    var style = surfaceStyle(theme, SurfaceState(selected: selected, expanded: state.expanded,
        focused: state.focused, hovered: state.hover > 0.001, pressed: state.press > 0.001),
        LiquidGlassSpec(variant: spec.variant, tint: spec.tint, interactive: spec.interactive,
            radius: radius, preferences: spec.preferences, optics: Some(spec.optics)))
    let acceptsSelectedFill = match (kind) {
        case ComponentControlKind.Dropdown => false
        case _ => true
    }
    if (selected && acceptsSelectedFill) {
        style = style.withFill(theme.accent.withAlpha(if (spec.preferences.reduceTransparency) { 255 } else { 206 }))
    }
    ComponentControlAppearance(
        surface: style,
        foreground: match (kind) {
            case ComponentControlKind.Chip => if (selected) { theme.accentText } else { theme.text }
            case _ => theme.text
        },
        indicator: if (selected) { theme.accentText } else { theme.accent },
        ink: theme.inkColor(),
        focusRadius: radius
    )
}

private func glassFill(dark: Bool, variant: LiquidGlassVariant, preferences: LiquidGlassPreferences): Color {
    if (preferences.reduceTransparency) {
        return if (dark) { Color.rgb(43, 50, 63) } else { Color.rgb(244, 247, 251) }
    }
    // Optical glass is a thin layer over a dense image, not a fogged panel. The previous alphas
    // (up to 166/255 for dark Regular) veiled the backdrop until it read as grey plastic, so the
    // body stays deliberately light and lets the cover art carry the colour.
    match (variant) {
        case LiquidGlassVariant.Regular => if (dark) {
            Color.rgba(30, 34, 46, 84)
        } else {
            Color.rgba(255, 255, 255, 96)
        }
        case LiquidGlassVariant.Clear => if (dark) {
            Color.rgba(34, 38, 52, 44)
        } else {
            Color.rgba(255, 255, 255, 46)
        }
        case LiquidGlassVariant.Vapor => if (dark) {
            Color.rgba(44, 50, 66, 128)
        } else {
            Color.rgba(246, 250, 255, 132)
        }
    }
}

private func glassEdge(dark: Bool, preferences: LiquidGlassPreferences): Color {
    if (preferences.increaseContrast) {
        if (dark) { Color.rgba(255, 255, 255, 118) } else { Color.rgba(61, 76, 98, 112) }
    } else if (dark) {
        Color.rgba(255, 255, 255, 62)
    } else {
        Color.rgba(255, 255, 255, 206)
    }
}

private func isDark(theme: Theme): Bool {
    Int64(theme.bg.r) + Int64(theme.bg.g) + Int64(theme.bg.b) < 384
}

private func fillAlpha(value: Color): Int64 { Int64(value.a) }

private func tintStrength(variant: LiquidGlassVariant): Float32 {
    match (variant) {
        case LiquidGlassVariant.Regular => 0.10
        case LiquidGlassVariant.Clear => 0.16
        case LiquidGlassVariant.Vapor => 0.12
    }
}

/**
 * Five explicit material layers. Keeping them separate is the point of this repair: a single
 * translucent fill previously stood in for the whole material, which is exactly what reads as
 * plastic. Each layer is independently testable through the recording renderer.
 */
private enum GlassLayer {
    | Backdrop
    | Body
    | Edge
    | Lens
    | State
}

private func glassLayerName(layer: GlassLayer): String {
    match (layer) {
        case GlassLayer.Backdrop => "glass.backdrop"
        case GlassLayer.Body => "glass.body"
        case GlassLayer.Edge => "glass.edge"
        case GlassLayer.Lens => "glass.lens"
        case GlassLayer.State => "glass.state"
    }
}

/**
 * Motion-following highlight travel. A fixed gleam slab is the other half of the plastic read;
 * the reference instead moves the specular response with the live lens and with state energy,
 * and keeps it clipped to the actual shape instead of painting a rectangle across the surface.
 */
private func paintGlassHighlight(renderer: Renderer, rect: Rect, radius: Float32,
    spec: LiquidGlassSpec, stretch: Float32): Unit {
    let optics = spec.optics
    if (isVaporVariant(spec.variant)) {
        // Vapor carries a wide soft bloom in the body layer; a defined band would fight it.
        return
    }
    let travel = clampUnit(0.16 + clampUnit(stretch) * 0.66)
    // The highlight must stay inside the rounded silhouette: a capsule surface has no wide flat
    // top edge, so the band narrows as the corner radius approaches half the shorter edge.
    let cornerRatio = clampUnit(radius / max(1.0, min(rect.w, rect.h) * 0.5))
    let usableW = rect.w * (1.0 - cornerRatio * 0.35)
    let bandW = min(usableW * 0.46, max(6.0, usableW * (0.16 + travel * 0.30)))
    let bandH = min(6.5, max(1.6, rect.h * 0.055))
    let x = rect.x + max(0.0, (rect.w - bandW) * (0.10 + travel * 0.70))
    let y = rect.y + min(rect.h * 0.22, 1.0 + travel * 3.0)
    // Alpha stays edge-energy weighted so a large surface never receives a white slab.
    let alpha = Int64(26.0 + 58.0 * optics.edgeEnergy * (0.55 + 0.45 * travel))
    renderer.fillRoundedRectSoft(Rect(x, y, bandW, bandH), bandH / 2.0,
        Color.rgba(255, 255, 255, min(255, alpha)), feather: 4.0)
}

private func paintGlassBackdropLayer(renderer: Renderer, rect: Rect, radius: Float32,
    spec: LiquidGlassSpec, stretch: Float32): RendererEffectReceipt {
    let optics = spec.optics
    let motion = clampUnit(stretch)
    let shorter = min(rect.w, rect.h)
    let lensRadius = max(2.0, shorter * optics.lensRadius)
    let cx = rect.x + rect.w * (0.5 + (motion - 0.5) * 0.18)
    let cy = rect.y + rect.h * 0.46

    // Sample ONLY the lens disc, not the whole surface.
    //
    // A full-screen glass container cannot be read back in one bound: its visible area alone is
    // larger than the provider pixel budget, and splitting it into bands misaligns the lens grid and
    // leaves visible seams. But a full-surface readback is also unnecessary: in the reference the
    // optical element is a bounded circular lens (frame 61), while the rest of the panel is plain
    // composition. So the bounded sample follows the lens, which fits the budget comfortably.
    var sampleRect = rect
    if (optics.lensRadius > 0.0) {
        let diameter = lensRadius * 2.0
        sampleRect = Rect(cx - lensRadius, cy - lensRadius, diameter, diameter)
            .intersection(rect)
    }
    let lens = BackdropLensOptics(
        centerX: 0.5,
        centerY: 0.5,
        radius: 0.5,
        displacementStrength: optics.displacement,
        sampleRadius: optics.sampleRadius,
        invertInsideLens: isClearVariant(spec.variant))
    return renderer.applyBackdropEffect(BackdropEffectRequest(
        sampleRect,
        cornerRadius: min(radius, lensRadius),
        blurRadius: 4.0 + optics.haze * 16.0,
        refraction: 0.10 + optics.clarity * 0.40,
        edgeResponse: optics.edgeEnergy,
        lens: lens,
        motionEnergy: motion,
        lensFrame: sampleRect))
}

private func paintGlassBodyLayer(renderer: Renderer, rect: Rect, radius: Float32,
    dark: Bool, spec: LiquidGlassSpec): Unit {
    let optics = spec.optics
    let base = glassFill(dark, spec.variant, spec.preferences)
    let tint = match (spec.tint) {
        case Some(value) => value
        case None => if (dark) { Color.rgb(126, 174, 255) } else { Color.rgb(210, 231, 255) }
    }
    // The white veil must be a sheen, not a wash. Halving it is what lets saturated cover art read
    // through the material instead of turning the whole frame grey.
    let topAlpha = Int64(14.0 + 30.0 * optics.haze)
    let bottomAlpha = Int64(8.0 + 26.0 * (1.0 - optics.clarity))
    let top = base.lerp(Color.rgba(255, 255, 255, topAlpha), 0.30)
    let bottom = base.lerp(tint.withAlpha(bottomAlpha), 0.20)
    match (spec.variant) {
        case LiquidGlassVariant.Vapor =>
            // A large translucent gradient can expose the portable renderer's triangle fan on
            // dark SDR targets. Vapor favours a seamless body plus local mist bands instead.
            renderer.fillRoundedRect(rect, radius, top.lerp(bottom, 0.52))
        case _ => renderer.fillRoundedRectGradient(rect, radius, top, bottom)
    }
    if (optics.tintStrength > 0.001) {
        match (spec.tint) {
            case Some(value) =>
                let tintAlpha = Int64(optics.tintStrength * 90.0)
                renderer.fillRoundedRect(rect, radius, value.withAlpha(min(255, tintAlpha)))
            case None => ()
        }
    }
    match (spec.variant) {
        case LiquidGlassVariant.Vapor =>
            let mistInset = max(2.0, min(rect.w, rect.h) * 0.06)
            let mist = Rect(rect.x + mistInset, rect.y + mistInset,
                max(1.0, rect.w - mistInset * 2.0), min(42.0, max(8.0, rect.h * 0.09)))
            renderer.fillRoundedRectSoft(mist, mist.h / 2.0,
                Color.rgba(255, 255, 255, Int64(16.0 + 32.0 * optics.haze)),
                feather: 10.0 + 10.0 * optics.haze)
        case _ => ()
    }
}

/**
 * Contour depth. The reference edge is not one hairline: it shows several brightness contours.
 * `edgeRings` draws converging inset rings, which is what makes the boundary read as a bevel
 * instead of a drawn border.
 */
private func paintGlassEdgeLayer(renderer: Renderer, rect: Rect, radius: Float32,
    dark: Bool, spec: LiquidGlassSpec): Unit {
    let optics = spec.optics
    let rings = max(Int64(2), optics.edgeRings)
    // Reference frame 52: the border is not one bright stroke. It is a band of alternating bright
    // and dark contours — light bends differently at each rim step, so the eye reads thickness.
    var index: Int64 = 0
    while (index < rings) {
        let step = Float32(index)
        let inset = 0.5 + step * (1.35 + optics.haze * 0.7)
        let ringRadius = max(0.0, radius - inset)
        let falloff = 1.0 - step / Float32(rings)
        // Even rings are the lit contour, odd rings the shadowed one that sits just inside it.
        let bright = index % 2 == 0
        let alpha = if (bright) {
            Int64((62.0 + 116.0 * optics.edgeEnergy) * (0.40 + 0.60 * falloff))
        } else {
            Int64((26.0 + 40.0 * optics.edgeEnergy) * (0.30 + 0.70 * falloff))
        }
        let width: Float32 = if (index == 0) {
            if (spec.preferences.increaseContrast) { 2.0 } else { 1.5 }
        } else {
            max(0.7, 1.15 - step * 0.10)
        }
        let color = if (bright) {
            Color.rgba(255, 255, 255, min(255, alpha))
        } else if (dark) {
            Color.rgba(12, 18, 32, min(255, alpha))
        } else {
            Color.rgba(74, 96, 128, min(255, alpha))
        }
        renderer.strokeRoundedRect(rect.inset(inset), ringRadius, Pen(width: width, color: color))
        index += 1
    }
    // Deep inner shadow: the rim of real glass gathers the backdrop and goes darker just inside.
    let insetDeep = 2.0 + Float32(rings) * 1.1
    let inner = rect.inset(insetDeep)
    if (inner.w > 2.0 && inner.h > 2.0) {
        renderer.strokeRoundedRect(inner, max(0.0, radius - insetDeep),
            Pen(width: 1.4, color: if (dark) {
                Color.rgba(8, 12, 24, min(255, Int64(48.0 + 56.0 * optics.edgeEnergy)))
            } else {
                Color.rgba(64, 84, 116, min(255, Int64(26.0 + 34.0 * optics.edgeEnergy)))
            }))
    }
}

/**
 * The bounded local lens. This is the layer the reference demands and the old implementation had
 * no way to express: an optical centre with a radius, an interior reflection ring, and chromatic
 * separation that only exists while the material is moving. Settled frames of the source are free
 * of colour fringing, so a permanent chromatic outline is a defect, not a feature.
 */
private func paintGlassLensLayer(renderer: Renderer, rect: Rect, radius: Float32,
    dark: Bool, spec: LiquidGlassSpec, stretch: Float32): Unit {
    let optics = spec.optics
    if (isVaporVariant(spec.variant)) {
        // Vapor is a haze material; a hard lens would contradict its recipe.
        return
    }
    let motion = clampUnit(stretch)
    let shorter = min(rect.w, rect.h)
    let cornerRatio = clampUnit(radius / max(1.0, shorter * 0.5))
    let flatWindow = shorter * (0.5 - cornerRatio * 0.12)
    let lensRadius = max(2.0, min(flatWindow, shorter * optics.lensRadius * 0.5))
    if (lensRadius * 2.0 > shorter) { return }
    let cx = rect.x + rect.w * (0.5 + (motion - 0.5) * 0.18)
    let cy = rect.y + rect.h * 0.46

    // Reference frame 61 brightens inside the lens, but that brightness is *magnified backdrop*,
    // not a white overlay: painting opaque white discs here turned the lens into a spotlight and
    // washed the content out. Only a faint interior sheen survives, and the displacement job belongs
    // to the backdrop sampler.
    renderer.fillCircle(cx, cy, lensRadius,
        Color.rgba(255, 255, 255, min(255, Int64(4.0 + 7.0 * optics.clarity))))

    // Concentric contour rings: the reference shows several brightness steps inside the rim
    // (frames 61 and 71), which is what makes the boundary read as a lens rather than a stroke.
    let ringCount = max(Int64(2), optics.edgeRings)
    var ring: Int64 = 0
    while (ring < ringCount) {
        let t = Float32(ring) / Float32(ringCount - 1)
        let ringR = lensRadius * (0.78 + 0.20 * t)
        let ringAlpha = Int64(10.0 + 18.0 * (1.0 - t) * (0.4 + optics.edgeEnergy))
        renderer.strokeCircle(cx, cy, ringR,
            Pen(width: 0.9, color: Color.rgba(255, 255, 255, min(255, ringAlpha))))
        ring += 1
    }

    // Hard inner rim: one darker contour so the lens edge separates from the body.
    let rimAlpha = Int64(20.0 + 26.0 * optics.edgeEnergy)
    let rimR: Int64 = if (dark) { 24 } else { 120 }
    let rimG: Int64 = if (dark) { 28 } else { 124 }
    let rimB: Int64 = if (dark) { 38 } else { 140 }
    renderer.strokeCircle(cx, cy, max(1.0, lensRadius - 0.8),
        Pen(width: 1.1, color: Color.rgba(rimR, rimG, rimB, min(255, rimAlpha))))

    // Specular arc: reference frames 61 and 71 show a bright glint travelling along the sphere, not
    // a straight band across the panel. Its position follows motion so the glint sweeps the rim.
    let arcStart = -2.35 + motion * 1.6
    let arcAlpha = Int64(30.0 + 70.0 * optics.edgeEnergy * (0.35 + 0.65 * motion))
    var arcSegment: Int64 = 0
    while (arcSegment < 7) {
        let a = arcStart + Float32(arcSegment) * 0.085
        let ax = cx + effectCosApprox(a) * (lensRadius - 1.4)
        let ay = cy + effectSinApprox(a) * (lensRadius - 1.4)
        renderer.fillCircle(ax, ay, max(1.2, lensRadius * 0.075),
            Color.rgba(255, 255, 255, min(255, arcAlpha / 7 + 6)))
        arcSegment += 1
    }

    // Chromatic separation stays strictly transient: frame 73 is clean. Only the *amount* is gated.
    let chroma = optics.chromaticEdge * motion
    if (chroma > 0.02) {
        let chromaAlpha = min(255, Int64(30.0 * chroma))
        let offset = 0.8 + 2.2 * chroma
        renderer.strokeCircle(cx - offset, cy, lensRadius - 0.8,
            Pen(width: 1.2, color: Color.rgba(102, 180, 255, chromaAlpha)))
        renderer.strokeCircle(cx + offset, cy, lensRadius - 0.8,
            Pen(width: 1.2, color: Color.rgba(255, 128, 179, chromaAlpha)))
        // Reference frame 61 also shows a green fringe on the rim, not only blue/red.
        renderer.strokeCircle(cx, cy + offset * 0.8, lensRadius - 0.6,
            Pen(width: 1.0, color: Color.rgba(126, 226, 150, min(255, Int64(22.0 * chroma)))))
    }
}

private func paintGlassStateLayer(renderer: Renderer, rect: Rect, radius: Float32,
    spec: LiquidGlassSpec, stretch: Float32): Unit {
    let optics = spec.optics
    // Boundary halo sits outside the body so it cannot create a false seam inside the shape.
    let haloAlpha = Int64(18.0 + 40.0 * optics.edgeEnergy)
    renderer.fillRoundedRectSoft(
        Rect(rect.x - 2.0, rect.y - 2.0, rect.w + 4.0, rect.h + 5.0),
        radius + 2.0,
        Color.rgba(255, 255, 255, haloAlpha),
        feather: 5.0 + 4.0 * optics.haze
    )
    paintGlassHighlight(renderer, rect, radius, spec, stretch)
}

private func paintOpticalGlass(
    renderer: Renderer,
    rect: Rect,
    dark: Bool,
    spec: LiquidGlassSpec,
    stretch: Float32
): RendererEffectReceipt {
    let radius = min(spec.radius, rect.h / 2.0 + stretch * 3.0)

    // Accessibility path is deliberately opaque and never requests backdrop sampling.
    if (spec.preferences.reduceTransparency) {
        renderer.fillRoundedRect(rect, radius, glassFill(dark, spec.variant, spec.preferences))
        renderer.strokeRoundedRect(rect.inset(0.5), max(0.0, radius - 0.5),
            Pen(width: if (spec.preferences.increaseContrast) { 1.5 } else { 1.0 },
                color: glassEdge(dark, spec.preferences)))
        return RendererEffectReceipt(
            RendererEffectStatus.Degraded,
            "backdrop",
            "reduced-transparency",
            frameGeneration: renderer.effectFrameGeneration(),
            detail: "opaque accessibility material selected without backdrop sampling"
        )
    }

    let backdropReceipt = paintGlassBackdropLayer(renderer, rect, radius, spec, stretch)
    paintGlassBodyLayer(renderer, rect, radius, dark, spec)
    paintGlassEdgeLayer(renderer, rect, radius, dark, spec)
    paintGlassLensLayer(renderer, rect, radius, dark, spec, stretch)
    paintGlassStateLayer(renderer, rect, radius, spec, stretch)
    backdropReceipt
}

private func isVaporVariant(variant: LiquidGlassVariant): Bool {
    match (variant) {
        case LiquidGlassVariant.Vapor => true
        case _ => false
    }
}

private func isClearVariant(variant: LiquidGlassVariant): Bool {
    match (variant) {
        case LiquidGlassVariant.Clear => true
        case _ => false
    }
}

/** Small-angle cosine approximation; avoids pulling a trig import into the paint path. */
private func effectCosApprox(angle: Float32): Float32 {
    // Wrap into [-pi, pi] by folding through the Taylor series over three cosine lobes.
    var a = angle
    while (a > 3.14159265) { a -= 6.2831853 }
    while (a < -3.14159265) { a += 6.2831853 }
    let a2 = a * a
    let a4 = a2 * a2
    return 1.0 - a2 * 0.5 + a4 * 0.0416667
}

/** Paired sine approximation: sin(a) = cos(a - pi/2). */
private func effectSinApprox(angle: Float32): Float32 {
    effectCosApprox(angle - 1.5707963)
}

private func clampUnit(value: Float32): Float32 {
    max(0.0, min(1.0, value))
}
