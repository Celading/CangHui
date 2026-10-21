package chui_public_api_consumer

import chui.*
import std.collection.{ArrayList, HashSet}

private class FixtureSymbols <: SymbolProvider {
    public let paints = ArrayList<SymbolPaint>()

    public func id(): String { "consumer-fixture" }
    public func source(): SymbolProviderSource {
        SymbolProviderSource("https://example.invalid/symbol-fixture", "fixture-v1", "1", "MIT", "symbols")
    }
    public func descriptors(): Array<SymbolDescriptor> {
        [SymbolDescriptor("folder"), SymbolDescriptor("file")]
    }
    public func resolve(name: String, _: SymbolVariant): ?SymbolGlyph {
        if (name != "folder" && name != "file") { return None }
        Some(SymbolGlyph(id(), name, "symbols/" + name) {renderer, rect, paint =>
            paints.add(paint)
            renderer.fill(rect, paint.color)
        })
    }
}

func symbolPaintForFixture(): SymbolPaint {
    SymbolPaint(Color.rgb(1, 2, 3), 400.0, SymbolVariant.Outlined, SymbolDirection.Inherit, false)
}

private func verifyVisualLineResult(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let editor = TextArea(State<String>("abcdef\n末行"), key: "public-editor",
        wrapMode: TextAreaWrapMode.SoftWrap)
    let lines: Array<TextAreaVisualLine> = editor.visualLines(ctx, 24.0)
    require(lines.size > 2 && lines[0].startByte == 0 &&
        lines[lines.size - 1].endByte == "abcdef\n末行".size, "typed visualLines result")
}

private func verifyTreeScene(provider: FixtureSymbols, dark: Bool, selected: Bool, expanded: Bool): Unit {
    let renderer = Renderer.recordingHeadless()
    let theme = if (dark) { Theme.dark() } else { Theme.light() }
    let ctx = UiContext(renderer, theme)
    let expandedIds = HashSet<String>()
    if (expanded) { expandedIds.add("folder") }
    let selection = State<String>(if (selected) { "folder" } else { "" })
    let expansion = State<HashSet<String>>(expandedIds)
    let roots = [
        TreeNode("folder", "Folder", icon: IconName.OpenFolder,
            symbol: SymbolName("folder", provider: "consumer-fixture"), children: [
                TreeNode("file", "File", symbol: SymbolName("file", provider: "consumer-fixture"))
            ]),
        TreeNode("missing", "Missing", icon: IconName.Save,
            symbol: SymbolName("absent", provider: "unavailable-fixture")),
        TreeNode("legacy", "Legacy", icon: IconName.Save),
        TreeNode("empty", "Empty")
    ]
    require(roots[0].icon.isSome() && roots[0].symbol.isSome() && roots[2].symbol.isNone(),
        "legacy fields and additive symbol defaults")
    let tree = TreeView(roots, selection, expanded: Some(expansion), key: "public-tree")
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 240.0))
    provider.paints.clear()
    tree.draw(ctx)
    require(provider.paints.size == (if (expanded) { 2 } else { 1 }), "provider actual paint callbacks")
    let expected = if (selected) { theme.accentText } else { theme.text }
    let actual = provider.paints[0].color
    require(actual.r == expected.r && actual.g == expected.g && actual.b == expected.b,
        "provider receives selected/theme foreground")

    let out = StringBuilder()
    out.append("{\"dark\":${dark},\"selected\":${selected},\"expanded\":${expanded},\"commands\":[")
    var separator = ""
    var symbols: Int64 = 0
    var fallback = false
    for (command in renderer.drawIr()) {
        if (command.kind != "symbol") { continue }
        symbols += 1
        let json = command.toJson()
        if (json.contains("\"fallback\":true")) { fallback = true }
        out.append(separator); out.append(json); separator = ","
    }
    out.append("]}")
    require(symbols == (if (expanded) { 3 } else { 2 }) && fallback,
        "symbol slot precedence, visible children and shared missing fallback")
    println(out.toString())

    ctx.focus("public-tree")
    require(tree.handle(ctx, UiEvent.KeyDown(Key.Home, false)) && selection.value == "folder",
        "keyboard selection retained")
    require(tree.handle(ctx, UiEvent.KeyDown(Key.Right, false)) && expansion.value.contains("folder"),
        "keyboard expansion retained")
}

main(): Int64 {
    verifyFacadeContracts()
    verifyVisualLineResult()
    let provider = FixtureSymbols()
    Symbols.register(provider)
    for (dark in [false, true]) {
        for (selected in [false, true]) {
            for (expanded in [false, true]) { verifyTreeScene(provider, dark, selected, expanded) }
        }
    }
    println("PUBLIC_API_CONSUMER_PASS")
    0
}
