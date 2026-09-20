package chui.system

/** Explicit local assets: bundle-relative inside .app, working-directory-relative during development. */
@When[os == "macOS"]
internal func macShellImage(native: MacShellApi, asset: AppAsset): ShellRef {
    var path = asset.path
    if (!path.startsWith("/")) {
        let bundle = native.get(native.cls("NSBundle"), "mainBundle")
        if (native.string(native.get(bundle, "bundlePath")).endsWith(".app")) {
            path = native.string(native.get(bundle, "resourcePath")) + "/" + path
        }
    }
    let name = native.text(path)
    try {
        native.require(unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> ShellRef>(native.symbol("objc_msgSend"))(
            native.get(native.cls("NSImage"), "alloc"), native.sel("initWithContentsOfFile:"), name) }, "local icon image")
    } finally { native.release(name) }
}

@When[os == "macOS"]
internal class MacShellImages {
    private var previous = ShellRef()
    private var owned = ShellRef()

    func attach(native: MacShellApi, app: ShellRef, manifest: ApplicationManifest): Unit {
        for (asset in manifest.assets) {
            if (asset.role == AppAssetRole.ApplicationIcon) {
                let image = macShellImage(native, asset)
                previous = native.retain(native.get(app, "applicationIconImage"))
                owned = image
                native.set(app, "setApplicationIconImage:", image)
                return
            }
        }
    }

    func addAboutIcon(native: MacShellApi, app: ShellRef, options: ShellRef): Unit {
        let icon = native.get(app, "applicationIconImage")
        if (icon.isNotNull()) { native.dictionaryObject(options, "NSAboutPanelOptionApplicationIcon", icon) }
    }

    func restore(native: MacShellApi, app: ShellRef): Unit {
        if (owned.isNull()) { return }
        if (native.get(app, "applicationIconImage").toUIntNative() == owned.toUIntNative()) {
            native.set(app, "setApplicationIconImage:", previous)
        }
        native.release(previous); native.release(owned)
        previous = ShellRef(); owned = ShellRef()
    }
}

@When[os == "macOS"]
internal class MacShellStatusItem {
    private var bar = ShellRef()
    private var item = ShellRef()

    func apply(native: MacShellApi, model: AppStatusItem, assets: Array<AppAsset>, menu: ShellRef): Unit {
        if (!model.visible) { detach(native); return }
        var image = ShellRef()
        var candidate = ShellRef()
        try {
            for (asset in assets) {
                if (asset.role == model.iconRole) { image = macShellImage(native, asset); break }
            }
            if (image.isNull() && model.title.isEmpty()) {
                throw IllegalArgumentException("status item needs a title or an explicit local icon asset")
            }
            let statusBar = native.require(native.get(native.cls("NSStatusBar"), "systemStatusBar"), "status bar")
            candidate = native.retain(native.require(unsafe {
                CFunc<(ShellRef, ShellRef, Float64) -> ShellRef>(native.symbol("objc_msgSend"))(
                    statusBar, native.sel("statusItemWithLength:"), -1.0)
            }, "status item"))
            // Configure before making the new item visible; keep the old item on validation failure.
            native.boolean(candidate, "setVisible:", false)
            let button = native.require(native.get(candidate, "button"), "status button")
            native.setText(button, "setTitle:", model.title)
            native.setText(button, "setToolTip:", model.tooltip)
            if (image.isNotNull()) {
                native.boolean(image, "setTemplate:", model.templateIcon)
                unsafe { CFunc<(ShellRef, ShellRef, MacShellSize) -> Unit>(native.symbol("objc_msgSend"))(
                    image, native.sel("setSize:"), MacShellSize(18.0, 18.0)) }
                native.set(button, "setImage:", image)
            }
            native.set(candidate, "setMenu:", menu)
            detach(native)
            bar = native.retain(statusBar)
            item = candidate
            candidate = ShellRef()
            native.boolean(item, "setVisible:", true)
        } finally {
            if (candidate.isNotNull()) {
                let statusBar = native.get(native.cls("NSStatusBar"), "systemStatusBar")
                native.set(statusBar, "removeStatusItem:", candidate)
                native.release(candidate)
            }
            native.release(image)
        }
    }

    func detach(native: MacShellApi): Unit {
        if (item.isNull()) { return }
        native.set(item, "setMenu:", ShellRef())
        native.set(bar, "removeStatusItem:", item)
        native.release(item); native.release(bar)
        item = ShellRef(); bar = ShellRef()
    }
}

@When[os == "macOS"]
@C
internal struct MacShellSize {
    let width: Float64
    let height: Float64
    init(width: Float64, height: Float64) { this.width = width; this.height = height }
}
