package chui.core

import std.collection.{ArrayList, HashSet}
import sdl.DrawIrCommand

/** Additive editable-design envelope. V1 remains embedded byte-for-byte and keeps its own protocol. */
public const CANGHUI_DESIGN_SNAPSHOT_V2_PROTOCOL: String = "canghui.design-snapshot/v2"
public const DESIGN_SNAPSHOT_V2_HARD_MAX_COMPONENT_BINDINGS: Int64 = 4096
public const DESIGN_SNAPSHOT_V2_HARD_MAX_INTERACTIONS: Int64 = 8192
public const DESIGN_SNAPSHOT_V2_HARD_MAX_SCENES: Int64 = 64
public const DESIGN_SNAPSHOT_V2_HARD_MAX_COMPUTED_NODES: Int64 = DESIGN_SNAPSHOT_HARD_MAX_NODES
public const DESIGN_SNAPSHOT_V2_HARD_MAX_COMPUTED_FACTS: Int64 = DESIGN_SNAPSHOT_HARD_MAX_PROPERTIES

/** Project-neutral source location used for design-to-code navigation, never execution. */
public struct DesignSourceBinding {
    public let packageName: String
    public let symbol: String
    public let relativePath: String
    public let line: Int64
    public let column: Int64
    public let sourceDigest: String
    public let resourceDigest: String

    public init(
        packageName: String,
        symbol: String,
        relativePath: String,
        line!: Int64 = 0,
        column!: Int64 = 0,
        sourceDigest!: String = "",
        resourceDigest!: String = ""
    ) {
        validateDesignV2Token(packageName, "design source package")
        validateDesignV2Token(symbol, "design source symbol")
        validateDesignV2RelativePath(relativePath)
        if (line < 0 || column < 0) {
            throw IllegalArgumentException("design source line and column cannot be negative")
        }
        validateDesignV2Sha256(sourceDigest, "design source digest")
        validateDesignV2Sha256(resourceDigest, "design resource digest")
        this.packageName = packageName
        this.symbol = symbol
        this.relativePath = relativePath
        this.line = line
        this.column = column
        this.sourceDigest = sourceDigest
        this.resourceDigest = resourceDigest
    }
}

/** One stable runtime/design node mapped to a public component and its editable surface. */
public class DesignComponentBinding {
    public let nodeId: String
    public let componentSymbol: String
    public let source: DesignSourceBinding
    public let publicProperties: Array<String>
    public let variants: Array<String>
    public let slots: Array<String>

    public init(
        nodeId: String,
        componentSymbol: String,
        source: DesignSourceBinding,
        publicProperties!: Array<String> = [],
        variants!: Array<String> = [],
        slots!: Array<String> = []
    ) {
        validateDesignV2Identifier(nodeId, "design component node id")
        validateDesignV2Token(componentSymbol, "design component symbol")
        this.nodeId = nodeId
        this.componentSymbol = componentSymbol
        this.source = source
        this.publicProperties = sortedUniqueDesignV2Tokens(publicProperties, "design public property")
        this.variants = sortedUniqueDesignV2Tokens(variants, "design component variant")
        this.slots = sortedUniqueDesignV2Tokens(slots, "design component slot")
    }
}

public enum DesignInteractionTrigger {
    | Click
    | DoubleClick
    | LongPress
    | HoverEnter
    | HoverExit
    | Focus
    | Blur
    | Key
    | Submit
    | ValueChange
    | DragStart
    | DragUpdate
    | DragEnd
    | GamepadActivate
}

