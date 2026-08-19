package cui.core

import sdl.{Color, SurfaceStyle}

/** Continuous interaction state supplied to a state-aware button style. */
public struct ButtonVisualState {
    public let hover: Float32
    public let press: Float32
    public let focused: Bool

    public init(hover!: Float32 = 0.0, press!: Float32 = 0.0, focused!: Bool = false) {
        this.hover = max(0.0, min(1.0, hover))
        this.press = max(0.0, min(1.0, press))
        this.focused = focused
    }
}

/** Complete outer paint result for a button; slot content keeps ownership of its own foreground. */
public struct ButtonAppearance {
    public let surface: SurfaceStyle
    public let foreground: Color
    public let ink: Color
    public let focusRadius: Float32

    public init(
        surface!: SurfaceStyle,
        foreground!: Color,
        ink!: Color,
        focusRadius!: Float32
    ) {
        this.surface = surface
        this.foreground = foreground
        this.ink = ink
        this.focusRadius = max(0.0, focusRadius)
    }
}

/** Resolves one button appearance from semantic role and live interaction state. */
public class ButtonStyle {
    private let resolver: (Theme, ButtonRole, ButtonVisualState) -> ButtonAppearance

    public init(resolve!: (Theme, ButtonRole, ButtonVisualState) -> ButtonAppearance) {
        this.resolver = resolve
    }

    public func resolve(theme: Theme, role: ButtonRole, state: ButtonVisualState): ButtonAppearance {
        resolver(theme, role, state)
    }
}

/** Layout anatomy shared by title and slot-based buttons. */
public struct ButtonLayoutStyle {
    public let contentPadding: LengthInsets
    public let minWidth: Float32
    public let minHeight: Float32

    public init(
        contentPadding!: LengthInsets = LengthInsets(12.vp, 0.vp),
        minWidth!: Float32 = 72.0,
        minHeight!: Float32 = CUI_CONTROL_H
    ) {
        this.contentPadding = contentPadding
        this.minWidth = max(0.0, minWidth)
        this.minHeight = max(0.0, minHeight)
    }
}

/** Component-scoped theme overrides layered on top of the semantic palette. */
public struct ComponentTheme {
    public let buttonStyle: ?ButtonStyle
    public let buttonLayout: ButtonLayoutStyle
    public let panelSurface: ?SurfaceStyle

    public init(
        buttonStyle!: ?ButtonStyle = None,
        buttonLayout!: ButtonLayoutStyle = ButtonLayoutStyle(),
        panelSurface!: ?SurfaceStyle = None
    ) {
        this.buttonStyle = buttonStyle
        this.buttonLayout = buttonLayout
        this.panelSurface = panelSurface
    }
}

protected func resolveButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    styleOverride!: ?ButtonStyle = None,
    surfaceOverride!: ?SurfaceStyle = None
): ButtonAppearance {
    match (styleOverride) {
        case Some(value) => return value.resolve(theme, role, state)
        case None => ()
    }
    match (surfaceOverride) {
        case Some(value) => return defaultButtonAppearance(theme, role, state, base: value)
        case None => ()
    }
    match (theme.components.buttonStyle) {
        case Some(value) => value.resolve(theme, role, state)
        case None => defaultButtonAppearance(theme, role, state)
    }
}

private func defaultButtonAppearance(
    theme: Theme,
    role: ButtonRole,
    state: ButtonVisualState,
    base!: ?SurfaceStyle = None
): ButtonAppearance {
    let surface = match (base) {
        case Some(value) => value
        case None => theme.buttonSurface(role)
    }
    ButtonAppearance(
        surface: animatedButtonSurface(theme, surface, role, state),
        foreground: match (role) {
            case ButtonRole.Normal => theme.text
            case _ => theme.accentText
        },
        ink: theme.inkColor(role: role),
        focusRadius: surface.radius
    )
}

protected func animatedButtonSurface(
    theme: Theme,
    base: SurfaceStyle,
    role: ButtonRole,
    state: ButtonVisualState
): SurfaceStyle {
    let amount = theme.motionLevel.amplitude()
    let hoverFill = match (role) {
        case ButtonRole.Normal => theme.fieldActive
        case _ => base.fill.lerp(theme.accentText, min(0.16, 0.08 * amount))
    }
    let pressFill = match (role) {
        case ButtonRole.Normal => theme.accentSoft
        case _ => base.fill.lerp(theme.bg, min(0.24, 0.14 * amount))
    }
    let hovered = base.fill.lerp(hoverFill, state.hover)
    base.withFill(hovered.lerp(pressFill, state.press))
}
