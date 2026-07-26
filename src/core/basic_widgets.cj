package cui.core

import sdl.{FontSizes, Key, Rect, Size, SurfaceStyle, UiEvent}

/**
 * An empty, flexible widget: it measures zero and absorbs a share of its stack's leftover space,
 * pushing its siblings apart — the idiomatic way to right-align a row's tail or split a toolbar.
 */
public class Spacer <: Widget {
    public init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isFlexible(): Bool {
        true
    }
}

/*
 * A push button: a themed surface with a centered title, firing `onClick` when the primary press that
 * started inside is also released inside (dragging off before release cancels). Focusable — Enter and
 * Space activate it while focused. `role` selects semantic coloring (primary accent, danger); `style`
 * overrides the surface entirely. The focus/press identity defaults to a per-build-position value;
 * `key` pins one that survives tree reshapes.
 */
public class Button <: Widget {
    private let title: String
    private let onClick: () -> Unit
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private var pointSize: Length
    private var controlId: String
    private let interaction: InteractionAnimation
    private var animationSpec: AnimationSpec
    private var frame = Rect.zero()

    public init(
        title: String,
        onClick: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        fontSize!: Length = Length(FontSizes.CONTROL, LengthUnit.Fp)
    ) {
        this.title = title
        this.onClick = onClick
        this.buttonRole = role
        this.customStyle = style
        this.pointSize = fontSize
        this.controlId = focusableControlIdentity("Button:${title}")
        this.interaction = localState<InteractionAnimation>("${this.controlId}:interaction") {
            InteractionAnimation()
        }.value
        this.animationSpec = AnimationSpec.automatic(duration: Motion.fast, easing: Motion.decelerate)
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes (for example a button that moves
     * between containers). Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Button {
        requireControlId(value, "Button")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): Button {
        buttonRole = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): Button {
        customStyle = Some(value)
        this
    }

    /** Sets the label font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Button {
        pointSize = value
        this
    }

    /** Sets the label font size in font pixels. */
    public func fontSize(value: Float32): Button {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Applies an automatic or explicit hover/press animation property. */
    public func animation(value: AnimationSpec): Button {
        animationSpec = value
        this
    }

    /** Applies an exact playback duration and curve. */
    public func animation(duration: UInt64, easing!: Easing = Motion.standard): Button {
        animation(AnimationSpec(duration: duration, easing: easing))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = max(1.0, ctx.resolve(pointSize))
        Size(min(available.w, max(72.0, ctx.renderer.textWidth(title, pointSize: ps) + 24.0)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let progress = interaction.animate(ctx, ctx.isHovered(controlId), ctx.isPressed(controlId), animationSpec)
        let visualFrame = animatedButtonFrame(frame, ctx.theme.motionLevel, progress)
        drawSurface(ctx, visualFrame, buttonStyle(ctx, progress))
        let textColor = match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
        ctx.renderer.textCenter(title, visualFrame, textColor, pointSize: max(1.0, ctx.resolve(pointSize)))
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, visualFrame, ctx.theme.controlRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        if (handlePointerClick(ctx, event, frame, controlId, onClick)) {
            return true
        }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY())
                    onClick()
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY())
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

    private func buttonStyle(ctx: UiContext, progress: InteractionProgress): SurfaceStyle {
        let base = match (customStyle) {
            case Some(value) => value
            case None => ctx.theme.buttonSurface(buttonRole)
        }
        animatedButtonSurface(ctx, base, buttonRole, progress)
    }
}

protected func animatedButtonFrame(frame: Rect, level: MotionLevel, progress: InteractionProgress): Rect {
    let amount = level.amplitude()
    let lift = progress.hover * amount * 0.9
    let inset = progress.press * amount * 0.75
    Rect(frame.x + inset, frame.y - lift + inset, max(0.0, frame.w - inset * 2.0),
        max(0.0, frame.h - inset * 2.0))
}

protected func animatedButtonSurface(
    ctx: UiContext,
    base: SurfaceStyle,
    role: ButtonRole,
    progress: InteractionProgress
): SurfaceStyle {
    let amount = ctx.theme.motionLevel.amplitude()
    let hoverFill = match (role) {
        case ButtonRole.Normal => ctx.theme.fieldActive
        case _ => base.fill.lerp(ctx.theme.accentText, min(0.16, 0.08 * amount))
    }
    let pressFill = match (role) {
        case ButtonRole.Normal => ctx.theme.accentSoft
        case _ => base.fill.lerp(ctx.theme.bg, min(0.24, 0.14 * amount))
    }
    let hovered = base.fill.lerp(hoverFill, progress.hover)
    base.withFill(hovered.lerp(pressFill, progress.press))
}