public func designInteractionTriggerName(value: DesignInteractionTrigger): String {
    match (value) {
        case DesignInteractionTrigger.Click => "click"
        case DesignInteractionTrigger.DoubleClick => "double-click"
        case DesignInteractionTrigger.LongPress => "long-press"
        case DesignInteractionTrigger.HoverEnter => "hover-enter"
        case DesignInteractionTrigger.HoverExit => "hover-exit"
        case DesignInteractionTrigger.Focus => "focus"
        case DesignInteractionTrigger.Blur => "blur"
        case DesignInteractionTrigger.Key => "key"
        case DesignInteractionTrigger.Submit => "submit"
        case DesignInteractionTrigger.ValueChange => "value-change"
        case DesignInteractionTrigger.DragStart => "drag-start"
        case DesignInteractionTrigger.DragUpdate => "drag-update"
        case DesignInteractionTrigger.DragEnd => "drag-end"
        case DesignInteractionTrigger.GamepadActivate => "gamepad-activate"
    }
}

public enum DesignInteractionTargetKind {
    | Action
    | Route
    | State
    | Component
    | ExternalIntent
}

public func designInteractionTargetKindName(value: DesignInteractionTargetKind): String {
    match (value) {
        case DesignInteractionTargetKind.Action => "action"
        case DesignInteractionTargetKind.Route => "route"
        case DesignInteractionTargetKind.State => "state"
        case DesignInteractionTargetKind.Component => "component"
        case DesignInteractionTargetKind.ExternalIntent => "external-intent"
    }
}

/** A declarative edge. Handler fields identify source; no callback body or executable payload is carried. */
public class DesignInteractionBinding {
    public let id: String
    public let ownerNodeId: String
    public let trigger: DesignInteractionTrigger
    public let targetKind: DesignInteractionTargetKind
    public let targetId: String
    public let handlerPackage: String
    public let handlerSymbol: String
    public let handlerRelativePath: String
    public let handlerSourceDigest: String
    public let shortcut: String
    public let enabled: Bool

    public init(
        id: String,
        ownerNodeId: String,
        trigger: DesignInteractionTrigger,
        targetKind: DesignInteractionTargetKind,
        targetId: String,
        handlerPackage!: String = "",
        handlerSymbol!: String = "",
        handlerRelativePath!: String = "",
        handlerSourceDigest!: String = "",
        shortcut!: String = "",
        enabled!: Bool = true
    ) {
        validateDesignV2Identifier(id, "design interaction id")
        validateDesignV2Identifier(ownerNodeId, "design interaction owner node id")
        validateDesignV2Identifier(targetId, "design interaction target id")
        let hasHandler = !handlerPackage.isEmpty() || !handlerSymbol.isEmpty() ||
            !handlerRelativePath.isEmpty() || !handlerSourceDigest.isEmpty()
        if (hasHandler) {
            validateDesignV2Token(handlerPackage, "design handler package")
            validateDesignV2Token(handlerSymbol, "design handler symbol")
            validateDesignV2RelativePath(handlerRelativePath)
        }
        validateDesignV2Sha256(handlerSourceDigest, "design handler source digest")
        if (!shortcut.isEmpty()) { validateDesignV2Token(shortcut, "design interaction shortcut") }
        this.id = id
        this.ownerNodeId = ownerNodeId
        this.trigger = trigger
        this.targetKind = targetKind
        this.targetId = targetId
        this.handlerPackage = handlerPackage
        this.handlerSymbol = handlerSymbol
        this.handlerRelativePath = handlerRelativePath
        this.handlerSourceDigest = handlerSourceDigest
        this.shortcut = shortcut
        this.enabled = enabled
    }
}

public enum DesignDeviceClass {
    | Phone
    | Tablet
    | Desktop
    | Foldable
    | TwoInOne
}

public func designDeviceClassName(value: DesignDeviceClass): String {
    match (value) {
        case DesignDeviceClass.Phone => "phone"
        case DesignDeviceClass.Tablet => "tablet"
        case DesignDeviceClass.Desktop => "desktop"
        case DesignDeviceClass.Foldable => "foldable"
        case DesignDeviceClass.TwoInOne => "two-in-one"
    }
}

public enum DesignOrientation {
    | Portrait
    | Landscape
    | Adaptive
}

public func designOrientationName(value: DesignOrientation): String {
    match (value) {
        case DesignOrientation.Portrait => "portrait"
        case DesignOrientation.Landscape => "landscape"
        case DesignOrientation.Adaptive => "adaptive"
    }
}

