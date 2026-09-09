package chui.text

@When[debug]
import chui.core.{ComponentProbe, State, VStack}

@When[debug]
@Test
func probeKeyboardWorkflowCanSelectReplaceUndoAndTraverseBackwards(): Unit {
    let text = State<String>("a你b")
    let report = ComponentProbe("test.keyboard-workflow", width: 360.0, height: 160.0).run(
        "focus first\nkey ctrl+a\ntext 替换\nassert property first value 替换\nkey ctrl+z\nkey Tab\n" +
        "assert state second focus true\nkey Shift+Tab\nassert state first focus true") {
        VStack {
            TextField(text, key: "first").probe("first")
            TextField(State<String>("second"), key: "second").probe("second")
        }
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(text.value, "a你b")
}
