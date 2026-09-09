package chui.core

import sdl.Rect

private func semanticGlyphFixture(): SemanticTextLayout {
    SemanticTextLayout("A", [SemanticTextGlyph(0, 1, 0, Rect(0.0, 0.0, 8.0, 18.0), false)])
}

@Test
func semanticGlyphLayoutsOwnTheirStorageAndFollowSnapshotCopies(): Unit {
    let input = [SemanticTextGlyph(0, 1, 0, Rect(0.0, 0.0, 8.0, 18.0), false)]
    let layout = SemanticTextLayout("A", input)
    input[0] = SemanticTextGlyph(0, 1, 0, Rect(999.0, 0.0, 8.0, 18.0), true)
    @Expect(layout.glyph(0).frame.x, Float32(0.0))
    let runtime = SemanticRuntime("glyphs")
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", ControlSemantics("textfield", value: "A", actionOwner: "field",
        textGeometry: Some(SemanticTextGeometry(layout, 4.0, 5.0))))
    let first = runtime.commitFrame()
    let session = SemanticNativeSession("glyphs")
    session.publish(first)
    @Expect(session.snapshot().getOrThrow().tree.nodes[0].textGeometry.getOrThrow().layout.glyph(0).frame.w, Float32(8.0))
    runtime.beginFrame()
    runtime.record(Rect.zero(), "TextField", ControlSemantics("textfield", value: "A", actionOwner: "field",
        textGeometry: Some(SemanticTextGeometry(layout, 3.0, 5.0))))
    let second = runtime.commitFrame()
    @Expect(runtime.diff(first).changed, ["field"])
    @Expect(first.sameContent(second, includeGeometry: false))
    @Expect(!first.sameContent(second))
    @Expect(first.nodes[0].textGeometry.getOrThrow().x, Float32(4.0))
    session.close()
}

@Test
func semanticGlyphLayoutsRejectMismatchesAndSuppressPasswordGeometry(): Unit {
    let geometry = Some(SemanticTextGeometry(semanticGlyphFixture(), 0.0, 0.0))
    @Expect(ControlSemantics("password", value: "secret", actionOwner: "pw", textGeometry: geometry).textGeometry.isNone())
    @Expect(SemanticNode("pw", Rect.zero(), "TextField", "password", value: "secret", textGeometry: geometry).textGeometry.isNone())
    var rejected: Int64 = 0
    try { ControlSemantics("textfield", value: "B", actionOwner: "x", textGeometry: geometry) }
    catch (_: IllegalArgumentException) { rejected++ }
    try { SemanticNode("x", Rect.zero(), "Button", "button", value: "A", textGeometry: geometry) }
    catch (_: IllegalArgumentException) { rejected++ }
    try { SemanticTextLayout("e\u{301}", [SemanticTextGlyph(0, 1, 0, Rect(0.0, 0.0, 8.0, 18.0), false)]) }
    catch (_: IllegalArgumentException) { rejected++ }
    try { SemanticTextGlyph(0, 1, 0, Rect(0.0, 0.0, -1.0, 18.0), false) }
    catch (_: IllegalArgumentException) { rejected++ }
    try { SemanticTextLayout("\n", [SemanticTextGlyph(0, 1, 0, Rect(0.0, 0.0, 0.0, 18.0), false)]) }
    catch (_: IllegalArgumentException) { rejected++ }
    @Expect(rejected, Int64(5))
    let empty = SemanticTextLayout("", [SemanticTextGlyph(0, 0, 0, Rect(0.0, 0.0, 0.0, 18.0), false)])
    @Expect(empty.count, Int64(1))
    let crlf = SemanticTextLayout("\r\n", [
        SemanticTextGlyph(0, 2, 0, Rect(0.0, 0.0, 0.0, 18.0), false),
        SemanticTextGlyph(2, 2, 1, Rect(0.0, 24.0, 0.0, 18.0), false)])
    @Expect(crlf.glyph(1).line, Int64(1))
}