public enum DesignInputClass {
    | Touch
    | Pointer
    | Keyboard
    | Gamepad
}

public func designInputClassName(value: DesignInputClass): String {
    match (value) {
        case DesignInputClass.Touch => "touch"
        case DesignInputClass.Pointer => "pointer"
        case DesignInputClass.Keyboard => "keyboard"
        case DesignInputClass.Gamepad => "gamepad"
    }
}

public struct DesignSafeAreaInsets {
    public let top: Float32
    public let right: Float32
    public let bottom: Float32
    public let left: Float32

    public init(top!: Float32 = 0.0, right!: Float32 = 0.0, bottom!: Float32 = 0.0,
        left!: Float32 = 0.0) {
        if (top < 0.0 || right < 0.0 || bottom < 0.0 || left < 0.0) {
            throw IllegalArgumentException("design safe-area insets cannot be negative")
        }
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }
}

/** CangHui design guidance attached to one scenario, not a platform-owned visual policy. */
public struct DesignSceneRecommendation {
    public let minimumTargetWidth: Float32
    public let minimumTargetHeight: Float32
    public let minimumInteractiveGap: Float32
    public let recommendedColumns: Int64
    public let navigationPattern: String

    public init(
        minimumTargetWidth: Float32,
        minimumTargetHeight: Float32,
        minimumInteractiveGap: Float32,
        recommendedColumns: Int64,
        navigationPattern: String
    ) {
        if (minimumTargetWidth <= 0.0 || minimumTargetHeight <= 0.0 || minimumInteractiveGap < 0.0 ||
            recommendedColumns <= 0) {
            throw IllegalArgumentException("design recommendation dimensions and columns are invalid")
        }
        validateDesignV2Token(navigationPattern, "design navigation pattern")
        this.minimumTargetWidth = minimumTargetWidth
        this.minimumTargetHeight = minimumTargetHeight
        this.minimumInteractiveGap = minimumInteractiveGap
        this.recommendedColumns = recommendedColumns
        this.navigationPattern = navigationPattern
    }
}

/** One explicit adaptation target. Device rotation selects a new scene/layout; it does not rotate the whole UI. */
public class DesignAdaptiveScene {
    public let id: String
    public let deviceClass: DesignDeviceClass
    public let orientation: DesignOrientation
    public let viewportWidth: Float32
    public let viewportHeight: Float32
    public let densityScale: Float32
    public let fontScale: Float32
    public let safeArea: DesignSafeAreaInsets
    public let inputClasses: Array<DesignInputClass>
    public let styleProfile: String
    public let recommendation: DesignSceneRecommendation

    public init(
        id: String,
        deviceClass: DesignDeviceClass,
        orientation: DesignOrientation,
        viewportWidth: Float32,
        viewportHeight: Float32,
        densityScale: Float32,
        fontScale: Float32,
        safeArea: DesignSafeAreaInsets,
        inputClasses: Array<DesignInputClass>,
        styleProfile: String,
        recommendation: DesignSceneRecommendation
    ) {
        validateDesignV2Identifier(id, "design adaptive scene id")
        if (viewportWidth <= 0.0 || viewportHeight <= 0.0 || densityScale <= 0.0 || fontScale <= 0.0) {
            throw IllegalArgumentException("design scene viewport, density and font scale must be positive")
        }
        if (inputClasses.isEmpty()) { throw IllegalArgumentException("design scene needs an input class") }
        validateDesignV2Token(styleProfile, "design style profile")
        this.id = id
        this.deviceClass = deviceClass
        this.orientation = orientation
        this.viewportWidth = viewportWidth
        this.viewportHeight = viewportHeight
        this.densityScale = densityScale
        this.fontScale = fontScale
        this.safeArea = safeArea
        this.inputClasses = sortedUniqueDesignInputClasses(inputClasses)
        this.styleProfile = styleProfile
        this.recommendation = recommendation
    }
}

