package chui.desktop

import std.env.getVariable
import std.fs.{exists, removeIfExists}
import sdl.WindowSpec
import sdl.system.PerformanceClock
import chui.core.Label

private func managedCaptureTestPath(): String {
    let base = getVariable("TEMP") ?? (getVariable("TMPDIR") ?? "/tmp")
    let path = base + "/chui-managed-capture-${PerformanceClock.counter()}.bmp"
    if (exists(path)) { throw IllegalStateException("capture test path already exists") }
    path
}

@Test
func managedCaptureWaitsForApplicationStepsThenClosesAllWindows(): Unit {
    let path = managedCaptureTestPath()
    let app = DesktopApplication(capture: Some(DesktopCaptureRequest(path,
        settleFrames: UInt64(2), windowId: "settings")))
    try {
        let first = app.openWindow(WindowSpec("capture primary", 160, 100, vsync: false),
            {=> Label("primary")}, semanticWindowId: "primary")
        let _ = app.openWindow(WindowSpec("capture settings", 220, 140, vsync: false),
            {=> Label("settings")}, semanticWindowId: "settings")
        @Expect(!exists(path))
        @Expect(app.sessionCount(), 2)
        let _ = app.step()
        @Expect(!exists(path))
        @Expect(!app.isClosed())
        let _ = app.focusWindow(first)
        let _ = app.step()
        @Expect(exists(path))
        @Expect(app.isClosed())
        @Expect(app.sessionCount(), 0)
    } finally { app.close(); removeIfExists(path) }
}

@Test
func managedCaptureRejectsMissingAndAmbiguousSemanticTargets(): Unit {
    for (duplicate in [false, true]) {
        let path = managedCaptureTestPath()
        let app = DesktopApplication(capture: Some(DesktopCaptureRequest(path,
            settleFrames: UInt64(1), windowId: "settings")))
        try {
            let id = if (duplicate) { "settings" } else { "primary" }
            let _ = app.openWindow(WindowSpec("capture one", 160, 100, vsync: false),
                {=> Label("one")}, semanticWindowId: id)
            let _ = app.openWindow(WindowSpec("capture two", 160, 100, vsync: false),
                {=> Label("two")}, semanticWindowId: id)
            var failed = false
            try { let _ = app.step() }
            catch (error: IllegalArgumentException) {
                failed = error.message.contains(if (duplicate) { "ambiguous" } else { "not found" })
            }
            @Expect(failed)
            @Expect(app.isClosed())
            @Expect(!exists(path))
        } finally { app.close(); removeIfExists(path) }
    }
}

@Test
func managedCaptureNeverRetargetsAfterSelectedWindowCloses(): Unit {
    let path = managedCaptureTestPath()
    let app = DesktopApplication(capture: Some(DesktopCaptureRequest(path,
        settleFrames: UInt64(3), windowId: "settings")))
    try {
        let _ = app.openWindow(WindowSpec("capture primary", 160, 100, vsync: false),
            {=> Label("primary")}, semanticWindowId: "primary")
        let second = app.openWindow(WindowSpec("capture settings", 220, 140, vsync: false),
            {=> Label("settings")}, semanticWindowId: "settings")
        let _ = app.step()
        @Expect(app.closeWindow(second))
        var failed = false
        try { let _ = app.step() }
        catch (error: IllegalStateException) { failed = error.message.contains("capture target closed") }
        @Expect(failed)
        @Expect(!exists(path))
        @Expect(app.isClosed())
    } finally { app.close(); removeIfExists(path) }
}

@Test
func managedCaptureFailureReleasesAllNativeWindows(): Unit {
    let path = managedCaptureTestPath() + "/missing-parent.bmp"
    let app = DesktopApplication(capture: Some(DesktopCaptureRequest(path, settleFrames: UInt64(1))))
    try {
        let _ = app.openWindow(WindowSpec("capture failure", 160, 100, vsync: false), {=> Label("one")})
        let _ = app.openWindow(WindowSpec("capture sibling", 160, 100, vsync: false), {=> Label("two")})
        var failed = false
        try { let _ = app.step() } catch (_: Exception) { failed = true }
        @Expect(failed)
        @Expect(app.isClosed())
        @Expect(!exists(path))
    } finally { app.close() }
}

@Test
func singleDesktopCaptureRejectsWrongSemanticWindowBeforeNativeCreation(): Unit {
    var failed = false
    try {
        let app = DesktopApp(WindowSpec("must not open", 160, 100),
            capture: Some(DesktopCaptureRequest("unused.bmp", windowId: "settings")))
        app.requestWindowClose()
        app.run { Label("unreachable") }
    } catch (error: IllegalArgumentException) { failed = error.message.contains("does not match") }
    @Expect(failed)
}
