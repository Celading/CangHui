package chui.system

@Test
func dockMenuCapturesImmutableQueuedModelAndClears(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.dock", "1"),
        actions: [AppAction("app.first", "First"), AppAction("app.second", "Second")]), provider: provider)
    let ids = ["app.first"]
    @Expect(shell.setDockMenu(Some(AppMenu("dock", "Dock", actionIds: ids))).status, SystemShellResultStatus.Queued)
    ids[0] = "app.second"
    let copy = provider.capturedDockMenu().getOrThrow()
    @Expect(copy.actionIds[0], "app.first")
    copy.actionIds[0] = "app.second"
    @Expect(provider.capturedDockMenu().getOrThrow().actionIds[0], "app.first")
    @Expect(shell.capability(SystemSurface.DockMenu), SystemSurfaceState.Fallback)
    @Expect(systemSurfaceName(SystemSurface.DockMenu), "dock-menu")
    @Expect(shell.setDockMenu(None).ok())
    @Expect(provider.capturedDockMenu().isNone())
}

@Test
func dockMenuRejectsUnknownDuplicatesNulAndMutatedIdsBeforeProvider(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.dock", "1"),
        actions: [AppAction("app.first", "First")]), provider: provider)
    let original = Some(AppMenu("dock", "Dock", actionIds: ["app.first"]))
    @Expect(shell.setDockMenu(original).ok())
    @Expect(!shell.setDockMenu(Some(AppMenu("dock", "Unknown", actionIds: ["app.unknown"]))).ok())
    var errors: Int64 = 0
    try { let _ = shell.setDockMenu(Some(AppMenu("dock", "Duplicate", actionIds: ["app.first", "app.first"]))) }
    catch (_: IllegalArgumentException) { errors++ }
    try { let _ = shell.setDockMenu(Some(AppMenu("dock", "Bad\u{0}"))) }
    catch (_: IllegalArgumentException) { errors++ }
    let ids = ["app.first"]
    let mutated = AppMenu("dock", "Mutated", actionIds: ids)
    ids[0] = "bad id"
    try { let _ = shell.setDockMenu(Some(mutated)) } catch (_: IllegalArgumentException) { errors++ }
    @Expect(errors, 3)
    @Expect(provider.capturedDockMenu().getOrThrow().title, "Dock")
}

@Test
func dockMenuIsBoundedAndSharesExistingActionRegistry(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.dock", "1")), provider: provider)
    let calls = [Int64(0)]
    @Expect(shell.registerAction(AppAction("app.run", "Run"), {=> calls[0]++}).ok())
    @Expect(shell.setDockMenu(Some(AppMenu("dock", "Dock", actionIds: ["app.run"]))).ok())
    @Expect(shell.invokeAction("app.run").ok())
    @Expect(calls[0], 1)
    var rejected = false
    let many = Array<String>(257, {i => "app.item${i}"})
    try { let _ = shell.setDockMenu(Some(AppMenu("dock", "Too many", actionIds: many))) }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
    shell.detach()
    @Expect(shell.setDockMenu(None).status, SystemShellResultStatus.Failed)
    @Expect(shell.capability(SystemSurface.DockMenu), SystemSurfaceState.Unsupported)
    @Expect(provider.capturedDockMenu().getOrThrow().actionIds[0], "app.run")
    @Expect(!shell.invokeAction("app.run").ok())
    @Expect(calls[0], 1)
}

@Test
func dockMenuKeepsLegacyProviderOptional(): Unit {
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.dock", "1")),
        provider: RuntimeShellFixture())
    @Expect(shell.setDockMenu(None).status, SystemShellResultStatus.Unsupported)
    shell.detach()
    @Expect(shell.setDockMenu(None).status, SystemShellResultStatus.Failed)
}