/** Recommended common-layout design targets. They are preview contracts, not platform runtime proof. */
public func cangHuiRecommendedDesignScenes(): Array<DesignAdaptiveScene> {
    [
        DesignAdaptiveScene("phone-compact-3x", DesignDeviceClass.Phone, DesignOrientation.Portrait,
            390.0, 844.0, 3.0, 1.0, DesignSafeAreaInsets(top: 47.0, bottom: 34.0),
            [DesignInputClass.Touch], "common-mobile",
            DesignSceneRecommendation(48.0, 48.0, 8.0, 4, "bottom-bar-or-navigation-rail")),
        DesignAdaptiveScene("tablet-medium-2x", DesignDeviceClass.Tablet, DesignOrientation.Adaptive,
            800.0, 1100.0, 2.0, 1.0, DesignSafeAreaInsets(),
            [DesignInputClass.Touch, DesignInputClass.Pointer, DesignInputClass.Keyboard], "common-tablet",
            DesignSceneRecommendation(44.0, 44.0, 8.0, 8, "navigation-rail-or-master-detail")),
        DesignAdaptiveScene("desktop-expanded-1x", DesignDeviceClass.Desktop, DesignOrientation.Landscape,
            1440.0, 900.0, 1.0, 1.0, DesignSafeAreaInsets(),
            [DesignInputClass.Pointer, DesignInputClass.Keyboard, DesignInputClass.Gamepad], "common-desktop",
            DesignSceneRecommendation(32.0, 32.0, 6.0, 12, "sidebar-or-master-detail")),
        DesignAdaptiveScene("desktop-expanded-2x", DesignDeviceClass.Desktop, DesignOrientation.Landscape,
            1440.0, 900.0, 2.0, 1.0, DesignSafeAreaInsets(),
            [DesignInputClass.Pointer, DesignInputClass.Keyboard], "common-desktop",
            DesignSceneRecommendation(32.0, 32.0, 6.0, 12, "sidebar-or-master-detail")),
        DesignAdaptiveScene("foldable-medium-2x", DesignDeviceClass.Foldable, DesignOrientation.Adaptive,
            720.0, 900.0, 2.0, 1.0, DesignSafeAreaInsets(),
            [DesignInputClass.Touch, DesignInputClass.Pointer], "common-foldable",
            DesignSceneRecommendation(48.0, 48.0, 8.0, 8, "adaptive-pane")),
        DesignAdaptiveScene("two-in-one-expanded-2x", DesignDeviceClass.TwoInOne, DesignOrientation.Adaptive,
            1280.0, 800.0, 2.0, 1.15, DesignSafeAreaInsets(),
            [DesignInputClass.Touch, DesignInputClass.Pointer, DesignInputClass.Keyboard], "common-two-in-one",
            DesignSceneRecommendation(44.0, 44.0, 8.0, 12, "adaptive-sidebar"))
    ]
}

/** Deterministic v2 extension envelope around one immutable v1 hard-truth snapshot. */
public class DesignSnapshotV2 {
    public let base: DesignSnapshot
    public let componentBindings: Array<DesignComponentBinding>
    public let interactions: Array<DesignInteractionBinding>
    public let scenes: Array<DesignAdaptiveScene>
    public let computedNodes: Array<DesignComputedNode>
    public let contentDigest: String
    private let canonicalContent: String

