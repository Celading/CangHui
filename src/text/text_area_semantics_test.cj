package chui.text

import chui.core.{ComponentProbe, Label, ProbeProperty, State, VStack}

@Test
func textAreaProbeAliasRoutesFocusAndEditingToItsActualOwner(): Unit {
    let text = State<String>("")
    let report = ComponentProbe("test.editor-alias").run(
        "focus studio.editor\ntext 仓绘\nkey Backspace\nassert state studio.editor focused true\nassert event text consumed true") {
        TextArea(text, key: "editor-runtime-key").probe("studio.editor", "TextArea", [
            ProbeProperty("role", "code-editor")
        ])
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(text.value == "仓")
}

@Test
func textAreaProbeAliasCannotFocusDisabledOrConflictingOwners(): Unit {
    let disabled = ComponentProbe("test.disabled-alias").run("focus editor.alias") {
        TextArea(State<String>(""), key: "disabled-owner").enabled(false)
            .probe("editor.alias", "TextArea")
    }
    @Expect(disabled.contains("\"ok\":false"))
    let conflicting = ComponentProbe("test.conflicting-alias").run("focus editor.alias") {
        VStack {
            TextArea(State<String>(""), key: "owner-one").probe("editor.alias", "TextArea")
            TextArea(State<String>(""), key: "editor.alias")
        }
    }
    @Expect(conflicting.contains("ambiguous focus target"))
    @Expect(conflicting.contains("\"ok\":false"))
}

@Test
func probeFocusDoesNotTrustDescriptivePropertiesToRedirectInput(): Unit {
    let report = ComponentProbe("test.forged-alias").run("focus description") {
        VStack {
            Label("Not a control").probe("description", "TextArea", [
                ProbeProperty("focusTarget", "actual-editor"),
                ProbeProperty("actionOwner", "actual-editor")
            ])
            TextArea(State<String>(""), key: "actual-editor")
        }
    }
    @Expect(report.contains("\"ok\":false"))
    @Expect(report.contains("focus target is not in the current focus ring"))
}

@Test
func textAreaObservationPreservesFocusedRegionWithoutDuplicateStateKeys(): Unit {
    let report = ComponentProbe("test.textarea-observation", width: 360.0, height: 120.0)
        .run("@cui-prntx json 32 -\nfocus semantic-area") {
            TextArea(State<String>("a你b"), key: "semantic-area").accessibilityLabel("Source editor")
        }
    @Expect(report.contains("\"ok\":true"))
    @Expect(report.contains("Source editor"))
    @Expect(report.contains("focused=true"))
}

@Test
func textAreaSemanticsExposeNameValueFocusEditabilityAndByteSelection(): Unit {
    let text = State<String>("a你b")
    let cursor = State<Int64>(4)
    let anchor = State<Int64>(1)
    let report = ComponentProbe("test.textarea-accessibility", width: 360.0, height: 120.0)
        .run("focus semantic-area") {
            VStack {
                TextArea(text, key: "semantic-area", cursor: Some(cursor), anchor: Some(anchor))
                    .accessibilityLabel("Source editor")
            }
        }

    @Expect(report.contains("\"role\":\"textarea\""))
    @Expect(report.contains("\"label\":\"Source editor\""))
    @Expect(report.contains("\"value\":\"a你b\""))
    @Expect(report.contains("\"focused\":\"true\""))
    @Expect(report.contains("\"editable\":\"true\""))
    @Expect(report.contains("\"selectionStart\":\"1\""))
    @Expect(report.contains("\"selectionEnd\":\"4\""))
}

@Test
func readOnlyTextAreaSemanticsKeepValueButExposeNoEditingAction(): Unit {
    let report = ComponentProbe("test.textarea-readonly-accessibility", width: 320.0, height: 100.0)
        .run("") {
            TextArea(State<String>("logs"), key: "read-only-area", editable: false)
                .accessibilityLabel("Build output")
        }

    @Expect(report.contains("\"readonly\":\"true\""))
    @Expect(report.contains("\"editable\":\"false\""))
    @Expect(report.contains("\"value\":\"logs\""))
    @Expect(!report.contains("\"action\":\"TextArea.edit()\""))
}

@Test
func explicitEditorProbeKeepsStockStateAndCustomRoleAfterEditing(): Unit {
    let text = State<String>("")
    let report = ComponentProbe("test.editor-merge").run(
        "focus editor.alias\ntext 中\nassert property editor.alias value 中\n" +
        "assert property editor.alias role code-editor\nassert property editor.alias editable true\n" +
        "assert property editor.alias label Source editor") {
        TextArea(text, key: "editor-owner").accessibilityLabel("Source editor")
            .probe("editor.alias", "TextArea", [ProbeProperty("role", "code-editor")])
    }
    @Expect(report.contains("\"ok\":true"))
    @Expect(!report.contains("control-semantic:editor-owner"))
    @Expect(!report.contains("\"ok\":false"))
}

@Test
func explicitPasswordProbeCannotDowngradeStockRedaction(): Unit {
    let report = ComponentProbe("test.password-merge").run("") {
        TextField(State<String>("real-password"), key: "secret-owner").secureEntry()
            .probe("secret.alias", "TextField", [ProbeProperty("role", "textfield"),
                ProbeProperty("value", "annotation-password")])
    }
    @Expect(!report.contains("\"ok\":false"))
    @Expect(report.contains("\"role\":\"password\""))
    @Expect(!report.contains("real-password"))
    @Expect(!report.contains("annotation-password"))
}
