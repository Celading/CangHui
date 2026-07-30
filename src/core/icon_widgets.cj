package cui.core

import sdl.{Color, FontSizes, IconName, Key, Rect, Size, SurfaceStyle, UiEvent}
import cui.symbol.{SymbolDirection, SymbolMissingPolicy, SymbolName, SymbolVariant, drawSymbol, symbolNameForIcon}

private let ICON_DEFAULT_SIZE: Float32 = 18.0
private let ICON_BUTTON_PAD: Float32 = 10.0
private let ICON_TEXT_GAP: Float32 = 8.0

/** Provider-neutral vector symbol with deterministic fallback and Draw IR reporting. */
public class Symbol <: Widget {
    private let symbolName: SymbolName
    private var symbolExtent: Length
    private var symbolColorOverride: ?Color
    private var symbolWeight: Float32
    private var symbolVariant: SymbolVariant
    private var symbolDirection: SymbolDirection
    private var mirrorSymbol: Bool
    private var a11yLabel: String
    private var missingPolicy: SymbolMissingPolicy
    private var frame = Rect.zero()

    public init(
        name: SymbolName,
        size!: Length = Length(ICON_DEFAULT_SIZE, LengthUnit.Vp),
        color!: ?Color = None,
        weight!: Float32 = 400.0,
        variant!: SymbolVariant = SymbolVariant.Outlined,
        direction!: SymbolDirection = SymbolDirection.Inherit,
        mirrored!: Bool = false,
        accessibilityLabel!: String = "",
        missingPolicy!: SymbolMissingPolicy = SymbolMissingPolicy.Fallback
    ) {
        this.symbolName = name
        this.symbolExtent = size
        this.symbolColorOverride = color
        this.symbolWeight = weight
        this.symbolVariant = variant
        this.symbolDirection = direction
        this.mirrorSymbol = mirrored
        this.a11yLabel = accessibilityLabel
        this.missingPolicy = missingPolicy
        emit(this)
    }

    public func symbolSize(value: Length): Symbol { symbolExtent = value; this }
    public func symbolSize(value: Float32): Symbol { symbolSize(vpLength(value)) }
    public func foregroundColor(value: Color): Symbol { symbolColorOverride = Some(value); this }
    public func weight(value: Float32): Symbol { symbolWeight = value; this }
    public func variant(value: SymbolVariant): Symbol { symbolVariant = value; this }
    public func fill(value!: Bool = true): Symbol {
        symbolVariant = if (value) { SymbolVariant.Filled } else { SymbolVariant.Outlined }
        this
    }
    public func direction(value: SymbolDirection): Symbol { symbolDirection = value; this }
    public func mirrored(value!: Bool = true): Symbol { mirrorSymbol = value; this }
    public func accessibilityLabel(value: String): Symbol { a11yLabel = value; this }
    public func accessibilityLabel(): String { a11yLabel }
    public func missing(value: SymbolMissingPolicy): Symbol { missingPolicy = value; this }
    public func strict(value!: Bool = true): Symbol {
        missingPolicy = if (value) { SymbolMissingPolicy.Strict } else { SymbolMissingPolicy.Fallback }
        this
    }

    public func measure(ctx: UiContext, _: Size): Size {
        let extent = max(1.0, ctx.resolve(symbolExtent))
        Size(extent, extent)
    }

    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }

    public func draw(ctx: UiContext): Unit {
        let extent = max(1.0, ctx.resolve(symbolExtent))
        let color = match (symbolColorOverride) {
            case Some(value) => value
            case None => ctx.theme.text
        }
        let _ = drawSymbol(ctx.renderer, symbolName, centeredIconRect(frame, extent), color,
            weight: symbolWeight, variant: symbolVariant, direction: symbolDirection,
            mirrored: mirrorSymbol, accessibilityLabel: a11yLabel, policy: missingPolicy)
    }

    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

/**
 * A non-interactive vector icon drawn at a square extent (default 18 vp), in the theme text color
 * unless `foregroundColor` overrides it. For a clickable icon use `IconButton`.
 */
public class Icon <: Widget {
    private let symbolName: SymbolName
    private var iconExtent: Length
    private var iconColorOverride: ?Color
    private var frame = Rect.zero()