    public init(
        base: DesignSnapshot,
        componentBindings!: Array<DesignComponentBinding> = [],
        interactions!: Array<DesignInteractionBinding> = [],
        scenes!: Array<DesignAdaptiveScene> = [],
        computedNodes!: Array<DesignComputedNode> = []
    ) {
        if (componentBindings.size > DESIGN_SNAPSHOT_V2_HARD_MAX_COMPONENT_BINDINGS ||
            interactions.size > DESIGN_SNAPSHOT_V2_HARD_MAX_INTERACTIONS ||
            scenes.size > DESIGN_SNAPSHOT_V2_HARD_MAX_SCENES ||
            computedNodes.size > DESIGN_SNAPSHOT_V2_HARD_MAX_COMPUTED_NODES) {
            throw IllegalArgumentException("design snapshot v2 extension exceeds a hard item limit")
        }
        let ownedBindings = sortedDesignComponentBindings(componentBindings)
        let ownedInteractions = sortedDesignInteractionBindings(interactions)
        let ownedScenes = sortedDesignAdaptiveScenes(scenes)
        let ownedComputedNodes = sortedDesignComputedNodes(computedNodes)
        validateDesignSnapshotV2References(base, ownedBindings, ownedInteractions, ownedComputedNodes)
        this.base = base
        this.componentBindings = ownedBindings
        this.interactions = ownedInteractions
        this.scenes = ownedScenes
        this.computedNodes = ownedComputedNodes
        this.canonicalContent = renderDesignSnapshotV2Content(
            base, ownedBindings, ownedInteractions, ownedScenes, ownedComputedNodes)
        if (canonicalContent.toArray().size > DESIGN_SNAPSHOT_HARD_MAX_TEXT_BYTES) {
            throw IllegalArgumentException("design snapshot v2 exceeds the hard text byte limit")
        }
        this.contentDigest = designSnapshotV2StableDigest(canonicalContent)
    }

    public func toJson(): String {
        "{\"protocol\":" + designV2Quote(CANGHUI_DESIGN_SNAPSHOT_V2_PROTOCOL) +
            ",\"contentDigest\":" + designV2Quote(contentDigest) +
            ",\"content\":" + canonicalContent + "}"
    }
}

private func renderDesignSnapshotV2Content(base: DesignSnapshot,
    bindings: Array<DesignComponentBinding>, interactions: Array<DesignInteractionBinding>,
    scenes: Array<DesignAdaptiveScene>, computedNodes: Array<DesignComputedNode>): String {
    let out = StringBuilder()
    out.append("{\"schemaVersion\":2,\"base\":")
    out.append(base.toJson())
    out.append(",\"componentBindings\":[")
    var first = true
    for (value in bindings) {
        if (!first) { out.append(",") }
        first = false
        out.append(renderDesignComponentBinding(value))
    }
    out.append("],\"interactions\":[")
    first = true
    for (value in interactions) {
        if (!first) { out.append(",") }
        first = false
        out.append(renderDesignInteractionBinding(value))
    }
    out.append("],\"scenes\":[")
    first = true
    for (value in scenes) {
        if (!first) { out.append(",") }
        first = false
        out.append(renderDesignAdaptiveScene(value))
    }
    out.append("]")
    // Optional by design: omitting this member preserves every existing v2 canonical byte.
    if (!computedNodes.isEmpty()) {
        out.append(",\"computedNodes\":[")
        first = true
        for (value in computedNodes) {
            if (!first) { out.append(",") }
            first = false
            out.append(value.toJson())
        }
        out.append("]")
    }
    out.append("}")
    out.toString()
}

private func renderDesignComponentBinding(value: DesignComponentBinding): String {
    "{\"nodeId\":" + designV2Quote(value.nodeId) +
        ",\"componentSymbol\":" + designV2Quote(value.componentSymbol) +
        ",\"source\":" + renderDesignSourceBinding(value.source) +
        ",\"publicProperties\":" + renderDesignV2Strings(value.publicProperties) +
        ",\"variants\":" + renderDesignV2Strings(value.variants) +
        ",\"slots\":" + renderDesignV2Strings(value.slots) + "}"
}

private func renderDesignSourceBinding(value: DesignSourceBinding): String {
    "{\"package\":" + designV2Quote(value.packageName) +
        ",\"symbol\":" + designV2Quote(value.symbol) +
        ",\"relativePath\":" + designV2Quote(value.relativePath) +
        ",\"line\":" + value.line.toString() +
        ",\"column\":" + value.column.toString() +
        ",\"sourceDigest\":" + designV2Quote(value.sourceDigest) +
        ",\"resourceDigest\":" + designV2Quote(value.resourceDigest) + "}"
}

