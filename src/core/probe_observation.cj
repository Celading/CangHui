package chui.core

import std.collection.ArrayList
import sdl.{Rect, drawIrAnnotationVisibility}
import chui.probe.probeJsonQuote

// A bounded view of existing DesignSnapshot/UI-health owners, not a second semantic tree.
internal func renderProbeObservation(snapshot: DesignSnapshot, baseline: DesignSnapshot, mode: String,
    limit: Int64, selectedId: String, overlay: Bool, ok: Bool, revision: UInt64): String {
    let selected = ArrayList<DesignSnapshotNode>()
    for (node in snapshot.nodes) {
        if (selectedId.isEmpty() || node.id == selectedId || node.parentId == selectedId) { selected.add(node) }
    }
    let found = selectedId.isEmpty() || snapshot.nodes.any({n => n.id == selectedId})
    let success = ok && found
    let audit = UiHealthAudit.analyze(snapshot)
    let out = StringBuilder()
    let json = mode == "json" || mode == "diff"
    if (json) {
        out.append("{\"protocol\":\"canghui.observation/v1\",\"ok\":${success},\"probe\":")
        out.append(observationQuote(snapshot.identifier))
        out.append(",\"digest\":" + observationQuote(snapshot.contentDigest))
        out.append(",\"inputRevision\":${revision},\"overlayActive\":${overlay},\"nodeCount\":${selected.size}")
        out.append(",\"viewport\":[${snapshot.environment.viewportWidth},${snapshot.environment.viewportHeight}]")
        out.append(",\"omittedNodes\":${max(0, selected.size - limit)},\"diagnosticCount\":${audit.diagnostics.size}")
        out.append(",\"coverage\":\"instrumented headless nodes only; clip/occlusion/native-surface hit coverage unverified\"")
        out.append(",\"error\":" + observationQuote(if (found) { if (ok) { "" } else { "probe-failed; inspect probe run --json" } }
            else { "node-not-found" }))
    } else {
        out.append("CangHui prntx | ok=${success} | probe=" + observationQuote(snapshot.identifier) + "\n")
        out.append("digest=${snapshot.contentDigest} input-revision=${revision} overlay=${overlay}\n")
        out.append("viewport=${snapshot.environment.viewportWidth}x${snapshot.environment.viewportHeight}\n")
        out.append("nodes=${selected.size} omitted=${max(0, selected.size - limit)} diagnostics=${audit.diagnostics.size}\n")
        out.append("Coverage: instrumented headless nodes only; clipping/occlusion/native surfaces unverified. No action permission is implied.\n")
        if (!found) { out.append("ERROR: node-not-found\n") }
        if (!ok) { out.append("ERROR: probe-failed; inspect probe run --json\n") }
    }
    if (mode == "diff") {
        let diff = snapshot.diff(baseline)
        out.append(",\"fromDigest\":" + observationQuote(diff.fromDigest) + ",\"changes\":{")
        appendObservationDiff(out, "structure", diff.structure, limit)
        out.append(",")
        appendObservationDiff(out, "geometry", diff.geometry, limit)
        out.append(",")
        appendObservationDiff(out, "style", diff.style, limit)
        out.append(",")
        appendObservationDiff(out, "state", diff.state, limit)
        out.append(",")
        appendObservationDiff(out, "draw", diff.draw, limit)
        out.append("}}")
        return out.toString()
    }
    if (json) { out.append(",\"nodes\":[") }
    let ordered = if (mode == "tree") { observationTreeOrder(selected.toArray(), selectedId, limit) } else { selected.toArray() }
    for (i in 0..min(limit, ordered.size)) {
        let node = ordered[i]
        let visibility = drawIrAnnotationVisibility(node.frame, snapshot.environment.viewportWidth,
            snapshot.environment.viewportHeight)
        let state = observationState(node)
        let disabled = state.contains("disabled=true") || state.contains("enabled=false")
        let actionability = if (disabled) { "disabled" } else if (visibility != "visible") { "unavailable-viewport" }
            else if (overlay) { "overlay-unverified" } else { "unverified-hit-coverage" }
        let label = if (node.role == "password") { "[redacted]" } else { node.label }
        if (json) {
            if (i > 0) { out.append(",") }
            out.append("{\"id\":" + observationQuote(node.id) + ",\"parent\":" + observationQuote(node.parentId))
            out.append(",\"type\":" + observationQuote(node.widgetType) + ",\"label\":" + observationQuote(label))
            out.append(",\"role\":" + observationQuote(node.role) + ",\"icon\":" + observationQuote(observationProperty(node, "icon")))
            out.append(",\"actionBinding\":" + observationQuote(observationProperty(node, "action")))
            out.append(",\"rect\":" + observationRect(node.frame) + ",\"visibility\":" + observationQuote(visibility))
            out.append(",\"state\":" + observationQuote(state))
            out.append(",\"actionability\":" + observationQuote(actionability) + "}")
        } else {
            if (mode == "tree") {
                var parent = node.parentId
                var depth: Int64 = 0
                while (!parent.isEmpty() && node.id != selectedId && depth < 64) {
                    out.append("  ")
                    depth += 1
                    var next = ""
                    for (candidate in ordered) { if (candidate.id == parent) { next = candidate.parentId; break } }
                    parent = next
                }
            }
            out.append(observationQuote(node.id) + " <- " + observationQuote(node.parentId) + " " +
                observationQuote(node.widgetType) + " " + observationRect(node.frame) + " " + visibility + "\n")
            out.append("  " + observationQuote(label) + " | " + actionability + " | " + observationQuote(state) + "\n")
            let icon = observationProperty(node, "icon")
            let action = observationProperty(node, "action")
            if (!icon.isEmpty() || !action.isEmpty()) {
                out.append("  icon=" + observationQuote(icon) + " binding=" + observationQuote(action) + "\n")
            }
        }
    }
    if (json) { out.append("],\"diagnostics\":[") }
    for (i in 0..min(limit, audit.diagnostics.size)) {
        let diagnostic = audit.diagnostics[i]
        if (json) {
            if (i > 0) { out.append(",") }
            out.append("{\"code\":" + observationQuote(diagnostic.code) + ",\"id\":" +
                observationQuote(diagnostic.componentId) + ",\"severity\":" +
                observationQuote(uiHealthSeverityName(diagnostic.severity)) + ",\"evidenceSource\":" +
                observationQuote(diagnostic.evidenceSource) + ",\"message\":" + observationQuote(diagnostic.message) +
                ",\"suggestion\":" + observationQuote(diagnostic.suggestion) + "}")
        } else {
            out.append("! " + uiHealthSeverityName(diagnostic.severity) + " " + observationQuote(diagnostic.code) + " " + observationQuote(diagnostic.componentId) +
                " " + observationQuote(diagnostic.message) + "\n")
        }
    }
    if (json) { out.append("],\"omittedDiagnostics\":${max(0, audit.diagnostics.size - limit)}}") }
    out.toString()
}

