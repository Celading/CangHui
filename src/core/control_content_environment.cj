package cui.core

import std.collection.ArrayList
import sdl.{Color, DrawIrAsciiAnnotationKind, Rect}

/** Read-only visual and interaction state inherited by decorative control content. */
public struct ControlContentEnvironment {
    public let foreground: Color
    public let supportingForeground: Color
    public let role: String
    public let interactionOwner: String
    public let selected: Bool
    public let expanded: Bool
    public let focused: Bool
    public let hovered: Bool
    public let pressed: Bool

    public init(
        foreground: Color,
        supportingForeground!: ?Color = None,
        role!: String = "",
        interactionOwner!: String = "",
        selected!: Bool = false,
        expanded!: Bool = false,
        focused!: Bool = false,
        hovered!: Bool = false,
        pressed!: Bool = false
    ) {
        this.foreground = foreground
        this.supportingForeground = match (supportingForeground) {
            case Some(value) => value
            case None => foreground.withAlpha(Int64(foreground.a) * 3 / 4)
        }
        this.role = role
        this.interactionOwner = interactionOwner
        this.selected = selected
        this.expanded = expanded
        this.focused = focused
        this.hovered = hovered
        this.pressed = pressed
    }
}

/** One outer semantic action for a compound control and its decorative descendants. */
public struct ControlSemantics {
    public let role: String
    public let label: String
    public let value: String
    public let action: String
    public let shortcut: String
    public let actionOwner: String
    public let selected: ?Bool
    public let expanded: ?Bool

    public init(
        role: String,
        label!: String = "",
        value!: String = "",
        action!: String = "control.activate()",
        shortcut!: String = "Enter|Space",
        actionOwner!: String,
        selected!: ?Bool = None,
        expanded!: ?Bool = None
    ) {
        if (role.isEmpty()) { throw IllegalArgumentException("control semantic role must not be empty") }
        if (actionOwner.isEmpty()) { throw IllegalArgumentException("control semantic action owner must not be empty") }
        this.role = role
        this.label = label
        this.value = value
        this.action = action
        this.shortcut = shortcut
        this.actionOwner = actionOwner
        this.selected = selected
        this.expanded = expanded
    }
}

/** Records a compound-control region when a device-free ComponentProbe is active. */
public func recordControlSemantics(
    frame: Rect,
    widgetType: String,
    semantics: ControlSemantics
): Unit {
    if (!shouldRecordAutomaticControlSemantics(semantics.actionOwner)) { return }
    let properties = ArrayList<ProbeProperty>()
    properties.add(ProbeProperty("role", semantics.role))
    if (!semantics.label.isEmpty()) { properties.add(ProbeProperty("label", semantics.label)) }
    if (!semantics.value.isEmpty()) { properties.add(ProbeProperty("value", semantics.value)) }
    if (!semantics.action.isEmpty()) { properties.add(ProbeProperty("action", semantics.action)) }
    if (!semantics.shortcut.isEmpty()) { properties.add(ProbeProperty("shortcut", semantics.shortcut)) }
    properties.add(ProbeProperty("actionOwner", semantics.actionOwner))
    properties.add(ProbeProperty("semanticDescendants", "decorative"))
    match (semantics.selected) {
        case Some(value) => properties.add(ProbeProperty("selected", value.toString()))
        case None => ()
    }
    match (semantics.expanded) {
        case Some(value) => properties.add(ProbeProperty("expanded", value.toString()))
        case None => ()
    }
    probeSemanticRegions {=> [
        ProbeSemanticRegion(
            "control-semantic:" + semantics.actionOwner,
            DrawIrAsciiAnnotationKind.Interactive,
            frame,
            widgetType: widgetType,
            properties: properties.toArray()
        )
    ]}
}