    public init(icon: IconName, size!: Length = Length(ICON_DEFAULT_SIZE, LengthUnit.Vp), color!: ?Color = None) {
        this.symbolName = symbolNameForIcon(icon)
        this.iconExtent = size
        this.iconColorOverride = color
        emit(this)
    }

    /** Uses an optional Symbol provider while preserving the legacy Icon widget surface. */
    public init(name: SymbolName, size!: Length = Length(ICON_DEFAULT_SIZE, LengthUnit.Vp), color!: ?Color = None) {
        this.symbolName = name
        this.iconExtent = size
        this.iconColorOverride = color
        emit(this)
    }

    /** Sets the square icon extent, e.g. `.iconSize(22.vp)`. */
    public func iconSize(value: Length): Icon {
        iconExtent = value
        this
    }

    /** Sets the square icon extent in virtual pixels. */
    public func iconSize(value: Float32): Icon {
        iconSize(vpLength(value))
    }

    /** Overrides the theme-derived icon color. */
    public func foregroundColor(value: Color): Icon {
        iconColorOverride = Some(value)
        this
    }

    public func measure(ctx: UiContext, _: Size): Size {
        let extent = resolvedExtent(ctx)
        Size(extent, extent)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let _ = drawSymbol(ctx.renderer, symbolName, centeredIconRect(frame, resolvedExtent(ctx)), iconColor(ctx))
    }

    private func resolvedExtent(ctx: UiContext): Float32 {
        max(1.0, ctx.resolve(iconExtent))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func iconColor(ctx: UiContext): Color {
        match (iconColorOverride) {
            case Some(value) => value
            case None => ctx.theme.text
        }
    }
}

/*
 * A button whose face is an icon, optionally with a text label beside it. Activation matches `Button`:
 * `onClick` fires on a press released inside, or on Enter/Space while focused; `role` and `style`
 * color the surface the same way. Icon-only buttons in one view stay distinct through per-build
 * identities; `key` pins an identity that survives tree reshapes.
 */
public class IconButton <: Widget {
    private let symbolName: SymbolName
    private var labelText: ?String
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private let onClick: () -> Unit
    private var controlId: String
    private let interaction: InteractionAnimation
    private var animationSpec: AnimationSpec
    private var frame = Rect.zero()

    public init(
        icon: IconName,
        label!: ?String = None,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        onClick!: () -> Unit
    ) {
        this.symbolName = symbolNameForIcon(icon)
        this.labelText = label
        this.buttonRole = role
        this.customStyle = style
        this.onClick = onClick
        this.controlId = focusableControlIdentity(match (label) {
            case Some(value) => "IconButton:${value}"
            case None => "IconButton"
        })
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        emit(this)
    }

