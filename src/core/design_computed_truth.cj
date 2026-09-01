package chui.core

import std.collection.{ArrayList, HashSet}
import sdl.{Color, DrawIrCommand}

/** Stable categories used by computed design truth and node-scoped Draw IR evidence. */
public enum DesignComputedCategory {
    | Layout
    | Style
    | Typography
    | Paint
    | Resource
    | Clip
    | Transform
    | State
}

public func designComputedCategoryName(value: DesignComputedCategory): String {
    match (value) {
        case DesignComputedCategory.Layout => "layout"
        case DesignComputedCategory.Style => "style"
        case DesignComputedCategory.Typography => "typography"
        case DesignComputedCategory.Paint => "paint"
        case DesignComputedCategory.Resource => "resource"
        case DesignComputedCategory.Clip => "clip"
        case DesignComputedCategory.Transform => "transform"
        case DesignComputedCategory.State => "state"
    }
}

/** Wire value shape. Values stay strings so the canonical encoder never guesses JSON types. */
public enum DesignComputedValueKind {
    | Boolean
    | Integer
    | Number
    | Length
    | Color
    | Token
    | Text
    | Json
}

public func designComputedValueKindName(value: DesignComputedValueKind): String {
    match (value) {
        case DesignComputedValueKind.Boolean => "boolean"
        case DesignComputedValueKind.Integer => "integer"
        case DesignComputedValueKind.Number => "number"
        case DesignComputedValueKind.Length => "length"
        case DesignComputedValueKind.Color => "color"
        case DesignComputedValueKind.Token => "token"
        case DesignComputedValueKind.Text => "text"
        case DesignComputedValueKind.Json => "json"
    }
}

/** Identifies where a fact came from; it is evidence provenance, not editor policy. */
public enum DesignComputedProvenance {
    | RuntimeLayout
    | WidgetModifier
    | Container
    | DrawIr
    | Semantic
}

public func designComputedProvenanceName(value: DesignComputedProvenance): String {
    match (value) {
        case DesignComputedProvenance.RuntimeLayout => "runtime-layout"
        case DesignComputedProvenance.WidgetModifier => "widget-modifier"
        case DesignComputedProvenance.Container => "container"
        case DesignComputedProvenance.DrawIr => "draw-ir"
        case DesignComputedProvenance.Semantic => "semantic"
    }
}

/** One typed, resolved fact. `sourceValue` preserves the authored unit/value when available. */
public class DesignComputedFact {
    public let category: DesignComputedCategory
    public let name: String
    public let valueKind: DesignComputedValueKind
    public let value: String
    public let unit: String
    public let sourceValue: String
    public let provenance: DesignComputedProvenance

    public init(
        category: DesignComputedCategory,
        name: String,
        valueKind: DesignComputedValueKind,
        value: String,
        unit!: String = "",
        sourceValue!: String = "",
        provenance!: DesignComputedProvenance = DesignComputedProvenance.RuntimeLayout
    ) {
        validateComputedDesignToken(name, "computed fact name")
        validateComputedDesignValue(value, "computed fact value")
        if (!unit.isEmpty()) { validateComputedDesignToken(unit, "computed fact unit") }
        if (!sourceValue.isEmpty()) { validateComputedDesignValue(sourceValue, "computed fact source value") }
        this.category = category
        this.name = name
        this.valueKind = valueKind
        this.value = value
        this.unit = unit
        this.sourceValue = sourceValue
        this.provenance = provenance
    }

    public func identity(): String {
        designComputedCategoryName(category) + ":" + name
    }

    public func toJson(): String {
        "{\"category\":" + computedDesignQuote(designComputedCategoryName(category)) +
            ",\"name\":" + computedDesignQuote(name) +
            ",\"valueKind\":" + computedDesignQuote(designComputedValueKindName(valueKind)) +
            ",\"value\":" + computedDesignQuote(value) +
            ",\"unit\":" + computedDesignQuote(unit) +
            ",\"sourceValue\":" + computedDesignQuote(sourceValue) +
            ",\"provenance\":" + computedDesignQuote(designComputedProvenanceName(provenance)) + "}"
    }
}

/**
 * One stable node's computed facts and the exact Draw IR that produced its pixels.
 * Draw order is retained; facts are sorted by category/name for deterministic bytes.
 */
public class DesignComputedNode {
    public let nodeId: String
    public let facts: Array<DesignComputedFact>
    public let drawIr: Array<DrawIrCommand>

    public init(nodeId: String, facts!: Array<DesignComputedFact> = [],
        drawIr!: Array<DrawIrCommand> = []) {
        validateComputedDesignToken(nodeId, "computed node id")
        let ownedFacts = sortedComputedDesignFacts(facts)
        let identities = HashSet<String>()
        for (fact in ownedFacts) {
            if (identities.contains(fact.identity())) {
                throw IllegalArgumentException("duplicate computed design fact: " + fact.identity())
            }
            identities.add(fact.identity())
        }
        for (command in drawIr) {
            if (!command.scope.isEmpty() && command.scope != nodeId) {
                throw IllegalArgumentException("computed Draw IR scope does not match its node")
            }
        }
        this.nodeId = nodeId
        this.facts = ownedFacts
        this.drawIr = drawIr.clone()
    }

