package chui.core

import std.collection.ArrayList
import sdl.{Color, Insets, Pen, Rect, Size, SurfaceStyle, UiEvent}

/**
 * Internal modifier vocabulary. Each chained call wraps the previous node, so modifier
 * order stays observable and predictable, matching the layout tree shown in source.
 * Sizes are stored as unit-carrying `Length` values and resolved against the active
 * `UiContext` scales during measure/layout, never at construction time.
 */
protected enum WidgetModifier {
    | Width(Length)
    | Height(Length)
    | MinWidth(Length)
    | MaxWidth(Length)
    | MinHeight(Length)
    | MaxHeight(Length)
    | FillWidth
    | FillHeight
    | Padding(LengthInsets)
    | Surface(SurfaceStyle)
    | Background(Color, Length)
    | PerCornerBackground(Corners, Color)
    | GradientBackground(Gradient, Length)
    | DropShadow(Shadow, Length)
    | MultiShadow(Array<Shadow>, Length)
    | Border(Color, Float32, Length)
    | DashedBorder(Color, Float32, Length, Float32, Float32)
    | Flex(Float32)
    | ZIndex(Int64)
    | Visible(Bool)
    | Enabled(Bool)
    | Typography(TypographyEnvironment)
}

class ModifiedWidget <: Widget {
    private let child: Widget
    private let modifier: WidgetModifier
    private var frame = Rect.zero()
    private var propertyMotion: ?ModifierPropertyMotion = None
    private var propertySpec = AnimationSpec.automatic(duration: Motion.normal)

    init(child: Widget, modifier: WidgetModifier) {
        this.child = child
        this.modifier = modifier
    }