    /** Creates an IconButton from any registered Symbol provider. */
    public init(
        name: SymbolName,
        label!: ?String = None,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        onClick!: () -> Unit
    ) {
        this.symbolName = name
        this.labelText = label
        this.buttonRole = role
        this.customStyle = style
        this.onClick = onClick
        // The build-order identity keeps several icon-only buttons in one view distinct;
        // a shared id would let one button swallow the release meant for another.
        this.controlId = focusableControlIdentity(match (label) {
            case Some(value) => "IconButton:${value}"
            case None => "IconButton"
        })
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes.
     * Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): IconButton {
        requireControlId(value, "IconButton")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Adds a text label beside the icon. */
    public func label(value: String): IconButton {
        labelText = Some(value)
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): IconButton {
        buttonRole = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): IconButton {
        customStyle = Some(value)
        this
    }

    /** Applies an automatic or explicit hover/press animation property. */
    public func animation(value: AnimationSpec): IconButton {
        animationSpec = value
        this
    }

    /** Applies an exact playback duration and curve. */
    public func animation(duration: UInt64, easing!: Easing = Motion.standard): IconButton {
        animation(AnimationSpec(duration: duration, easing: easing))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (labelText) {
            // Measure at the same size draw uses (FontSizes.CONTROL), so the two cannot drift
            // apart if the token tables ever diverge from the measurement default.
            case Some(value) => max(76.0,
                ICON_BUTTON_PAD * 2.0 + ICON_DEFAULT_SIZE + ICON_TEXT_GAP +
                    ctx.renderer.textWidth(value, pointSize: FontSizes.CONTROL))
            case None => CUI_CONTROL_H
        }
        Size(min(available.w, width), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let progress = interaction.animate(ctx, ctx.isHovered(controlId), ctx.isPressed(controlId), animationSpec)
        let visualFrame = animatedButtonFrame(frame, ctx.theme.motionLevel, progress)
        drawSurface(ctx, visualFrame, buttonStyle(ctx, progress))
        let color = contentColor(ctx)
        let _ = drawSymbol(ctx.renderer, symbolName, iconFrame(visualFrame), color)
        match (labelText) {
            case Some(value) => ctx
                .renderer
                .text(value, iconFrame(visualFrame).right() + ICON_TEXT_GAP,
                    visualFrame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0, color,
                    pointSize: FontSizes.CONTROL)
            case None => ()
        }
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, visualFrame, ctx.theme.controlRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (handlePointerClick(ctx, event, frame, controlId, onClick,
            inkRadius: ctx.theme.controlRadius, inkColor: Some(ctx.theme.inkColor(role: buttonRole)))) {
            return true
        }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY(),
                        color: Some(ctx.theme.inkColor(role: buttonRole)), cornerRadius: ctx.theme.controlRadius)
                    onClick()
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY(),
                        color: Some(ctx.theme.inkColor(role: buttonRole)), cornerRadius: ctx.theme.controlRadius)
                    onClick()
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func iconFrame(bounds: Rect): Rect {
        match (labelText) {
            case Some(_) => Rect(
                bounds.x + ICON_BUTTON_PAD,
                bounds.centerY() - ICON_DEFAULT_SIZE / 2.0,
                ICON_DEFAULT_SIZE,
                ICON_DEFAULT_SIZE
            )
            case None => centeredIconRect(bounds, ICON_DEFAULT_SIZE)
        }
    }

    private func contentColor(ctx: UiContext): Color {
        match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
    }

    private func buttonStyle(ctx: UiContext, progress: InteractionProgress): SurfaceStyle {
        let base = match (customStyle) {
            case Some(value) => value
            case None => ctx.theme.buttonSurface(buttonRole)
        }
        animatedButtonSurface(ctx, base, buttonRole, progress)
    }
}

/**
 * A hairline rule separating content: 1 logical pixel thick along its `axis`, stretched across the
 * cross axis by the parent stack. Color defaults to the theme's panel edge.
 */
public class Divider <: Widget {
    private var dividerAxis: Axis
    private var dividerColor: ?Color
    private var frame = Rect.zero()

    public init(axis!: Axis = Axis.Horizontal, color!: ?Color = None) {
        this.dividerAxis = axis
        this.dividerColor = color
        emit(this)
    }

    /** Sets the divider orientation. */
    public func axis(value: Axis): Divider {
        dividerAxis = value
        this
    }

    /** Overrides the theme divider color, matching Label/Icon's `foregroundColor` naming. */
    public func foregroundColor(value: Color): Divider {
        dividerColor = Some(value)
        this
    }

    /** Deprecated alias for `foregroundColor`; kept so existing call sites keep working. */
    public func color(value: Color): Divider {
        foregroundColor(value)
    }

    public func measure(_: UiContext, _: Size): Size {
        // A divider only contributes its 1px thickness to a container's content size; the
        // parent's layout stretches it along the cross axis to span its siblings.
        match (dividerAxis) {
            case Axis.Horizontal => Size(0.0, 1.0)
            case Axis.Vertical => Size(1.0, 0.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let c = match (dividerColor) {
            case Some(value) => value
            case None => ctx.theme.panelEdge
        }
        ctx.renderer.fill(dividerRect(), c)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func dividerRect(): Rect {
        match (dividerAxis) {
            case Axis.Horizontal => Rect(frame.x, frame.centerY(), frame.w, 1.0)
            case Axis.Vertical => Rect(frame.centerX(), frame.y + 4.0, 1.0, max(0.0, frame.h - 8.0))
        }
    }
}

private func centeredIconRect(frame: Rect, size: Float32): Rect {
    Rect(frame.centerX() - size / 2.0, frame.centerY() - size / 2.0, size, size)
}
