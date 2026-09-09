package chui.text

import chui.core.{ComponentProbe, ProbeProperty, State}

@Test
func fieldSelectionSemanticsPreserveDirectionalByteEndpoints(): Unit {
    for (backward in [false, true]) {
        let caret: Int64 = if (backward) { 1 } else { 4 }
        let anchor: Int64 = if (backward) { 4 } else { 1 }
        let report = ComponentProbe("field-selection").run("focus field") {
            TextField(State<String>("a你b"), key: "field", editable: false,
                cursor: Some(State<Int64>(caret)), anchor: Some(State<Int64>(anchor)))
        }
        @Expect(report.contains("\"selectionStart\":\"1\""))
        @Expect(report.contains("\"selectionEnd\":\"4\""))
        @Expect(report.contains("\"selectionFocus\":\"${caret}\""))
    }
}

@Test
func passwordSelectionCannotLeakThroughDescriptiveProbeProperties(): Unit {
    let report = ComponentProbe("password-selection").run("focus password") {
        TextField(State<String>("secret"), key: "password").secureEntry()
            .probe("description", "TextField", [ProbeProperty("selectionStart", "1"),
                ProbeProperty("selectionEnd", "99"), ProbeProperty("selectionFocus", "1")])
    }
    @Expect(!report.contains("selectionStart"))
    @Expect(!report.contains("selectionEnd"))
    @Expect(!report.contains("selectionFocus"))
    @Expect(!report.contains("secret"))
}

@Test
func areaSelectionSemanticsPreserveCaretRatherThanAssumeRangeEnd(): Unit {
    let report = ComponentProbe("area-selection").run("focus area") {
        TextArea(State<String>("a你\nb"), key: "area",
            cursor: Some(State<Int64>(1)), anchor: Some(State<Int64>(5)))
    }
    @Expect(report.contains("\"selectionStart\":\"1\""))
    @Expect(report.contains("\"selectionEnd\":\"5\""))
    @Expect(report.contains("\"selectionFocus\":\"1\""))
}
