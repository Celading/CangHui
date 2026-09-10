package chui.text

import std.collection.ArrayList
import chui.core.{ComponentProbe, State, StateStore, Theme, UiContext, VStack, buildRoot}
import sdl.{Key, Rect, Renderer, UiEvent}

@When[debug]
@Test
func readonlyAreaSupportsProbeFocusAndSelectionWithoutEditing(): Unit {
    let text = State<String>("a你\né")
    let cursor = State<Int64>(0)
    let anchor = State<Int64>(0)
    let report = ComponentProbe("test.readonly-area", width: 320.0, height: 160.0)
        .run("focus output\nkey Ctrl+A\ntext forbidden\nkey Backspace\nkey Enter\nkey Delete") {
            TextArea(text, key: "output", editable: false, cursor: Some(cursor), anchor: Some(anchor))
        }
    @Expect(report.contains("\"ok\":true"))
    @Expect(text.value, "a你\né")
    @Expect(cursor.value, text.value.size)
    @Expect(anchor.value, Int64(0))
}

@Test
func readonlyAreaSelectionAndMutationGuardsApplyInBothBuildModes(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("a你\né")
    let cursor = State<Int64>(0)
    let anchor = State<Int64>(0)
    let area = TextArea(text, key: "output", editable: false, cursor: Some(cursor), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 320.0, 160.0)); ctx.focus("output")
    @Expect(ctx.withEventModifiers(Some(UInt16(0x00c0)), {=>
        area.handle(ctx, UiEvent.KeyDown(Key.Letter(UInt8(65)), false)) }))
    @Expect(cursor.value, text.value.size)
    @Expect(anchor.value, Int64(0))
    @Expect(!area.handle(ctx, UiEvent.TextInput("forbidden")))
    for (key in [Key.Enter, Key.Backspace, Key.Delete]) {
        @Expect(!area.handle(ctx, UiEvent.KeyDown(key, false)))
    }
    @Expect(text.value, "a你\né")
}

@Test
func readonlyAreaFocusStillRejectsDisabledAndHiddenControls(): Unit {
    for (disabled in [true, false]) {
        let report = ComponentProbe("test.readonly-excluded").run("focus excluded") {
            let area = TextArea(State<String>("output"), key: "excluded", editable: false)
            if (disabled) { area.enabled(false) } else { area.visible(false) }
        }
        @Expect(report.contains("\"ok\":false"))
    }
}

@Test
func readonlyTextFieldHistoryCannotMutateOrConsumeRetainedUndoRedo(): Unit {
    let store = StateStore()
    let fields = ArrayList<TextField>()
    let text = State<String>("old")
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let _ = buildRoot({=> fields.add(TextField(text, key: "field"))}, store)
    fields[0].layout(ctx, Rect(0.0, 0.0, 300.0, 40.0)); ctx.focus("field")
    let _ = fields[0].handle(ctx, UiEvent.TextInput("!"))
    @Expect(text.value, "old!")
    let _ = buildRoot({=> fields.add(TextField(text, key: "field", editable: false))}, store)
    fields[1].undo()
    @Expect(text.value, "old!")
    let _ = ctx.withEventModifiers(Some(UInt16(0x00c0)), {=>
        fields[1].handle(ctx, UiEvent.KeyDown(Key.Letter(UInt8(90)), false)) })
    @Expect(text.value, "old!")
    let _ = buildRoot({=> fields.add(TextField(text, key: "field"))}, store)
    fields[2].undo()
    @Expect(text.value, "old")
    let _ = buildRoot({=> fields.add(TextField(text, key: "field", editable: false))}, store)
    fields[3].redo()
    @Expect(text.value, "old")
    let _ = buildRoot({=> fields.add(TextField(text, key: "field"))}, store)
    fields[4].redo()
    @Expect(text.value, "old!")
}

@Test
func readonlyTextAreaHistoryCannotMutateOrConsumeRetainedUndoRedo(): Unit {
    let store = StateStore()
    let areas = ArrayList<TextArea>()
    let text = State<String>("old")
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let _ = buildRoot({=> areas.add(TextArea(text, key: "area"))}, store)
    areas[0].layout(ctx, Rect(0.0, 0.0, 300.0, 120.0)); ctx.focus("area")
    let _ = areas[0].handle(ctx, UiEvent.TextInput("!"))
    @Expect(text.value, "old!")
    let _ = buildRoot({=> areas.add(TextArea(text, key: "area", editable: false))}, store)
    areas[1].undo()
    @Expect(text.value, "old!")
    let _ = buildRoot({=> areas.add(TextArea(text, key: "area"))}, store)
    areas[2].undo()
    @Expect(text.value, "old")
    let _ = buildRoot({=> areas.add(TextArea(text, key: "area", editable: false))}, store)
    areas[3].redo()
    @Expect(text.value, "old")
    let _ = buildRoot({=> areas.add(TextArea(text, key: "area"))}, store)
    areas[4].redo()
    @Expect(text.value, "old!")
}