private func renderDesignInteractionBinding(value: DesignInteractionBinding): String {
    "{\"id\":" + designV2Quote(value.id) +
        ",\"ownerNodeId\":" + designV2Quote(value.ownerNodeId) +
        ",\"trigger\":" + designV2Quote(designInteractionTriggerName(value.trigger)) +
        ",\"targetKind\":" + designV2Quote(designInteractionTargetKindName(value.targetKind)) +
        ",\"targetId\":" + designV2Quote(value.targetId) +
        ",\"handlerPackage\":" + designV2Quote(value.handlerPackage) +
        ",\"handlerSymbol\":" + designV2Quote(value.handlerSymbol) +
        ",\"handlerRelativePath\":" + designV2Quote(value.handlerRelativePath) +
        ",\"handlerSourceDigest\":" + designV2Quote(value.handlerSourceDigest) +
        ",\"shortcut\":" + designV2Quote(value.shortcut) +
        ",\"enabled\":" + value.enabled.toString() + "}"
}

private func renderDesignAdaptiveScene(value: DesignAdaptiveScene): String {
    let out = StringBuilder()
    out.append("{\"id\":")
    out.append(designV2Quote(value.id))
    out.append(",\"deviceClass\":")
    out.append(designV2Quote(designDeviceClassName(value.deviceClass)))
    out.append(",\"orientation\":")
    out.append(designV2Quote(designOrientationName(value.orientation)))
    out.append(",\"viewportWidth\":")
    out.append(value.viewportWidth)
    out.append(",\"viewportHeight\":")
    out.append(value.viewportHeight)
    out.append(",\"densityScale\":")
    out.append(value.densityScale)
    out.append(",\"fontScale\":")
    out.append(value.fontScale)
    out.append(",\"safeArea\":{\"top\":")
    out.append(value.safeArea.top)
    out.append(",\"right\":")
    out.append(value.safeArea.right)
    out.append(",\"bottom\":")
    out.append(value.safeArea.bottom)
    out.append(",\"left\":")
    out.append(value.safeArea.left)
    out.append("},\"inputClasses\":[")
    var first = true
    for (input in value.inputClasses) {
        if (!first) { out.append(",") }
        first = false
        out.append(designV2Quote(designInputClassName(input)))
    }
    out.append("],\"styleProfile\":")
    out.append(designV2Quote(value.styleProfile))
    out.append(",\"recommendation\":{\"minimumTargetWidth\":")
    out.append(value.recommendation.minimumTargetWidth)
    out.append(",\"minimumTargetHeight\":")
    out.append(value.recommendation.minimumTargetHeight)
    out.append(",\"minimumInteractiveGap\":")
    out.append(value.recommendation.minimumInteractiveGap)
    out.append(",\"recommendedColumns\":")
    out.append(value.recommendation.recommendedColumns)
    out.append(",\"navigationPattern\":")
    out.append(designV2Quote(value.recommendation.navigationPattern))
    out.append("}}")
    out.toString()
}

