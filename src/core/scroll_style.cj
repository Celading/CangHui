package chui.core

import sdl.{Color, Rect}

/** Automatic shows chrome only on overflow; Hidden removes chrome and its hit lane. */
public enum ScrollBarVisibility { | Automatic | Hidden }
/** Reserved keeps chrome outside content; Overlay leaves content geometry unchanged. */
public enum ScrollBarLayout { | Automatic | Reserved | Overlay }

/** Shared logical-pixel scrollbar appearance. Explicit colors keep their own alpha. */
public struct ScrollBarStyle {
    public let visibility: ScrollBarVisibility
    public let layout: ScrollBarLayout
    public let width: Float32
    public let margin: Float32
    public let minThumbLength: Float32
    public let radius: Float32
    public let trackRadius: Float32
    public let opacity: Float32
    public let trackOpacity: Float32
    public let thumbOpacity: Float32
    public let hoverOpacity: Float32
    public let activeOpacity: Float32
    public let trackColor: ?Color
    public let thumbColor: ?Color
    public let hoverColor: ?Color
    public let activeColor: ?Color
    /** None preserves direct state changes; Some animates thumb hover/active color and opacity. */
    public let interactionAnimation: ?AnimationSpec

    public init(visibility!: ScrollBarVisibility = ScrollBarVisibility.Automatic,
        layout!: ScrollBarLayout = ScrollBarLayout.Automatic, width!: Float32 = 6.0,
        margin!: Float32 = 2.0, minThumbLength!: Float32 = 18.0,
        radius!: Float32 = 0.0, trackRadius!: Float32 = 0.0,
        opacity!: Float32 = 1.0, trackOpacity!: Float32 = Float32(80.0 / 255.0),
        thumbOpacity!: Float32 = Float32(180.0 / 255.0),
        hoverOpacity!: Float32 = Float32(180.0 / 255.0),
        activeOpacity!: Float32 = Float32(230.0 / 255.0),
        trackColor!: ?Color = None, thumbColor!: ?Color = None,
        hoverColor!: ?Color = None, activeColor!: ?Color = None,
        interactionAnimation!: ?AnimationSpec = None) {
        if (!(width > 0.0 && width <= 4096.0)) {
            throw IllegalArgumentException("scrollbar width must be finite and in (0,4096]")
        }
        for (value in [margin, minThumbLength, radius, trackRadius]) {
            if (!(value >= 0.0 && value <= 4096.0)) {
                throw IllegalArgumentException("scrollbar geometry must be finite and in [0,4096]")
            }
        }
        for (value in [opacity, trackOpacity, thumbOpacity, hoverOpacity, activeOpacity]) {
            if (!(value >= 0.0 && value <= 1.0)) {
                throw IllegalArgumentException("scrollbar opacity must be finite and in [0,1]")
            }
        }
        this.visibility = visibility
        this.layout = layout
        this.width = width
        this.margin = margin
        this.minThumbLength = minThumbLength
        this.radius = radius
        this.trackRadius = trackRadius
        this.opacity = opacity
        this.trackOpacity = trackOpacity
        this.thumbOpacity = thumbOpacity
        this.hoverOpacity = hoverOpacity
        this.activeOpacity = activeOpacity
        this.trackColor = trackColor
        this.thumbColor = thumbColor
        this.hoverColor = hoverColor
        this.activeColor = activeColor
        this.interactionAnimation = interactionAnimation
    }

    public func hidden(): Bool {
        match (visibility) { case ScrollBarVisibility.Hidden => true case _ => false }
    }

    /** Fully transparent chrome must not steal child pointer input. */
    public func interactive(): Bool {
        let normal = match (thumbColor) { case Some(c) => c.a > 0 case None => true }
        let hovered = match (hoverColor) { case Some(c) => c.a > 0 case None => normal }
        let active = match (activeColor) { case Some(c) => c.a > 0 case None => hovered }
        !hidden() && opacity > 0.0 && ((thumbOpacity > 0.0 && normal) ||
            (hoverOpacity > 0.0 && hovered) || (activeOpacity > 0.0 && active))
    }
}

/** Current post-layout geometry; before the first layout the rectangles are empty. */
public struct ScrollMetrics {
    public let viewport: Rect
    public let contentWidth: Float32
    public let contentHeight: Float32
    public let offsetX: Float32
    public let offsetY: Float32
    public let reservedRight: Float32
    public let reservedBottom: Float32
    public init(viewport: Rect, contentWidth: Float32, contentHeight: Float32,
        offsetX: Float32, offsetY: Float32, reservedRight: Float32, reservedBottom: Float32) {
        this.viewport = viewport
        this.contentWidth = contentWidth
        this.contentHeight = contentHeight
        this.offsetX = offsetX
        this.offsetY = offsetY
        this.reservedRight = reservedRight
        this.reservedBottom = reservedBottom
    }
}

protected class ScrollBarVisual {
    let hover = Animator(0.0)
    let active = Animator(0.0)
    func color(ctx: UiContext, style: ScrollBarStyle, hovered: Bool, dragging: Bool): Color {
        let h: Float32 = if (hovered) {1.0} else {0.0}
        let a: Float32 = if (dragging) {1.0} else {0.0}
        var hp = h
        var ap = a
        match (style.interactionAnimation) {
            case Some(spec) =>
                if (ctx.theme.reduceMotion) { hover.reset(h); active.reset(a) }
                else {
                    hp = hover.animate(ctx, target: h, spec: spec)
                    ap = active.animate(ctx, target: a, spec: spec)
                }
            case None => hover.reset(h); active.reset(a)
        }
        let base = match (style.thumbColor) { case Some(c) => c case None => ctx.theme.accent.withAlpha(255) }
        let over = match (style.hoverColor) { case Some(c) => c case None => base }
        let down = match (style.activeColor) { case Some(c) => c case None => over }
        let normal = scrollBarAlpha(base, style.opacity * style.thumbOpacity)
        let hoverColor = scrollBarAlpha(over, style.opacity * style.hoverOpacity)
        let activeColor = scrollBarAlpha(down, style.opacity * style.activeOpacity)
        normal.lerp(hoverColor, hp).lerp(activeColor, ap)
    }
}

internal func scrollBarAlpha(color: Color, opacity: Float32): Color {
    color.withAlpha(Int64(Float32(color.a) * opacity + 0.0001))
}

/** Embedded controls retain their intrinsic text padding; widen it only for admitted chrome. */
protected func scrollBarContentInset(style: ScrollBarStyle, existing: Float32,
    contentInset!: Float32 = 0.0): Float32 {
    if (style.hidden()) { return 0.0 }
    match (style.layout) { case ScrollBarLayout.Overlay => return 0.0 case _ => () }
    max(0.0, style.width + style.margin + contentInset - existing)
}
