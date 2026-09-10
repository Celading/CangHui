package chui.system

import std.collection.ArrayList

private class ClosedShellProvider <: SystemShellProvider & SystemShellRuntimeProvider {
    let fallback = HeadlessSystemShellProvider()
    let queue = ArrayList<String>()
    var entries: Int64 = 0
    var stops: Int64 = 0
    var beforeReturn: () -> Unit = {=> ()}
    public func attach(_: ApplicationManifest): SystemShellResult { entries++; SystemShellResult(SystemShellResultStatus.Applied) }
    public func detach(): Unit { stops++; queue.clear() }
    public func nextAction(): ?String {
        entries++
        let result = if (queue.isEmpty()) { None<String> } else { Some(queue.remove(at: 0)) }
        beforeReturn()
        result
    }
    public func state(v: SystemSurface): SystemSurfaceState { entries++; fallback.state(v) }
    public func registerAction(v: AppAction): SystemShellResult { entries++; fallback.registerAction(v) }
    public func setApplicationMenu(v: AppMenuBar): SystemShellResult { entries++; fallback.setApplicationMenu(v) }
    public func setStatusItem(v: AppStatusItem): SystemShellResult { entries++; fallback.setStatusItem(v) }
    public func notificationPermission(): NotificationPermissionState { entries++; fallback.notificationPermission() }
    public func requestNotificationPermission(): SystemShellResult { entries++; fallback.requestNotificationPermission() }
    public func notify(v: SystemNotification): SystemShellResult { entries++; fallback.notify(v) }
    public func registerDeepLink(v: AppDeepLinkRoute): SystemShellResult { entries++; fallback.registerDeepLink(v) }
    public func readSetting(v: String): ?AppSettingValue { entries++; fallback.readSetting(v) }
    public func writeSetting(k: String, v: AppSettingValue): SystemShellResult { entries++; fallback.writeSetting(k, v) }
}

@Test
func shellDetachRevokesEveryFacadeEntryBeforeAndAfterAttach(): Unit {
    for (attachFirst in [false, true]) {
        let provider = ClosedShellProvider()
        let calls = ApplicationShellTestCounter()
        let menu = AppMenuBar(menus: [AppMenu("app", "Application", actionIds: ["app.open"])])
        let status = AppStatusItem("Test", actionIds: ["app.open"])
        let route = AppDeepLinkRoute("test://open", "app.open")
        let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.close", "1"),
            actions: [AppAction("app.open", "Open")],
            settings: [AppSetting("theme.dark", AppSettingValue.Boolean(false))],
            applicationMenu: Some(menu), statusItem: Some(status), deepLinks: [route]), provider: provider)
        @Expect(shell.registerAction(AppAction("app.open", "Open"), {=> calls.value++}).ok())
        @Expect(shell.invokeAction("app.open").ok()) // pre-attach direct use remains supported
        @Expect(shell.registerDeepLink(route).ok())
        @Expect(shell.writeSetting("theme.dark", AppSettingValue.Boolean(true)).ok())
        if (attachFirst) { @Expect(shell.attach().ok()) }
        shell.detach(); shell.detach()
        @Expect(shell.isClosed())
        let baseline = provider.entries
        let results = [shell.attach(), shell.registerAction(AppAction("app.new", "New"), {=> calls.value++}),
            shell.invokeAction("app.open"), shell.handleDeepLink("test://open"),
            shell.setApplicationMenu(menu), shell.setStatusItem(status),
            shell.notify(SystemNotification("closed", "Closed")), shell.requestNotificationPermission(),
            shell.registerDeepLink(route), shell.projectDeepLinks(),
            shell.writeSetting("theme.dark", AppSettingValue.Boolean(false)), shell.setBadge(Some("1"))]
        for (result in results) {
            @Expect(result.status, SystemShellResultStatus.Failed)
            @Expect(result.message.contains("closed"))
        }
        let surfaces = shell.projectSystemSurfaces()
        @Expect(surfaces.applicationMenu.status, SystemShellResultStatus.Failed)
        @Expect(surfaces.statusItem.status, SystemShellResultStatus.Failed)
        @Expect(shell.readSetting("theme.dark").isNone())
        @Expect(shell.notificationPermission(), NotificationPermissionState.Unsupported)
        @Expect(shell.capability(SystemSurface.ApplicationMenu), SystemSurfaceState.Unsupported)
        @Expect(shell.dispatchPendingActions().isEmpty())
        @Expect(calls.value, Int64(1)); @Expect(provider.entries, baseline)
        @Expect(provider.stops, if (attachFirst) { Int64(1) } else { Int64(0) })
    }
}

@Test
func shellClosedEmptyProjectionDoesNotReportVacuousSuccess(): Unit {
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Empty", "dev.test.empty", "1")))
    shell.detach()
    @Expect(!shell.projectSystemSurfaces().ok())
    @Expect(shell.projectDeepLinks().status, SystemShellResultStatus.Failed)
}

@Test
func shellPollCloseRevokesTheAlreadyRetrievedAction(): Unit {
    let calls = ApplicationShellTestCounter()
    let provider = ClosedShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Poll", "dev.test.poll", "1")), provider: provider)
    @Expect(shell.registerAction(AppAction("app.open", "Open"), {=> calls.value++}).ok())
    @Expect(shell.attach().ok())
    provider.queue.add("app.open")
    provider.beforeReturn = {=> shell.detach()}
    let result = shell.dispatchPendingActions()
    @Expect(result.size, Int64(1))
    @Expect(!result[0].ok()); @Expect(calls.value, Int64(0)); @Expect(shell.isClosed())
}

@Test
func shellCallbackClosePreventsNestedDirectAndDeepLinkActions(): Unit {
    let calls = ApplicationShellTestCounter()
    let provider = ClosedShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Callback", "dev.test.callback", "1"),
        actions: [AppAction("app.after", "After")],
        deepLinks: [AppDeepLinkRoute("test://after", "app.after")]), provider: provider)
    @Expect(shell.registerAction(AppAction("app.after", "After"), {=> calls.value++}).ok())
    @Expect(shell.registerAction(AppAction("app.close", "Close"), {=>
        shell.detach()
        @Expect(!shell.invokeAction("app.after").ok())
        @Expect(!shell.handleDeepLink("test://after").ok())
    }).ok())
    @Expect(shell.attach().ok())
    provider.queue.add("app.close"); provider.queue.add("app.after")
    @Expect(shell.dispatchPendingActions().size, Int64(1))
    @Expect(calls.value, Int64(0)); @Expect(provider.stops, Int64(1))
}