private func validateDesignSnapshotV2References(base: DesignSnapshot,
    bindings: Array<DesignComponentBinding>, interactions: Array<DesignInteractionBinding>,
    computedNodes: Array<DesignComputedNode>): Unit {
    let nodeIds = HashSet<String>()
    let stateIds = HashSet<String>()
    for (node in base.nodes) {
        nodeIds.add(node.id)
        match (node.kind) {
            case DesignSnapshotNodeKind.State => stateIds.add(node.id)
            case _ => ()
        }
    }
    for (state in base.states) { stateIds.add(state.key) }
    let boundNodes = HashSet<String>()
    for (binding in bindings) {
        if (!nodeIds.contains(binding.nodeId)) {
            throw IllegalArgumentException("design component binding references an unknown node: " + binding.nodeId)
        }
        if (boundNodes.contains(binding.nodeId)) {
            throw IllegalArgumentException("duplicate design component binding node id")
        }
        boundNodes.add(binding.nodeId)
    }
    let interactionIds = HashSet<String>()
    for (interaction in interactions) {
        if (interactionIds.contains(interaction.id)) {
            throw IllegalArgumentException("duplicate design interaction id")
        }
        interactionIds.add(interaction.id)
        if (!nodeIds.contains(interaction.ownerNodeId)) {
            throw IllegalArgumentException("design interaction references an unknown owner node")
        }
        match (interaction.targetKind) {
            case DesignInteractionTargetKind.Component =>
                if (!nodeIds.contains(interaction.targetId)) {
                    throw IllegalArgumentException("design interaction references an unknown component target")
                }
            case DesignInteractionTargetKind.State =>
                if (!stateIds.contains(interaction.targetId)) {
                    throw IllegalArgumentException("design interaction references an unknown state target")
                }
            case _ => ()
        }
    }
    if (!computedNodes.isEmpty()) {
        if (computedNodes.size != base.nodes.size) {
            throw IllegalArgumentException("computed design truth must cover every base node")
        }
        var factCount: Int64 = 0
        var drawCount: Int64 = 0
        let computedIds = HashSet<String>()
        for (computed in computedNodes) {
            if (!nodeIds.contains(computed.nodeId)) {
                throw IllegalArgumentException("computed design truth references an unknown node")
            }
            if (computedIds.contains(computed.nodeId)) {
                throw IllegalArgumentException("duplicate computed design node id")
            }
            computedIds.add(computed.nodeId)
            factCount += computed.facts.size
            drawCount += computed.drawIr.size
            for (command in computed.drawIr) {
                if (command.scope.isEmpty() && !designSnapshotV2ScreenNode(base, computed.nodeId)) {
                    throw IllegalArgumentException("unscoped Draw IR may only belong to the screen node")
                }
            }
            validateComputedDrawIrExactlyMatchesBase(base, computed)
        }
        if (factCount > DESIGN_SNAPSHOT_V2_HARD_MAX_COMPUTED_FACTS) {
            throw IllegalArgumentException("computed design truth exceeds the hard fact limit")
        }
        if (drawCount != base.drawIr.size) {
            throw IllegalArgumentException("computed design truth must account for every Draw IR command")
        }
        for (command in base.drawIr) {
            if (!command.scope.isEmpty() && !nodeIds.contains(command.scope)) {
                throw IllegalArgumentException("DesignSnapshot v2 contains an orphan Draw IR scope")
            }
        }
    }
}

private func validateComputedDrawIrExactlyMatchesBase(base: DesignSnapshot,
    computed: DesignComputedNode): Unit {
    let expected = ArrayList<DrawIrCommand>()
    let screen = designSnapshotV2ScreenNode(base, computed.nodeId)
    for (command in base.drawIr) {
        if ((command.scope.isEmpty() && screen) || command.scope == computed.nodeId) {
            expected.add(command)
        }
    }
    if (expected.size != computed.drawIr.size) {
        throw IllegalArgumentException("computed node Draw IR does not match its base scope")
    }
    for (i in 0..expected.size) {
        let left = expected[i]
        let right = computed.drawIr[i]
        if (left.kind != right.kind || left.scope != right.scope || left.data != right.data) {
            throw IllegalArgumentException("computed node Draw IR changed base command bytes or order")
        }
    }
}

private func designSnapshotV2ScreenNode(base: DesignSnapshot, nodeId: String): Bool {
    for (node in base.nodes) {
        if (node.id == nodeId) {
            return match (node.kind) { case DesignSnapshotNodeKind.Screen => true case _ => false }
        }
    }
    false
}

private func sortedDesignComponentBindings(values: Array<DesignComponentBinding>): Array<DesignComponentBinding> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].nodeId > value.nodeId) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    result
}

private func sortedDesignInteractionBindings(values: Array<DesignInteractionBinding>): Array<DesignInteractionBinding> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].id > value.id) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    result
}

