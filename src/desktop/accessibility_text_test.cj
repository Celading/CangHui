package chui.desktop

import chui.core.SemanticNode
import sdl.Rect

@Test
func accessibilityTextPreservesEditorGraphemesRatherThanScalars(): Unit {
    let lengths = accessibilityTextLengths("textfield", "A你é👩‍👩‍👧‍👦").getOrThrow()
    @Expect(lengths.size, Int64(4))
    @Expect(lengths[0], UInt8(1))
    @Expect(lengths[1], UInt8(3))
    @Expect(lengths[2], UInt8(3))
    @Expect(lengths[3], UInt8(25))
    @Expect(accessibilityTextLengths("textfield", "").getOrThrow().isEmpty())
}

private func selectionNode(start: ?Int64, end: ?Int64, focus: ?Int64): SemanticNode {
    SemanticNode("field", Rect.zero(), "TextField", "textfield", value: "a你éb",
        selectionStart: start, selectionEnd: end, selectionFocus: focus)
}

private func expectNativeSelection(node: SemanticNode, lengths: Array<UInt8>, anchor: Int64, focus: Int64): Unit {
    let (actualAnchor, actualFocus) = accessibilityTextSelection(node, lengths).getOrThrow()
    @Expect(actualAnchor, anchor)
    @Expect(actualFocus, focus)
}

@Test
func nativeSelectionMapsDirectionalExactGraphemeBytes(): Unit {
    let lengths = accessibilityTextLengths("textfield", "a你éb").getOrThrow()
    let forward = selectionNode(Some(Int64(1)), Some(Int64(7)), Some(Int64(7)))
    let backward = selectionNode(Some(Int64(1)), Some(Int64(7)), Some(Int64(1)))
    expectNativeSelection(forward, lengths, 1, 3)
    expectNativeSelection(backward, lengths, 3, 1)
    let caret = selectionNode(Some(Int64(8)), Some(Int64(8)), Some(Int64(8)))
    expectNativeSelection(caret, lengths, 4, 4)
    let empty = SemanticNode("empty", Rect.zero(), "TextField", "textfield",
        selectionStart: Some(Int64(0)), selectionEnd: Some(Int64(0)), selectionFocus: Some(Int64(0)))
    expectNativeSelection(empty, [], 0, 0)
}

@Test
func nativeSelectionDoesNotGuessMissingDirectionOrRoundInvalidPositions(): Unit {
    let lengths = accessibilityTextLengths("textfield", "a你éb").getOrThrow()
    for ((start, end, focus) in [(1, 7, 4), (-1, 7, 7), (7, 1, 1), (1, 9, 9),
        (2, 7, 7), (4, 5, 5)]) {
        @Expect(accessibilityTextSelection(selectionNode(Some(start), Some(end), Some(focus)), lengths).isNone())
    }
    @Expect(accessibilityTextSelection(selectionNode(Some(Int64(1)), Some(Int64(7)), None), lengths).isNone())
    @Expect(accessibilityTextSelection(selectionNode(None, Some(Int64(7)), Some(Int64(7))), lengths).isNone())
}

@Test
func accessibilityTextDoesNotInventUnsupportedNativeRuns(): Unit {
    for (role in ["password", "label", "button"]) {
        @Expect(accessibilityTextLengths(role, "secret").isNone())
    }
    for (text in ["line\nline", "line\r\nline", "x\u{0}y"]) {
        @Expect(accessibilityTextLengths("textfield", text).isNone())
    }
    var longCluster = "a"
    for (_ in 0..127) { longCluster += "́" }
    @Expect(accessibilityTextLengths("textfield", longCluster).getOrThrow()[0], UInt8(255))
    @Expect(accessibilityTextLengths("textfield", longCluster + "́").isNone())
}

@Test
func accessibilityMultilinePreservesHardBreaksAndDirectionalByteSelection(): Unit {
    let text = "a你\r\né\n"
    let lengths = accessibilityTextLengths("textarea", text).getOrThrow()
    @Expect(lengths.size, Int64(5))
    @Expect(lengths[2], UInt8(2))
    @Expect(lengths[3], UInt8(3))
    @Expect(lengths[4], UInt8(1))
    let node = SemanticNode("area", Rect.zero(), "TextArea", "textarea", value: text,
        selectionStart: Some(Int64(1)), selectionEnd: Some(Int64(10)), selectionFocus: Some(Int64(1)))
    expectNativeSelection(node, lengths, 5, 1)
    @Expect(accessibilityTextLengths("textarea", "").getOrThrow().isEmpty())
    @Expect(accessibilityTextLengths("textarea", "\n\n").getOrThrow().size, Int64(2))
    @Expect(accessibilityTextLengths("textarea", "a\rb").isNone())
    @Expect(accessibilityTextLengths("textarea", "a\u{0}b").isNone())
}
