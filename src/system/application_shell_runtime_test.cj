package chui.system

import std.collection.ArrayList

class RuntimeShellFixture <: SystemShellProvider & SystemShellRuntimeProvider {
    let fallback = HeadlessSystemShellProvider()
    let queue = ArrayList<String>()
    var starts: Int64 = 0
    var stops: Int64 = 0
    var refuse = false
    var calls: Int64 = 0
    var handlerFails = true
    public func attach(_: ApplicationManifest): SystemShellResult {
        starts += 1
        SystemShellResult(if (refuse) { SystemShellResultStatus.Failed } else { SystemShellResultStatus.Applied })
    }
    public func nextAction(): ?String { if (queue.isEmpty()) { None } else { Some(queue.remove(at: 0)) } }
    public func detach(): Unit { stops += 1; queue.clear() }
    public func state(surface: SystemSurface): SystemSurfaceState { fallback.state(surface) }
    public func registerAction(action: AppAction): SystemShellResult { fallback.registerAction(action) }
    public func setApplicationMenu(menu: AppMenuBar): SystemShellResult { fallback.setApplicationMenu(menu) }
    public func setStatusItem(item: AppStatusItem): SystemShellResult { fallback.setStatusItem(item) }
    public func notificationPermission(): NotificationPermissionState { fallback.notificationPermission() }
    public func requestNotificationPermission(): SystemShellResult { fallback.requestNotificationPermission() }
    public func notify(value: SystemNotification): SystemShellResult { fallback.notify(value) }
    public func registerDeepLink(value: AppDeepLinkRoute): SystemShellResult { fallback.registerDeepLink(value) }
    public func readSetting(key: String): ?AppSettingValue { fallback.readSetting(key) }
    public func writeSetting(key: String, value: AppSettingValue): SystemShellResult { fallback.writeSetting(key, value) }
}

@Test
func applicationShellRuntimeAttachesOnceAndDrainsOnlyTheRequestedBound(): Unit {
    let provider = RuntimeShellFixture()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.shell", "1")), provider: provider)
    let _ = shell.registerAction(AppAction("file.open", "Open"), { => provider.calls += 1 })
    provider.queue.add("file.open"); provider.queue.add("file.open")
    @Expect(shell.dispatchPendingActions().size, 0)
    @Expect(shell.attach().ok()); @Expect(shell.attach().ok()); @Expect(provider.starts, 1)
    @Expect(shell.dispatchPendingActions(limit: 1).size, 1)
    @Expect(provider.calls, 1); @Expect(provider.queue.size, 1)
    @Expect(shell.dispatchPendingActions().size, 1); @Expect(provider.calls, 2)
    shell.detach(); shell.detach()
    @Expect(provider.stops, 1); @Expect(!shell.attach().ok())
}

@Test
func applicationShellRuntimeDefersNestedDrainAndStopsWhenHandlerCloses(): Unit {
    let provider = RuntimeShellFixture()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.shell", "1")), provider: provider)
    let _ = shell.registerAction(AppAction("app.close", "Close"), { =>
        @Expect(shell.dispatchPendingActions().size, 0)
        provider.calls += 1
        shell.detach()
    })
    let _ = shell.attach()
    provider.queue.add("app.close"); provider.queue.add("app.close")
    @Expect(shell.dispatchPendingActions().size, 1)
    @Expect(provider.calls, 1); @Expect(provider.stops, 1); @Expect(provider.queue.isEmpty())
}

@Test
func applicationShellRuntimeRefusalIsRetryableAndUnknownActionIsNotSuccess(): Unit {
    let provider = RuntimeShellFixture()
    provider.refuse = true
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.shell", "1")), provider: provider)
    @Expect(!shell.attach().ok())
    provider.refuse = false
    @Expect(shell.attach().ok()); @Expect(provider.starts, 2)
    provider.queue.add("missing.action")
    let receipts = shell.dispatchPendingActions()
    @Expect(receipts.size, 1); @Expect(!receipts[0].ok())
    shell.detach()
}

@Test
func applicationShellRuntimeRestoresDispatchGuardAfterHandlerException(): Unit {
    let provider = RuntimeShellFixture()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.shell", "1")), provider: provider)
    let _ = shell.registerAction(AppAction("file.open", "Open"), { =>
        if (provider.handlerFails) { throw IllegalStateException("handler failure") }
        provider.calls += 1
    })
    let _ = shell.attach()
    provider.queue.add("file.open"); provider.queue.add("file.open")
    var threw = false
    try { let _ = shell.dispatchPendingActions() } catch (_: IllegalStateException) { threw = true }
    @Expect(threw)
    provider.handlerFails = false
    @Expect(shell.dispatchPendingActions().size, 1); @Expect(provider.calls, 1)
    shell.detach()
}

@Test
func applicationShellRuntimePreservesHeadlessProviderAndRejectsInvalidLimit(): Unit {
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.shell", "1")))
    @Expect(shell.attach().ok())
    @Expect(shell.capability(SystemSurface.ApplicationMenu), SystemSurfaceState.Fallback)
    @Expect(shell.dispatchPendingActions().isEmpty())
    for (limit in [Int64(0), Int64(257)]) {
        var threw = false
        try { let _ = shell.dispatchPendingActions(limit: limit) } catch (_: IllegalArgumentException) { threw = true }
        @Expect(threw)
    }
    shell.detach()
}
