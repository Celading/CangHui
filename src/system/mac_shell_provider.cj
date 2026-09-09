package chui.system

import std.collection.ArrayList

@When[os == "macOS"]
private var macShellOwner: ?MacShellActionSink = None

@When[os == "macOS"]
internal class MacShellActionSink {
    let api: MacShellApi
    let target: ShellRef
    private let slots = Array<Int64>(256, {_ => Int64(0)})
    private let bound = Array<Bool>(4096, {_ => false})
    private var head: Int64 = 0
    private var count: Int64 = 0
    var failed = false
    init(api: MacShellApi, target: ShellRef) { this.api = api; this.target = target }
    func enqueue(receiver: ShellRef, sender: ShellRef): Unit {
        if (!canActivate(receiver, sender)) { return }
        if (count == slots.size) { failed = true; return }
        slots[(head + count) % slots.size] = api.getInteger(sender, "tag")
        count += 1
    }
    func setBound(index: Int64): Unit { bound[index] = true }
    func canActivate(receiver: ShellRef, sender: ShellRef): Bool {
        if (receiver.toUIntNative() != target.toUIntNative() || sender.isNull()) { return false }
        let tag = api.getInteger(sender, "tag")
        if (tag == 1) { return true }
        let index = tag - 100
        index >= 0 && index < bound.size && bound[index]
    }
    func take(): ?Int64 {
        if (failed) { throw IllegalStateException("AppKit action queue overflow or native callback failure") }
        if (count == 0) { return None }
        let result = slots[head]
        head = (head + 1) % slots.size
        count -= 1
        Some(result)
    }
    func clear(): Unit { head = 0; count = 0; failed = false }
}

@When[os == "macOS"]
@C
internal func macShellActionCallback(receiver: ShellRef, _: ShellRef, sender: ShellRef): Unit {
    // Never unwind into Objective-C or execute user handlers from this callback.
    if (let Some(owner) <- macShellOwner) {
        try { owner.enqueue(receiver, sender) } catch (_: Exception) { owner.failed = true }
    }
}

@When[os == "macOS"]
@C
internal func macShellValidateCallback(receiver: ShellRef, _: ShellRef, sender: ShellRef): Bool {
    if (let Some(owner) <- macShellOwner) {
        try { return owner.canActivate(receiver, sender) } catch (_: Exception) { owner.failed = true }
    }
    false
}

/** Native menu/About/badge/Dock provider; notification and persistence are
 * intentionally unsupported until their independent native providers exist. */
@When[os == "macOS"]
public class MacOSSystemShellProvider <: SystemShellProvider & SystemShellRuntimeProvider & SystemShellBadgeProvider & SystemShellDockMenuProvider {
    private let actions = ArrayList<AppAction>()
    private let boundActionIds = ArrayList<String>()
    private let fallback = HeadlessSystemShellProvider()
    private var requestedMenu: ?AppMenuBar = None
    private var api: ?MacShellApi = None
    private var sink: ?MacShellActionSink = None
    private var identity: ?AppIdentity = None
    private var app = ShellRef()
    private var target = ShellRef()
    private var ownedMenu = ShellRef()
    private var oldMenu = ShellRef()
    private var oldWindowsMenu = ShellRef()
    private var oldServicesMenu = ShellRef()
    private var oldProcessName = ShellRef()
    private var processInfo = ShellRef()
    private var savedSurfaces = false
    private var closed = false
    private let actionItems = ArrayList<ShellRef>()
    private let badge = MacShellBadge()
    private var requestedBadge: ?String = None
    private var hasRequestedBadge = false
    private var requestedDockMenu: ?AppMenu = None
    private let dock = MacShellDock()
    private let dockItems = ArrayList<ShellRef>()

    public init() {}

    public func state(surface: SystemSurface): SystemSurfaceState {
        match (surface) {
            case SystemSurface.ApplicationMenu => SystemSurfaceState.Native
            case SystemSurface.Badge => SystemSurfaceState.Native
            case SystemSurface.DockMenu => SystemSurfaceState.Native
            case SystemSurface.Settings => SystemSurfaceState.Fallback
            case _ => SystemSurfaceState.Unsupported
        }
    }

