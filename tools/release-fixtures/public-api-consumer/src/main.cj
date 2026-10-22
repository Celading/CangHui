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

private func verifyEditorTypography(): Unit {
    let renderer = Renderer.recordingHeadless()
    let ctx = UiContext(renderer, Theme.light())
    for (size in [Float32(12.0), Float32(32.0)]) {
        let text = State<String>("a你\nb好")
        let cursor = State<Int64>(5)
        let widget = TextArea(text, key: "public-typography", cursor: Some(cursor),
            anchor: Some(State<Int64>(5)), wrapMode: TextAreaWrapMode.SoftWrap)
            .lineHeight(Length(52.0, LengthUnit.Vp)).fontSize(size).fontFamily("Consumer face").bold()
        widget.layout(ctx, Rect(0.0, 0.0, 400.0, 220.0))
        ctx.focus("public-typography")
        widget.draw(ctx)
        let caret = ctx.textInputAnchorRect().getOrThrow()
        require(caret.y == 60.0 && caret.h == renderer.textHeight(pointSize: size,
            style: FontStyle(bold: true), font: "Consumer face"), "public editor typography geometry")
        require(widget.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 61.0)) &&
            cursor.value == 5 && text.value == "a你\nb好", "public editor row hit")
    }
}

private func verifyPublicScrollAppearance(): Unit {
    let ctx = UiContext(Renderer.recordingHeadless(), Theme.light())
    var cases: Int64 = 0
    for (width in [Float32(390.0), Float32(1024.0), Float32(1440.0)]) {
        for (mode in ["reserved", "overlay", "hidden", "transparent"]) {
            let bar = ScrollBarStyle(width: 12.0, margin: 3.0, radius: 6.0, trackRadius: 3.0,
                layout: if (mode == "overlay") {ScrollBarLayout.Overlay} else {ScrollBarLayout.Reserved},
                visibility: if (mode == "hidden") {ScrollBarVisibility.Hidden} else {ScrollBarVisibility.Automatic},
                opacity: if (mode == "transparent") {Float32(0.0)} else {Float32(1.0)},
                trackColor: Some(Color.rgb(10, 20, 30)), thumbColor: Some(Color.rgba(40, 50, 60, 200)),
                hoverColor: Some(Color.rgb(80, 90, 100)), activeColor: Some(Color.rgb(100, 110, 120)),
                interactionAnimation: Some(AnimationSpec.automatic(duration: 120)))
            let offset = State<Float32>(0.0)
            let child: Widget = Label("public scroll").height(500.0)
            let view = child.scrollable(key: "external-scroll", options: ScrollOptions.immediate(bar: bar))
                .scrollState(offset)
            view.layout(ctx, Rect(0.0, 0.0, width, 100.0))
            let metrics: ScrollMetrics = view.metrics()
            let reserved: Float32 = if (mode == "hidden" || mode == "overlay") {0.0} else {18.0}
            require(metrics.reservedRight == reserved && metrics.viewport.w == width - reserved,
                "public scroll reservation and metrics")
            require(view.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 30.0, 30.0)) && offset.value == 72.0,
                "public appearance does not disable scrolling")
            view.draw(ctx)
            view.layout(ctx, Rect(0.0, 0.0, width, 600.0))
            require(view.metrics().reservedRight == 0.0 && offset.value == 0.0,
                "public resize updates geometry and clamps offset")
            cases += 1
        }
    }
    println("SCROLL_APPEARANCE_PASS cases=${cases}")
}

main(): Int64 {
    verifyPublicScrollAppearance()
    verifyEditorTypography()
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