private func sortedDesignAdaptiveScenes(values: Array<DesignAdaptiveScene>): Array<DesignAdaptiveScene> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].id > value.id) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    var previous = ""
    for (value in result) {
        if (value.id == previous) { throw IllegalArgumentException("duplicate design adaptive scene id") }
        previous = value.id
    }
    result
}

private func sortedDesignComputedNodes(values: Array<DesignComputedNode>): Array<DesignComputedNode> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].nodeId > value.nodeId) {
            result[j] = result[j - 1]
            j -= 1
        }
        result[j] = value
        i += 1
    }
    result
}

private func sortedUniqueDesignInputClasses(values: Array<DesignInputClass>): Array<DesignInputClass> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && designInputClassName(result[j - 1]) > designInputClassName(value)) {
            result[j] = result[j - 1]
            j -= 1
        }
        result[j] = value
        i += 1
    }
    let unique = ArrayList<DesignInputClass>()
    var previous = ""
    for (value in result) {
        let name = designInputClassName(value)
        if (name != previous) { unique.add(value); previous = name }
    }
    unique.toArray()
}

private func sortedUniqueDesignV2Tokens(values: Array<String>, role: String): Array<String> {
    let result = values.clone()
    for (value in result) { validateDesignV2Token(value, role) }
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1] > value) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value
        i += 1
    }
    let unique = ArrayList<String>()
    for (value in result) {
        if (unique.isEmpty() || unique[unique.size - 1] != value) { unique.add(value) }
    }
    unique.toArray()
}

private func renderDesignV2Strings(values: Array<String>): String {
    let out = StringBuilder()
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(designV2Quote(value))
    }
    out.append("]")
    out.toString()
}

private func validateDesignV2Identifier(value: String, role: String): Unit {
    validateDesignV2Token(value, role)
    if (value.startsWith("/") || value.startsWith("./") || value.startsWith("~") ||
        containsDesignV2DotSegment(value) || value.contains("\\") || value.contains("://")) {
        throw IllegalArgumentException(role + " cannot contain a filesystem path or URL")
    }
}

private func validateDesignV2RelativePath(value: String): Unit {
    validateDesignV2Token(value, "design source relative path")
    if (value.startsWith("/") || value.startsWith("./") || value.startsWith("~") ||
        containsDesignV2DotSegment(value) || value.contains("\\") || value.contains("://") || value.contains(":")) {
        throw IllegalArgumentException("design source path must be a portable project-relative path")
    }
}

private func containsDesignV2DotSegment(value: String): Bool {
    for (segment in value.split("/")) {
        if (segment == "." || segment == "..") { return true }
    }
    false
}

private func validateDesignV2Token(value: String, role: String): Unit {
    if (value.isEmpty() || value.toArray().size > 4096 || value.contains("\n") || value.contains("\r") ||
        value.contains("\u{0000}")) {
        throw IllegalArgumentException(role + " must be a bounded single-line value")
    }
}

private func validateDesignV2Sha256(value: String, role: String): Unit {
    if (value.isEmpty()) { return }
    if (value.size != 71 || !value.startsWith("sha256:")) {
        throw IllegalArgumentException(role + " must be sha256: plus 64 lowercase hex characters")
    }
    let runes = value.toRuneArray()
    var i: Int64 = 7
    while (i < runes.size) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) {
            throw IllegalArgumentException(role + " must use lowercase hexadecimal")
        }
        i += 1
    }
}

private func designSnapshotV2StableDigest(value: String): String {
    var code: Int64 = 53
    for (byte in value.toArray()) { code = (code * 137 + Int64(byte)) % 2147483647 }
    "chui-hash-v2:" + value.toArray().size.toString() + ":" + max(Int64(1), code).toString()
}

private func designV2Quote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (rune in value.toRuneArray()) {
        if (rune == r'\"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\n') { out.append("\\n") }
        else if (rune == r'\r') { out.append("\\r") }
        else if (rune == r'\t') { out.append("\\t") }
        else { out.append(rune.toString()) }
    }
    out.append("\"")
    out.toString()
}