private func observationQuote(value: String): String {
    // Values/raw input/Draw IR are deliberately absent. Escape control characters and cap text.
    let runes = value.toRuneArray()
    probeJsonQuote(if (runes.size <= 256) { value } else { runeSlice(runes, 0, 256) + "…[truncated]" })
}

private func observationRect(rect: Rect): String { "[${rect.x},${rect.y},${rect.w},${rect.h}]" }

private func observationProperty(node: DesignSnapshotNode, key: String): String {
    for (property in node.states) { if (property.key == key) { return property.value } }
    ""
}

private func observationTreeOrder(nodes: Array<DesignSnapshotNode>, selectedId: String, limit: Int64): Array<DesignSnapshotNode> {
    let pending = ArrayList<DesignSnapshotNode>()
    let ordered = ArrayList<DesignSnapshotNode>()
    var i = nodes.size - 1
    while (i >= 0) {
        if (nodes[i].parentId.isEmpty() || nodes[i].id == selectedId) { pending.add(nodes[i]) }
        i -= 1
    }
    while (!pending.isEmpty() && ordered.size < limit) {
        let node = pending.remove(at: pending.size - 1)
        ordered.add(node)
        i = nodes.size - 1
        while (i >= 0) {
            if (nodes[i].parentId == node.id) { pending.add(nodes[i]) }
            i -= 1
        }
    }
    ordered.toArray()
}

private func observationState(node: DesignSnapshotNode): String {
    let out = StringBuilder()
    for (property in node.states) {
        if (["focused", "hovered", "pressed", "disabled", "enabled", "selected", "checked", "expanded"].contains(property.key)) {
            out.append(property.key + "=" + property.value + " ")
        }
    }
    out.toString()
}

private func appendObservationDiff(out: StringBuilder, name: String, ids: Array<String>, limit: Int64): Unit {
    out.append(observationQuote(name) + ":{\"count\":${ids.size},\"omitted\":${max(0, ids.size - limit)},\"ids\":[")
    for (i in 0..min(limit, ids.size)) {
        if (i > 0) { out.append(",") }
        out.append(observationQuote(ids[i]))
    }
    out.append("]}")
}
