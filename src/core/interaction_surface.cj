package cui.core

import std.collection.ArrayList
import sdl.{DrawIrAsciiAnnotationKind, Key, Rect, Size, UiEvent}

/** Semantic role owned by one `InteractionSurface`. */
public enum ControlRole {
    | Button
    | Link
    | Checkbox
    | Switch
    | Custom(String)

    public func name(): String {
        match (this) {
            case Button => "button"
            case Link => "link"
            case Checkbox => "checkbox"
            case Switch => "switch"
            case Custom(value) => value
        }
    }
}

/**
 * A one-owner interaction primitive for arbitrary decorative content. It owns exactly one focus id,
 * pressed state, release-inside action and semantic region. Focusable descendants are invalid: they
 * are removed from the Tab ring, reported to ComponentProbe and both outer and nested actions fail closed.
 */
public class InteractionSurface <: Widget {
    private let child: Widget
    private let action: () -> Unit
    private let controlRole: ControlRole
    private let semanticLabel: String
    private let isReadOnly: Bool
    private let isSelected: ?Bool
    private let isExpanded: ?Bool
    private var controlId: String
    private let nestedFocusIds: Array<String>
    private var materialProvider: MaterialProvider
    private var surfaceShape: Shape
    private var clipPolicy: ClipPolicy
    private var frame = Rect.zero()

    public init(
        action!: () -> Unit,
        role!: ControlRole = ControlRole.Button,
        accessibilityLabel!: String = "",
        key!: ?String = None,
        readOnly!: Bool = false,
        selected!: ?Bool = None,
        expanded!: ?Bool = None,
        body!: () -> Unit
    ) {
        if (role.name().isEmpty()) {
            throw IllegalArgumentException("InteractionSurface role must not be empty")
        }
        this.action = action
        this.controlRole = role
        this.semanticLabel = accessibilityLabel
        this.isReadOnly = readOnly
        this.isSelected = selected
        this.isExpanded = expanded
        let focusStart = focusableCountNow()
        this.child = buildChild(body)
        let registered = focusablesSince(focusStart)
        this.nestedFocusIds = collectNestedFocusIds(child, registered)
        for (id in nestedFocusIds) { unregisterFocusable(id) }
        this.controlId = resolveControlKey(key, "InteractionSurface")
        if (!isReadOnly && nestedFocusIds.isEmpty()) { registerFocusable(controlId) }
        this.materialProvider = Materials.themeSurface()
        this.surfaceShape = Shape.rectangle()
        this.clipPolicy = ClipPolicy.Unclipped
        emit(this)
    }

    /** Replaces the auto-derived interaction identity with a stable explicit key. */
    public func key(value: String): InteractionSurface {
        requireControlId(value, "InteractionSurface")
        if (!isReadOnly && nestedFocusIds.isEmpty()) { reregisterFocusable(controlId, value) }
        controlId = value
        this
    }

    /** Configures the visual material and the shared surface/ink shape. */
    public func surface(
        shape: Shape,
        material: MaterialProvider,
        clip!: ClipPolicy = ClipPolicy.Shape
    ): InteractionSurface {
        surfaceShape = shape
        materialProvider = material
        clipPolicy = clip
        this
    }

    /** Stable structural diagnostic, or `None` when the decorative slot has one owner. */
    public func structuralDiagnostic(): ?String {
        if (nestedFocusIds.isEmpty()) { return None }
        Some("nested-interaction-owner: " + joinFocusIds(nestedFocusIds))
    }

    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        let state = currentState(ctx)
        let material = materialProvider.resolve(ctx.theme, state)
        drawMaterialSurface(ctx, frame, surfaceShape, material)
        recordControlSemantics(ctx, frame, "InteractionSurface", ControlSemantics(
            controlRole.name(),
            label: semanticLabel,
            action: if (state.enabled) {"InteractionSurface.activate()"} else {""},
            shortcut: if (state.enabled) {"Enter|Space"} else {""},
            actionOwner: controlId,
            selected: isSelected,
            expanded: isExpanded,
            enabled: Some(state.enabled),
            readOnly: Some(state.readOnly)
        ))
        recordNestedInteractionDiagnostic()
        ctx.withControlContentEnvironment(ControlContentEnvironment(
            material.foreground,
            supportingForeground: Some(material.supportingForeground),
            role: controlRole.name(),
            interactionOwner: controlId,
            selected: match (isSelected) {case Some(value) => value case None => false},
            expanded: match (isExpanded) {case Some(value) => value case None => false},
            focused: state.focused,
            hovered: state.hovered,
            pressed: state.pressed,
            enabled: state.enabled,
            readOnly: state.readOnly
        )) {=>
            withSurfaceClip(ctx, frame, clipPolicy) {=> child.draw(ctx)}
        }
        if (state.enabled && ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, surfaceShape.cornerRadius())
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let state = currentState(ctx)
        if (!state.enabled) { return false }
        let material = materialProvider.resolve(ctx.theme, state)
        if (handlePointerClick(ctx, event, frame, controlId, action,
            inkRadius: surfaceShape.cornerRadius(), inkColor: Some(material.ink))) {
            return true
        }
        match (event) {
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    activateFromKeyboard(ctx, material)
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    activateFromKeyboard(ctx, material)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        if (isReadOnly || !nestedFocusIds.isEmpty()) { None } else { Some(controlId) }
    }

    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }

    private func currentState(ctx: UiContext): SurfaceState {
        let enabled = ctx.interactionsEnabled() && !isReadOnly && nestedFocusIds.isEmpty()
        SurfaceState(
            enabled: enabled,
            readOnly: isReadOnly,
            selected: match (isSelected) {case Some(value) => value case None => false},
            expanded: match (isExpanded) {case Some(value) => value case None => false},
            focused: enabled && ctx.hasFocus(controlId),
            hovered: enabled && ctx.isHovered(controlId),
            pressed: enabled && ctx.isPressed(controlId)
        )
    }

    private func activateFromKeyboard(ctx: UiContext, material: SurfaceMaterial): Unit {
        ctx.startInkRipple(controlId, frame, frame.centerX(), frame.centerY(),
            color: Some(material.ink), cornerRadius: surfaceShape.cornerRadius())
        action()
    }

    private func recordNestedInteractionDiagnostic(): Unit {
        if (nestedFocusIds.isEmpty()) { return }
        let descendants = joinFocusIds(nestedFocusIds)
        recordProbeStructuralError("nested-interaction-owner",
            "InteractionSurface " + controlId + " contains focusable descendants: " + descendants)
        probeSemanticRegions {=> [
            ProbeSemanticRegion(
                "interaction-diagnostic:" + controlId,
                DrawIrAsciiAnnotationKind.Visual,
                frame,
                widgetType: "InteractionSurfaceDiagnostic",
                properties: [
                    ProbeProperty("diagnostic", "nested-interaction-owner"),
                    ProbeProperty("severity", "error"),
                    ProbeProperty("actionOwner", controlId),
                    ProbeProperty("descendantFocusIds", descendants)
                ]
            )
        ]}
    }
}

private func collectNestedFocusIds(child: Widget, registered: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (id in registered) { addFocusIdIfAbsent(result, id) }
    for (id in child.focusableIds()) { addFocusIdIfAbsent(result, id) }
    result.toArray()
}

private func addFocusIdIfAbsent(values: ArrayList<String>, id: String): Unit {
    if (!values.contains(id)) { values.add(id) }
}

private func joinFocusIds(values: Array<String>): String {
    let out = StringBuilder()
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(value)
    }
    out.toString()
}