    public func toJson(): String {
        let out = StringBuilder()
        out.append("{\"nodeId\":")
        out.append(computedDesignQuote(nodeId))
        out.append(",\"facts\":[")
        var first = true
        for (fact in facts) {
            if (!first) { out.append(",") }
            first = false
            out.append(fact.toJson())
        }
        out.append("],\"drawIr\":[")
        first = true
        for (command in drawIr) {
            if (!first) { out.append(",") }
            first = false
            out.append("{\"category\":")
            out.append(computedDesignQuote(designComputedCategoryName(designDrawCategory(command.kind))))
            out.append(",\"command\":")
            out.append(command.toJson())
            out.append("}")
        }
        out.append("]}")
        out.toString()
    }
}

/** Default hook used by ComponentProbe; normal rendering does not allocate or call it. */
protected func emptyDesignComputedFacts(): Array<DesignComputedFact> { [] }

/** Adds/replaces facts by typed identity, preserving outer-modifier precedence. */
protected func mergeDesignComputedFacts(base: Array<DesignComputedFact>,
    additions: Array<DesignComputedFact>): Array<DesignComputedFact> {
    let result = ArrayList<DesignComputedFact>()
    for (fact in base) { result.add(fact) }
    for (fact in additions) {
        var i = result.size - 1
        while (i >= 0) {
            if (result[i].identity() == fact.identity()) { result.remove(at: i) }
            i -= 1
        }
        result.add(fact)
    }
    result.toArray()
}

protected func computedDesignLengthFact(name: String, resolved: Float32, source: String,
    provenance!: DesignComputedProvenance = DesignComputedProvenance.WidgetModifier): DesignComputedFact {
    DesignComputedFact(DesignComputedCategory.Layout, name, DesignComputedValueKind.Length,
        resolved.toString(), unit: "logical-pixel", sourceValue: source, provenance: provenance)
}

protected func computedDesignNumberFact(category: DesignComputedCategory, name: String, value: Float32,
    provenance: DesignComputedProvenance): DesignComputedFact {
    DesignComputedFact(category, name, DesignComputedValueKind.Number, value.toString(), provenance: provenance)
}

protected func computedDesignIntegerFact(category: DesignComputedCategory, name: String, value: Int64,
    provenance: DesignComputedProvenance): DesignComputedFact {
    DesignComputedFact(category, name, DesignComputedValueKind.Integer, value.toString(), provenance: provenance)
}

protected func computedDesignBoolFact(category: DesignComputedCategory, name: String, value: Bool,
    provenance: DesignComputedProvenance): DesignComputedFact {
    DesignComputedFact(category, name, DesignComputedValueKind.Boolean, value.toString(), provenance: provenance)
}

protected func computedDesignTokenFact(category: DesignComputedCategory, name: String, value: String,
    provenance: DesignComputedProvenance): DesignComputedFact {
    DesignComputedFact(category, name, DesignComputedValueKind.Token, value, provenance: provenance)
}

protected func computedDesignColor(value: Color): String {
    "rgba(${value.r},${value.g},${value.b},${value.a})"
}

protected func computedDesignColorFact(name: String, value: Color,
    provenance!: DesignComputedProvenance = DesignComputedProvenance.WidgetModifier): DesignComputedFact {
    DesignComputedFact(DesignComputedCategory.Style, name, DesignComputedValueKind.Color,
        computedDesignColor(value), unit: "rgba8", provenance: provenance)
}

private func designDrawCategory(kind: String): DesignComputedCategory {
    if (kind == "text") { return DesignComputedCategory.Typography }
    if (kind == "symbol" || kind.startsWith("resource.") || kind.contains("texture")) {
        return DesignComputedCategory.Resource
    }
    if (kind.startsWith("clip.")) { return DesignComputedCategory.Clip }
    if (kind.startsWith("transform.")) { return DesignComputedCategory.Transform }
    DesignComputedCategory.Paint
}

private func sortedComputedDesignFacts(values: Array<DesignComputedFact>): Array<DesignComputedFact> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1].identity() > value.identity()) {
            result[j] = result[j - 1]
            j -= 1
        }
        result[j] = value
        i += 1
    }
    result
}

private func validateComputedDesignToken(value: String, role: String): Unit {
    if (value.isEmpty() || value.toArray().size > 4096 || value.contains("\n") ||
        value.contains("\r") || value.contains("\u{0000}")) {
        throw IllegalArgumentException(role + " must be a bounded single-line value")
    }
}

private func validateComputedDesignValue(value: String, role: String): Unit {
    if (value.toArray().size > 16384 || value.contains("\n") || value.contains("\r") ||
        value.contains("\u{0000}")) {
        throw IllegalArgumentException(role + " must be a bounded single-line value")
    }
}

private func computedDesignQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (rune in value.toRuneArray()) {
        if (rune == r'\"') { out.append("\\\"") }
        else if (rune == r'\\') { out.append("\\\\") }
        else if (rune == r'\t') { out.append("\\t") }
        else { out.append(rune.toString()) }
    }
    out.append("\"")
    out.toString()
}
