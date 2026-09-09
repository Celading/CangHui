package chui.desktop

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

@Test
func accessibilityTextDoesNotInventUnsupportedNativeRuns(): Unit {
    for (role in ["password", "textarea", "label", "button"]) {
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