    public func registerAction(action: AppAction): SystemShellResult {
        if (closed) { return failed("application shell is closed") }
        if (let Some(native) <- api) { native.requireMainThread() }
        let _ = macMenuShortcut(action.shortcut)
        if (action.title.contains("\u{0}")) { throw IllegalArgumentException("native action title contains NUL") }
        for (id in boundActionIds) {
            if (id == action.id) { return failed("duplicate application action: " + action.id) }
        }
        var index = actionIndex(action.id)
        if (index >= 0) {
            let previous = actions[index]
            actions[index] = action
            try {
                if (let Some(native) <- api) {
                    rebuildMenu(native, currentMenu())
                    for (item in dockItems) {
                        if (native.getInteger(item, "tag") == index + 100) { native.setText(item, "setTitle:", action.title) }
                    }
                }
            } catch (error: Exception) { actions[index] = previous; throw error }
        } else {
            if (actions.size >= 4096) { return failed("native action limit is 4096") }
            index = actions.size
            actions.add(action)
        }
        boundActionIds.add(action.id)
        if (let Some(queue) <- sink) { queue.setBound(index) }
        applied("application action registered")
    }

    public func attach(manifest: ApplicationManifest): SystemShellResult {
        if (closed) { return failed("application shell is closed") }
        if (api.isSome()) { return applied("AppKit shell already attached") }
        if (macShellOwner.isSome()) { return failed("another application shell owns the native menu") }
        let native = MacShellApi()
        api = Some(native)
        try {
            identity = Some(manifest.identity)
            for (action in manifest.actions) {
                var found = false
                for (registered in actions) { if (registered.id == action.id) { found = true } }
                if (!found) {
                    if (actions.size >= 4096) { throw IllegalArgumentException("native action limit is 4096") }
                    actions.add(action)
                }
            }
            app = native.require(native.get(native.cls("NSApplication"), "sharedApplication"), "application")
            target = native.require(native.get(native.get(native.targetClass(), "alloc"), "init"), "action target")
            // Resolve both callback symbols before publication, outside the callback.
            let _ = native.symbol("objc_msgSend"); let _ = native.sel("tag")
            let queue = MacShellActionSink(native, target)
            for (id in boundActionIds) { queue.setBound(actionIndex(id)) }
            sink = Some(queue)
            macShellOwner = sink
            oldMenu = native.retain(native.get(app, "mainMenu"))
            oldWindowsMenu = native.retain(native.get(app, "windowsMenu"))
            oldServicesMenu = native.retain(native.get(app, "servicesMenu"))
            processInfo = native.get(native.cls("NSProcessInfo"), "processInfo")
            oldProcessName = native.retain(native.get(processInfo, "processName"))
            savedSurfaces = true
            native.setText(processInfo, "setProcessName:", manifest.identity.name)
            let menu = match (requestedMenu) {
                case Some(value) => value
                case None => match (manifest.applicationMenu) { case Some(value) => value; case None => AppMenuBar() }
            }
            rebuildMenu(native, menu)
            requestedMenu = Some(menu)
            if (hasRequestedBadge) { badge.apply(native, app, requestedBadge) }
            if (requestedDockMenu.isSome()) { rebuildDockMenu(native, requestedDockMenu) }
            applied("AppKit application menu attached")
        } catch (error: Exception) {
            detach()
            throw error
        }
    }

    public func setApplicationMenu(menu: AppMenuBar): SystemShellResult {
        if (closed) { return failed("application shell is closed") }
        // Validate before touching the live native menu; unknown IDs never become clickable.
        for (entry in menu.menus) {
            for (id in entry.actionIds) { if (actionIndex(id) < 0) { return failed("unknown application action: " + id) } }
        }
        if (let Some(native) <- api) {
            native.requireMainThread()
            rebuildMenu(native, menu)
            requestedMenu = Some(menu)
            return applied("AppKit application menu updated")
        }
        requestedMenu = Some(menu)
        SystemShellResult(SystemShellResultStatus.Queued, message: "menu awaits application attachment")
    }

    private func actionIndex(id: String): Int64 {
        for (i in 0..actions.size) { if (actions[i].id == id) { return i } }
        -1
    }
    private func currentMenu(): AppMenuBar {
        match (requestedMenu) { case Some(menu) => menu; case None => AppMenuBar() }
    }

    private func add(native: MacShellApi, menu: ShellRef, title: String, selector: String,
        receiver: ShellRef, key: String, mask: Int64): Unit {
        let item = native.item(title, native.sel(selector), receiver, key, mask)
        try { native.set(menu, "addItem:", item) } finally { native.release(item) }
    }

    private func addAction(native: MacShellApi, menu: ShellRef, title: String, tag: Int64,
        items: ArrayList<ShellRef>): Unit {
        let shortcut = if (tag >= 100) { macMenuShortcut(actions[tag - 100].shortcut) } else { ("", Int64(0)) }
        let item = native.item(title, native.sel("chuiPerformAction:"), target, shortcut[0], shortcut[1])
        try {
            native.integer(item, "setTag:", tag)
            native.set(menu, "addItem:", item)
            items.add(native.retain(item))
        } finally { native.release(item) }
    }