    func configurePropertyAnimation(key: String, spec: AnimationSpec, index: Int64): Unit {
        // Modifier kind is part of identity: changing a width into padding must not reuse its channel.
        let kind = match (modifier) {
            case WidgetModifier.Width(_) => "width"
            case WidgetModifier.Height(_) => "height"
            case WidgetModifier.MinWidth(_) => "min-width"
            case WidgetModifier.MaxWidth(_) => "max-width"
            case WidgetModifier.MinHeight(_) => "min-height"
            case WidgetModifier.MaxHeight(_) => "max-height"
            case WidgetModifier.Padding(_) => "padding"
            case WidgetModifier.Background(_, _) => "background"
            case WidgetModifier.Border(_, _, _) => "border"
            case _ => ""
        }
        if (!kind.isEmpty()) {
            propertySpec = spec
            propertyMotion = Some(localState<ModifierPropertyMotion>(
                "PropertyMotion:${key}:${index}:${kind}") { ModifierPropertyMotion() }.value)
        }
        applyPropertyAnimation(child, key, spec, index: index + 1)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        match (modifier) {
            case WidgetModifier.Width(length) =>
                let value = exact(ctx, length)
                let childSize = child.measure(ctx, Size(min(value, available.w), available.h))
                Size(min(value, available.w), childSize.h)
            case WidgetModifier.Height(length) =>
                let value = exact(ctx, length)
                let childSize = child.measure(ctx, Size(available.w, min(value, available.h)))
                Size(childSize.w, min(value, available.h))
            case WidgetModifier.MinWidth(length) =>
                let childSize = child.measure(ctx, available)
                Size(min(available.w, max(exact(ctx, length), childSize.w)), childSize.h)
            case WidgetModifier.MaxWidth(length) =>
                let limit = min(exact(ctx, length), available.w)
                let childSize = child.measure(ctx, Size(limit, available.h))
                Size(min(limit, childSize.w), childSize.h)
            case WidgetModifier.MinHeight(length) =>
                let childSize = child.measure(ctx, available)
                Size(childSize.w, min(available.h, max(exact(ctx, length), childSize.h)))
            case WidgetModifier.MaxHeight(length) =>
                let limit = min(exact(ctx, length), available.h)
                let childSize = child.measure(ctx, Size(available.w, limit))
                Size(childSize.w, min(limit, childSize.h))
            case WidgetModifier.FillWidth =>
                let childSize = child.measure(ctx, available)
                Size(available.w, childSize.h)
            case WidgetModifier.FillHeight =>
                let childSize = child.measure(ctx, available)
                Size(childSize.w, available.h)
            case WidgetModifier.Padding(edges) => measurePadding(ctx, available, edges)
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.measure(ctx, available)
                } else {
                    Size.zero()
                }
            case WidgetModifier.Typography(environment) =>
                ctx.withTypographyEnvironment(environment) {=> child.measure(ctx, available) }
            case _ => child.measure(ctx, available)
        }
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        match (modifier) {
            case WidgetModifier.Width(length) =>
                child.layout(ctx, Rect(rect.x, rect.y, min(exact(ctx, length), rect.w), rect.h))
            case WidgetModifier.Height(length) =>
                child.layout(ctx, Rect(rect.x, rect.y, rect.w, min(exact(ctx, length), rect.h)))
            case WidgetModifier.MaxWidth(length) =>
                child.layout(ctx, Rect(rect.x, rect.y, min(exact(ctx, length), rect.w), rect.h))
            case WidgetModifier.MaxHeight(length) =>
                child.layout(ctx, Rect(rect.x, rect.y, rect.w, min(exact(ctx, length), rect.h)))
            case WidgetModifier.Padding(edges) => child.layout(ctx, rect.inset(animatedInsets(ctx, edges)))
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.layout(ctx, rect)
                }
            case WidgetModifier.Typography(environment) =>
                ctx.withTypographyEnvironment(environment) {=> child.layout(ctx, rect) }
            case _ => child.layout(ctx, rect)
        }
    }

    public func draw(ctx: UiContext): Unit {
        match (modifier) {
            case WidgetModifier.Surface(style) =>
                drawSurface(ctx, frame, style)
                child.draw(ctx)
            case WidgetModifier.Background(color, radius) =>
                drawSurface(ctx, frame, SurfaceStyle(animatedColor(ctx, color),
                    radius: scalar(ctx, 4, max(0.0, ctx.resolve(radius)))))
                child.draw(ctx)
            // A background whose four corners take independent radii (vp), resolved to pixels here so
            // they scale like every other radius. Painted before the child, mirroring Background.
            case WidgetModifier.PerCornerBackground(corners, color) =>
                ctx
                    .renderer
                    .fillPerCornerRoundedRect(frame, color, topLeft: ctx.resolve(vpLength(corners.topLeft)),
                        topRight: ctx.resolve(vpLength(corners.topRight)),
                        bottomRight: ctx.resolve(vpLength(corners.bottomRight)),
                        bottomLeft: ctx.resolve(vpLength(corners.bottomLeft)))
                child.draw(ctx)
            case WidgetModifier.GradientBackground(gradient, radius) =>
                ctx
                    .renderer
                    .fillRoundedRectGradient(frame, max(0.0, ctx.resolve(radius)), gradient.start, gradient.end,
                        vertical: gradient.vertical)
                child.draw(ctx)
            // The shadow is painted before the child so its halo sits behind the widget; a shadow
            // modifier is therefore chained after `background` and shares its corner radius.
            case WidgetModifier.DropShadow(shadow, radius) =>
                drawConfigurableShadow(ctx, frame, max(0.0, ctx.resolve(radius)), shadow)
                child.draw(ctx)
            // Layered shadows paint in array order (first is deepest), all behind the child — the
            // Material key-plus-ambient pair being the canonical use (see Shadow.keyAmbient).
            case WidgetModifier.MultiShadow(layers, radius) =>
                let r = max(0.0, ctx.resolve(radius))
                for (layer in layers) {
                    drawConfigurableShadow(ctx, frame, r, layer)
                }
                child.draw(ctx)
            // The border is painted after the child so it sits on top of the fill and content; the
            // stroke is centred on the edge (inset by half its width) and rounded to the radius.
            case WidgetModifier.Border(color, width, radius) =>
                child.draw(ctx)
                let strokeColor = animatedColor(ctx, color)
                let strokeWidth = scalar(ctx, 5, max(0.0, width))
                let r = scalar(ctx, 4, max(0.0, ctx.resolve(radius)))
                if (strokeWidth > 0.0 && Int64(strokeColor.a) > 0) {
                    ctx
                        .renderer
                        .strokeRoundedRect(frame.inset(strokeWidth / 2.0), max(0.0, r - strokeWidth / 2.0),
                            Pen(width: strokeWidth, color: strokeColor))
                }
            case WidgetModifier.DashedBorder(color, width, radius, dash, gap) =>
                child.draw(ctx)
                if (width > 0.0 && Int64(color.a) > 0) {
                    let r = max(0.0, ctx.resolve(radius))
                    ctx
                        .renderer
                        .strokeRoundedRectDashed(frame.inset(width / 2.0), max(0.0, r - width / 2.0),
                            Pen(width: width, color: color), dash: dash, gap: gap)
                }
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.draw(ctx)
                }
            case WidgetModifier.Enabled(isEnabled) =>
                ctx.withInteractionsEnabled(isEnabled) {=> child.draw(ctx)}
                if (!isEnabled) {
                    ctx.renderer.fill(frame, ctx.theme.bg.withAlpha(96))
                }
            case WidgetModifier.Typography(environment) =>
                ctx.withTypographyEnvironment(environment) {=> child.draw(ctx) }
            case _ => child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (modifier) {
            case WidgetModifier.Visible(isVisible) => isVisible && child.handle(ctx, event)
            case WidgetModifier.Enabled(isEnabled) =>
                // Disabled suppresses input, not time: the per-frame tick still flows, so a
                // wrapped Frame hook (e.g. dialog polling) keeps running while greyed out.
                match (event) {
                    case UiEvent.Frame(_) =>
                        let handled = [false]
                        ctx.withInteractionsEnabled(isEnabled) {=> handled[0] = child.handle(ctx, event)}
                        handled[0]
                    case _ => isEnabled && child.handle(ctx, event)
                }
            case WidgetModifier.Typography(environment) =>
                ctx.withTypographyEnvironment(environment) {=> child.handle(ctx, event) }
            case _ => child.handle(ctx, event)
        }
    }

    public func isFlexible(): Bool {
        match (modifier) {
            case WidgetModifier.Flex(_) => true
            case WidgetModifier.Visible(isVisible) => isVisible && child.isFlexible()
            case _ => child.isFlexible()
        }
    }

    public func flexWeight(): Float32 {
        match (modifier) {
            case WidgetModifier.Flex(weight) => weight
            case _ => child.flexWeight()
        }
    }

    public func acceptsStretch(axis: Axis): Bool {
        match (modifier) {
            // A size modifier pins its own axis and defers the other to the child, so a chain
            // like `.width(w).height(h)` reports both axes rigid — hard-coding the cross axis
            // to `true` here would mask an inner size modifier and break ZStack alignment.
            case WidgetModifier.Width(_) => match (axis) {
                case Axis.Horizontal => false
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.MaxWidth(_) => match (axis) {
                case Axis.Horizontal => false
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.Height(_) => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => false
            }
            case WidgetModifier.MaxHeight(_) => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => false
            }
            case WidgetModifier.FillWidth => match (axis) {
                case Axis.Horizontal => true
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.FillHeight => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => true
            }
            case _ => child.acceptsStretch(axis)
        }
    }

    public func participatesInLayout(): Bool {
        match (modifier) {
            case WidgetModifier.Visible(isVisible) => isVisible && child.participatesInLayout()
            case _ => child.participatesInLayout()
        }
    }

    public func stackingIndex(): Int64 {
        match (modifier) {
            case WidgetModifier.ZIndex(value) => value
            case _ => child.stackingIndex()
        }
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        child.interactionOwnerIds()
    }

    public func interactionsEnabled(): Bool {
        match (modifier) {
            case WidgetModifier.Enabled(isEnabled) => isEnabled && child.interactionsEnabled()
            case _ => child.interactionsEnabled()
        }
    }

    public func designComputedFacts(ctx: UiContext): Array<DesignComputedFact> {
        let additions = ArrayList<DesignComputedFact>()
        match (modifier) {
            case WidgetModifier.Width(value) =>
                additions.add(computedDesignLengthFact("constraint.width", exact(ctx, value), value.toString()))
            case WidgetModifier.Height(value) =>
                additions.add(computedDesignLengthFact("constraint.height", exact(ctx, value), value.toString()))
            case WidgetModifier.MinWidth(value) =>
                additions.add(computedDesignLengthFact("constraint.min-width", exact(ctx, value), value.toString()))
            case WidgetModifier.MaxWidth(value) =>
                additions.add(computedDesignLengthFact("constraint.max-width", exact(ctx, value), value.toString()))
            case WidgetModifier.MinHeight(value) =>
                additions.add(computedDesignLengthFact("constraint.min-height", exact(ctx, value), value.toString()))
            case WidgetModifier.MaxHeight(value) =>
                additions.add(computedDesignLengthFact("constraint.max-height", exact(ctx, value), value.toString()))
            case WidgetModifier.FillWidth => additions.add(computedDesignBoolFact(
                DesignComputedCategory.Layout, "constraint.fill-width", true,
                DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.FillHeight => additions.add(computedDesignBoolFact(
                DesignComputedCategory.Layout, "constraint.fill-height", true,
                DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.Padding(value) =>
                let edges = animatedInsets(ctx, value)
                additions.add(computedDesignLengthFact("padding.top", edges.top, value.top.toString()))
                additions.add(computedDesignLengthFact("padding.right", edges.right, value.right.toString()))
                additions.add(computedDesignLengthFact("padding.bottom", edges.bottom, value.bottom.toString()))
                additions.add(computedDesignLengthFact("padding.left", edges.left, value.left.toString()))
            case WidgetModifier.Surface(value) => appendComputedSurface(additions, value)
            case WidgetModifier.Background(color, radius) =>
                additions.add(computedDesignColorFact("background.color", animatedColor(ctx, color)))
                additions.add(computedDesignLengthFact(
                    "background.corner-radius", scalar(ctx, 4, max(0.0, ctx.resolve(radius))), radius.toString()))
            case WidgetModifier.PerCornerBackground(corners, color) =>
                additions.add(computedDesignColorFact("background.color", color))
                additions.add(computedDesignNumberFact(DesignComputedCategory.Style,
                    "background.corner.top-left", corners.topLeft, DesignComputedProvenance.WidgetModifier))
                additions.add(computedDesignNumberFact(DesignComputedCategory.Style,
                    "background.corner.top-right", corners.topRight, DesignComputedProvenance.WidgetModifier))
                additions.add(computedDesignNumberFact(DesignComputedCategory.Style,
                    "background.corner.bottom-right", corners.bottomRight, DesignComputedProvenance.WidgetModifier))
                additions.add(computedDesignNumberFact(DesignComputedCategory.Style,
                    "background.corner.bottom-left", corners.bottomLeft, DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.GradientBackground(gradient, radius) =>
                additions.add(computedDesignColorFact("gradient.start", gradient.start))
                additions.add(computedDesignColorFact("gradient.end", gradient.end))
                additions.add(computedDesignTokenFact(DesignComputedCategory.Style, "gradient.axis",
                    if (gradient.vertical) { "vertical" } else { "horizontal" },
                    DesignComputedProvenance.WidgetModifier))
                additions.add(computedDesignLengthFact(
                    "gradient.corner-radius", exact(ctx, radius), radius.toString()))
            case WidgetModifier.DropShadow(shadow, radius) =>
                appendComputedShadow(additions, shadow, 0)
                additions.add(computedDesignLengthFact(
                    "shadow.corner-radius", exact(ctx, radius), radius.toString()))
            case WidgetModifier.MultiShadow(layers, radius) =>
                for (i in 0..layers.size) { appendComputedShadow(additions, layers[i], i) }
                additions.add(computedDesignLengthFact(
                    "shadow.corner-radius", exact(ctx, radius), radius.toString()))
            case WidgetModifier.Border(color, width, radius) =>
                additions.add(computedDesignColorFact("border.color", animatedColor(ctx, color)))
                additions.add(computedDesignNumberFact(DesignComputedCategory.Style, "border.width",
                    scalar(ctx, 5, max(0.0, width)), DesignComputedProvenance.WidgetModifier))
                additions.add(computedDesignLengthFact("border.corner-radius",
                    scalar(ctx, 4, max(0.0, ctx.resolve(radius))), radius.toString()))
                additions.add(computedDesignBoolFact(DesignComputedCategory.Style, "border.dashed", false,
                    DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.DashedBorder(color, width, radius, dash, gap) =>
                appendComputedBorder(additions, ctx, color, width, radius, true, dash, gap)
            case WidgetModifier.Flex(weight) => additions.add(computedDesignNumberFact(
                DesignComputedCategory.Layout, "flex.weight", weight, DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.ZIndex(value) => additions.add(computedDesignIntegerFact(
                DesignComputedCategory.Layout, "stacking.z-index", value,
                DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.Visible(value) => additions.add(computedDesignBoolFact(
                DesignComputedCategory.State, "visible", value, DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.Enabled(value) => additions.add(computedDesignBoolFact(
                DesignComputedCategory.State, "enabled", value, DesignComputedProvenance.WidgetModifier))
            case WidgetModifier.Typography(value) => appendComputedTypography(additions, ctx, value)
        }
        mergeDesignComputedFacts(child.designComputedFacts(ctx), additions.toArray())
    }

    /** Resolves an exact-size length, clamped to non-negative logical pixels. */
    private func exact(ctx: UiContext, length: Length): Float32 {
        max(0.0, scalar(ctx, 0, max(0.0, ctx.resolve(length))))
    }

    private func scalar(ctx: UiContext, slot: Int64, target: Float32): Float32 {
        match (propertyMotion) {
            case Some(motion) => motion.scalar(ctx, slot, target, propertySpec)
            case None => target
        }
    }

    private func animatedColor(ctx: UiContext, value: Color): Color {
        match (propertyMotion) {
            case Some(motion) => motion.color(ctx, value, propertySpec)
            case None => value
        }
    }

    private func animatedInsets(ctx: UiContext, edges: LengthInsets): Insets {
        match (propertyMotion) {
            case Some(motion) => motion.insets(ctx, ctx.resolve(edges), propertySpec)
            case None => ctx.resolve(edges)
        }
    }

    private func measurePadding(ctx: UiContext, available: Size, edges: LengthInsets): Size {
        let resolved = animatedInsets(ctx, edges)
        let inner = Size(
            max(0.0, available.w - resolved.horizontal()),
            max(0.0, available.h - resolved.vertical())
        )
        let childSize = child.measure(ctx, inner)
        Size(
            min(available.w, childSize.w + resolved.horizontal()),
            min(available.h, childSize.h + resolved.vertical())
        )
    }
}

private func appendComputedSurface(target: ArrayList<DesignComputedFact>, value: SurfaceStyle): Unit {
    target.add(computedDesignColorFact("surface.fill", value.fill))
    target.add(computedDesignColorFact("surface.border", value.border))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, "surface.corner-radius", value.radius,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, "surface.border-width", value.borderWidth,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignColorFact("surface.shadow", value.shadow))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, "surface.shadow-offset-y",
        value.shadowOffsetY, DesignComputedProvenance.WidgetModifier))
}

private func appendComputedShadow(target: ArrayList<DesignComputedFact>, value: Shadow, index: Int64): Unit {
    let prefix = "shadow.layer." + index.toString()
    target.add(computedDesignColorFact(prefix + ".color", value.color))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, prefix + ".offset-x", value.offsetX,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, prefix + ".offset-y", value.offsetY,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, prefix + ".blur", value.blur,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, prefix + ".spread", value.spread,
        DesignComputedProvenance.WidgetModifier))
}

private func appendComputedBorder(target: ArrayList<DesignComputedFact>, ctx: UiContext, color: Color,
    width: Float32, radius: Length, dashed: Bool, dash: Float32, gap: Float32): Unit {
    target.add(computedDesignColorFact("border.color", color))
    target.add(computedDesignNumberFact(DesignComputedCategory.Style, "border.width", width,
        DesignComputedProvenance.WidgetModifier))
    target.add(computedDesignLengthFact("border.corner-radius", ctx.resolve(radius), radius.toString()))
    target.add(computedDesignBoolFact(DesignComputedCategory.Style, "border.dashed", dashed,
        DesignComputedProvenance.WidgetModifier))
    if (dashed) {
        target.add(computedDesignNumberFact(DesignComputedCategory.Style, "border.dash", dash,
            DesignComputedProvenance.WidgetModifier))
        target.add(computedDesignNumberFact(DesignComputedCategory.Style, "border.gap", gap,
            DesignComputedProvenance.WidgetModifier))
    }
}

private func appendComputedTypography(target: ArrayList<DesignComputedFact>, ctx: UiContext,
    value: TypographyEnvironment): Unit {
    match (value.fontFamily) {
        case Some(family) => target.add(computedDesignTokenFact(DesignComputedCategory.Typography,
            "font.family", family, DesignComputedProvenance.WidgetModifier))
        case None => ()
    }
    match (value.fontSize) {
        case Some(size) => target.add(DesignComputedFact(DesignComputedCategory.Typography,
            "font.size", DesignComputedValueKind.Length, ctx.resolve(size).toString(),
            unit: "logical-pixel", sourceValue: size.toString(),
            provenance: DesignComputedProvenance.WidgetModifier))
        case None => ()
    }
    appendOptionalComputedTypographyBool(target, "font.bold", value.bold)
    appendOptionalComputedTypographyBool(target, "font.italic", value.italic)
    appendOptionalComputedTypographyBool(target, "font.underline", value.underline)
    appendOptionalComputedTypographyBool(target, "font.strikethrough", value.strikethrough)
}

private func appendOptionalComputedTypographyBool(target: ArrayList<DesignComputedFact>, name: String,
    value: ?Bool): Unit {
    match (value) {
        case Some(actual) => target.add(computedDesignBoolFact(DesignComputedCategory.Typography,
            name, actual, DesignComputedProvenance.WidgetModifier))
        case None => ()
    }
}

protected func applyModifier(widget: Widget, modifier: WidgetModifier): Widget {
    let modified = ModifiedWidget(widget, modifier)
    replaceLastEmission(widget, modified)
    modified
}
