package chui.desktop

import chui.controls.ReorderableList
import chui.core.{Label, SemanticActionKind, SemanticActionRequest, SemanticActionSource,
    SemanticRuntime, State, StateStore, Theme, UiContext, buildRoot, withActiveSemanticRuntime}
import sdl.{Rect, Renderer}

@Test
func reorderSemanticActionsGrabMoveCancelAndCommitActualDataCallback(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let moves = State<Int64>(0)
    let root = buildRoot({=>
        ReorderableList(2, 40.0, {from, to =>
            @Expect(from, 0)
            @Expect(to, 1)
            moves.value += 1
        }, id: "semantic-reorder") {_ => Label("Track")}
    }, store)
    ctx.adoptFocusRing(store.focusRing())
    let router = DesktopSemanticActionRouter(ctx)
    router.bind(root)
    let runtime = SemanticRuntime("reorder", handler: {request => router.dispatch(request)})
    let refresh = {=>
        root.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))
        runtime.beginFrame()
        withActiveSemanticRuntime(runtime, {=> root.draw(ctx)})
        runtime.commitFrame()
    }
    let action = {kind: SemanticActionKind =>
        let tree = refresh()
        runtime.dispatch(SemanticActionRequest("reorder", tree.revision,
            "ReorderableList:semantic-reorder:item:0:grip", kind, SemanticActionSource.Accessibility))
    }
    @Expect(!action(SemanticActionKind.Increment).ok)
    @Expect(action(SemanticActionKind.Activate).ok)
    @Expect(action(SemanticActionKind.Increment).ok)
    @Expect(moves.value, 0)
    @Expect(!action(SemanticActionKind.Increment).ok)
    @Expect(action(SemanticActionKind.Dismiss).ok)
    @Expect(moves.value, 0)
    @Expect(action(SemanticActionKind.Activate).ok)
    @Expect(action(SemanticActionKind.Increment).ok)
    @Expect(action(SemanticActionKind.Activate).ok)
    @Expect(moves.value, 1)
    @Expect(ctx.dragId, "")
}