    private func group(native: MacShellApi, root: ShellRef, title: String): ShellRef {
        let menu = native.menu(title)
        var item = ShellRef()
        try {
            item = native.item(title, ShellRef(), ShellRef(), "", 0)
            native.set(item, "setSubmenu:", menu)
            native.set(root, "addItem:", item)
        }
        catch (error: Exception) { native.release(menu); throw error }
        finally { native.release(item) }
        menu
    }

    private func disconnectItems(native: MacShellApi, items: ArrayList<ShellRef>): Unit {
        for (item in items) {
            native.set(item, "setTarget:", ShellRef())
            native.set(item, "setAction:", ShellRef())
            native.release(item)
        }
        items.clear()
    }

    private func rebuildMenu(native: MacShellApi, model: AppMenuBar): Unit {
        let currentIdentity = identity.getOrThrow()
        // Validate the entire model before clearing the current projection.
        for (entry in model.menus) {
            for (id in entry.actionIds) {
                if (actionIndex(id) < 0) { throw IllegalArgumentException("unknown native menu action: " + id) }
            }
        }
        for (action in actions) { let _ = macMenuShortcut(action.shortcut) }
        let root = native.menu(currentIdentity.name)
        let pendingItems = ArrayList<ShellRef>()
        var services = ShellRef()
        var windowMenu = ShellRef()
        try {
            let primary = group(native, root, currentIdentity.name)
            try {
                addAction(native, primary, "About " + currentIdentity.name, 1, pendingItems)
                let settings = actionIndex("app.settings")
                if (settings >= 0) { addAction(native, primary, actions[settings].title, settings + 100, pendingItems) }
                services = group(native, primary, "Services")
                native.release(services)
                add(native, primary, "Hide " + currentIdentity.name, "hide:", app, "h", 1048576)
                add(native, primary, "Hide Others", "hideOtherApplications:", app, "h", 1572864)
                add(native, primary, "Show All", "unhideAllApplications:", app, "", 0)
                add(native, primary, "Quit " + currentIdentity.name, "terminate:", app, "q", 1048576)
            } finally { native.release(primary) }
            for (entry in model.menus) {
                let menu = group(native, root, entry.title)
                try {
                    for (id in entry.actionIds) {
                        let index = actionIndex(id)
                        addAction(native, menu, actions[index].title, index + 100, pendingItems)
                    }
                } finally { native.release(menu) }
            }
            let windows = group(native, root, "Window")
            windowMenu = windows
            try {
                add(native, windows, "Minimize", "performMiniaturize:", ShellRef(), "m", 1048576)
                add(native, windows, "Zoom", "performZoom:", ShellRef(), "", 0)
                add(native, windows, "Close", "performClose:", ShellRef(), "w", 1048576)
                add(native, windows, "Bring All to Front", "arrangeInFront:", app, "", 0)
            } finally { native.release(windows) }
            native.set(app, "setServicesMenu:", services)
            native.set(app, "setWindowsMenu:", windowMenu)
            native.set(app, "setMainMenu:", root)
            disconnectItems(native, actionItems)
            for (item in pendingItems) { actionItems.add(item) }
            pendingItems.clear()
            if (let Some(queue) <- sink) { queue.clear() }
            native.release(ownedMenu)
            ownedMenu = root
        } catch (error: Exception) {
            disconnectItems(native, pendingItems)
            native.release(root)
            throw error
        }
    }

    public func nextAction(): ?String {
        if (closed) { return None }
        if (let Some(native) <- api) {
            native.requireMainThread()
            if (let Some(queue) <- sink) {
                while (let Some(tag) <- queue.take()) {
                    if (tag == 1) {
                        let info = identity.getOrThrow()
                        let options = native.object("NSMutableDictionary")
                        try {
                            native.dictionaryText(options, "NSAboutPanelOptionApplicationName", info.name)
                            native.dictionaryText(options, "NSAboutPanelOptionApplicationVersion", info.version)
                            native.set(app, "orderFrontStandardAboutPanelWithOptions:", options)
                        } finally { native.release(options) }
                    } else {
                        let index = tag - 100
                        if (index >= 0 && index < actions.size) { return Some(actions[index].id) }
                        throw IllegalStateException("invalid AppKit action tag")
                    }
                }
            }
        }
        None
    }

    public func setBadge(label: ?String): SystemShellResult {
        if (closed) { return failed("application shell is closed") }
        validateApplicationBadge(label)
        if (let Some(native) <- api) {
            native.requireMainThread()
            badge.apply(native, app, label)
            return applied("AppKit Dock badge updated")
        }
        requestedBadge = label
        hasRequestedBadge = true
        SystemShellResult(SystemShellResultStatus.Queued, message: "badge awaits application attachment")
    }

