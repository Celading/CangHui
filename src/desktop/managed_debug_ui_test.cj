package chui.desktop

@When[debug]
import chui.core.{State, Button, Label, Theme, UiContext, VStack, LengthUnits}
@When[debug]
import chui.text.TextField
@When[debug]
import chui.controls.Modal
@When[debug]
import sdl.{WindowSpec, WindowScaleSettings, Renderer, Rect}

@When[debug]
@Test
func managedDebugScriptSelectsOneWindowAndClosesTheWholeApplication(): Unit {
    let app = DesktopApplication()
    let first = State<String>("primary")
    let second = State<String>("target")
    let runner = DebugUiScriptRunner("focus field\nkey Ctrl+A\ntext 替换\nsnapshot", windowId: "target")
    try {
        let primary = app.openWindow(WindowSpec("primary", 320, 120, vsync: false),
            {=> TextField(first, key: "field")}, semanticWindowId: "primary")
        let _ = app.openWindow(WindowSpec("target", 320, 120, vsync: false),
            {=> TextField(second, key: "field")}, semanticWindowId: "target")
        @Expect(second.value, "target") // openWindow previews must not execute commands.
        for (_ in 0..5) {
            let _ = app.focusWindow(primary)
            let _ = app.step()
            app.stepDebugUi(runner)
        }
        @Expect(first.value, "primary")
        @Expect(second.value, "替换")
        @Expect(app.isClosed())
        @Expect(app.sessionCount(), 0)
    } finally { app.close() }
}

@When[debug]
@Test
func managedDebugScriptRejectsAmbiguityAndMissingTargetsBeforeInput(): Unit {
    for (requested in ["", "missing", "duplicate"]) {
        let app = DesktopApplication()
        let text = State<String>("unchanged")
        try {
            let _ = app.openWindow(WindowSpec("one", 160, 100, vsync: false),
                {=> TextField(text, key: "field")}, semanticWindowId: "duplicate")
            let _ = app.openWindow(WindowSpec("two", 160, 100, vsync: false),
                {=> TextField(text, key: "field")}, semanticWindowId: "duplicate")
            let runner = DebugUiScriptRunner("focus field\ntext changed", windowId: requested)
            var failed = false
            try { app.stepDebugUi(runner) } catch (_: IllegalArgumentException) { failed = true }
            @Expect(failed)
            @Expect(app.isClosed())
            @Expect(text.value, "unchanged")
        } finally { app.close() }
    }
}

@When[debug]
@Test
func managedDebugScriptNeverRetargetsAndDisposesOnCommandFailure(): Unit {
    for (closeTarget in [true, false]) {
        let app = DesktopApplication()
        try {
            let _ = app.openWindow(WindowSpec("primary", 160, 100, vsync: false),
                {=> Label("peer")}, semanticWindowId: "primary")
            let target = app.openWindow(WindowSpec("target", 160, 100, vsync: false),
                {=> Label("target")}, semanticWindowId: "target")
            let runner = DebugUiScriptRunner("snapshot\nkey Unknown", windowId: "target")
            app.stepDebugUi(runner)
            if (closeTarget) { let _ = app.closeWindow(target) }
            var failed = false
            try {
                app.stepDebugUi(runner)
                app.stepDebugUi(runner)
            } catch (_: Exception) { failed = true }
            @Expect(failed)
            @Expect(app.isClosed())
            @Expect(app.sessionCount(), 0)
        } finally { app.close() }
    }
}

@When[debug]
@Test
func managedDebugClicksUseLogicalUiCoordinatesAfterZoom(): Unit {
    let app = DesktopApplication()
    let clicks = State<Int64>(0)
    try {
        let target = app.openWindow(WindowSpec("scaled", 320, 200, vsync: false), {=>
            VStack(spacing: 0.vp, flexible: false) {
                Label("spacer").height(40.vp)
                Button("click", {=> clicks.value += 1}).height(30.vp)
            }
        }, semanticWindowId: "scaled")
        @Expect(app.setWindowScaling(target, WindowScaleSettings(followSystem: false, zoom: 2.0)))
        let runner = DebugUiScriptRunner("click 20 55\nsnapshot", windowId: "scaled")
        for (_ in 0..3) { let _ = app.step(); app.stepDebugUi(runner) }
        @Expect(clicks.value, 1)
        @Expect(app.isClosed())
    } finally { app.close() }
}

@When[debug]
@Test
func debugFocusCannotBypassAnOpenModal(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 300.0
    let background = Button("background", {=> ()}).key("background")
    let modal = Modal(State<Bool>(true)) { Button("dialog", {=> ()}).key("dialog") }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.hasOverlay())
    let before = ctx.focusId
    let runner = DebugUiScriptRunner("focus background")
    runner.observe(background, ctx, 400, 300)
    runner.executeNext(ctx, {_ => @Fail("focus failure must not dispatch an event")})
    var rejected = false
    try { runner.executeNext(ctx, {_ => ()}) }
    catch (error: Exception) { rejected = error.message.contains("overlay ownership") }
    @Expect(rejected)
    @Expect(ctx.focusId, before)
}