    public func setDockMenu(menu: ?AppMenu): SystemShellResult {
        if (closed) { return failed("application shell is closed") }
        let snapshot = copyApplicationDockMenu(menu)
        if (let Some(native) <- api) {
            native.requireMainThread()
            // Includes actions declared in the manifest but not yet bound.
            if (let Some(value) <- snapshot) {
                for (id in value.actionIds) { if (actionIndex(id) < 0) { return failed("unknown application action: " + id) } }
            }
            rebuildDockMenu(native, snapshot)
            requestedDockMenu = snapshot
            return applied("AppKit Dock menu updated")
        }
        requestedDockMenu = snapshot
        SystemShellResult(SystemShellResultStatus.Queued, message: "Dock menu awaits application attachment")
    }

    private func rebuildDockMenu(native: MacShellApi, model: ?AppMenu): Unit {
        if (let Some(value) <- model) {
            for (id in value.actionIds) {
                if (actionIndex(id) < 0) { throw IllegalArgumentException("unknown Dock action: " + id) }
            }
            let menu = native.menu(value.title)
            let pendingItems = ArrayList<ShellRef>()
            try {
                for (id in value.actionIds) {
                    let index = actionIndex(id)
                    // Dock entries share action tags but not menu-bar key equivalents.
                    let item = native.item(actions[index].title, native.sel("chuiPerformAction:"), target, "", 0)
                    try {
                        native.integer(item, "setTag:", index + 100)
                        native.set(menu, "addItem:", item)
                        pendingItems.add(native.retain(item))
                    } finally { native.release(item) }
                }
                dock.apply(native, app, menu)
                disconnectItems(native, dockItems)
                for (item in pendingItems) { dockItems.add(item) }
                pendingItems.clear()
            } finally { disconnectItems(native, pendingItems); native.release(menu) }
        } else {
            dock.detach(native)
            disconnectItems(native, dockItems)
        }
        // A changed system projection invalidates events captured by the old one.
        if (let Some(queue) <- sink) { queue.clear() }
    }

    public func detach(): Unit {
        if (closed) { return }
        if (let Some(native) <- api) {
            native.requireMainThread()
            closed = true
            macShellOwner = None
            sink = None
            disconnectItems(native, actionItems)
            disconnectItems(native, dockItems)
            dock.detach(native)
            badge.restore(native)
            // Dock restores its delegate only while still owned; other surfaces
            // restore independently. Hosts without a custom Dock keep SDL's delegate.
            if (savedSurfaces && (ownedMenu.isNull() || native.get(app, "mainMenu").toUIntNative() == ownedMenu.toUIntNative())) {
                native.set(app, "setMainMenu:", oldMenu)
                native.set(app, "setWindowsMenu:", oldWindowsMenu)
                native.set(app, "setServicesMenu:", oldServicesMenu)
                if (oldProcessName.isNotNull()) { native.set(processInfo, "setProcessName:", oldProcessName) }
            }
            native.release(ownedMenu); native.release(oldMenu)
            native.release(oldWindowsMenu); native.release(oldServicesMenu)
            native.release(oldProcessName); native.release(target)
            native.close()
            api = None
        } else { closed = true }
    }

    private func applied(message: String): SystemShellResult { SystemShellResult(SystemShellResultStatus.Applied, message: message) }
    private func failed(message: String): SystemShellResult { SystemShellResult(SystemShellResultStatus.Failed, message: message) }
    private func unsupported(): SystemShellResult { SystemShellResult(SystemShellResultStatus.Unsupported, message: "native surface is not implemented by this provider") }
    public func setStatusItem(_: AppStatusItem): SystemShellResult { unsupported() }
    public func notificationPermission(): NotificationPermissionState { NotificationPermissionState.Unsupported }
    public func requestNotificationPermission(): SystemShellResult { unsupported() }
    public func notify(_: SystemNotification): SystemShellResult { unsupported() }
    public func registerDeepLink(_: AppDeepLinkRoute): SystemShellResult { unsupported() }
    public func readSetting(key: String): ?AppSettingValue { fallback.readSetting(key) }
    public func writeSetting(key: String, value: AppSettingValue): SystemShellResult { fallback.writeSetting(key, value) }
}

/** Explicit native selection; deterministic/headless ApplicationShell() stays unchanged. */
@When[os == "macOS"]
public func desktopApplicationShell(manifest: ApplicationManifest): ApplicationShell {
    ApplicationShell(manifest, provider: MacOSSystemShellProvider())
}

@When[os != "macOS"]
public func desktopApplicationShell(manifest: ApplicationManifest): ApplicationShell {
    ApplicationShell(manifest)
}
