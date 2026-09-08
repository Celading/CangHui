package chui.system

/** Own only the label we changed; leave application icons, tile views and delegates alone. */
@When[os == "macOS"]
internal class MacShellBadge {
    private var tile = ShellRef()
    private var previous = ShellRef()
    private var last = ShellRef()

    func apply(native: MacShellApi, app: ShellRef, label: ?String): Unit {
        validateApplicationBadge(label)
        var value = ShellRef()
        try {
            if (let Some(text) <- label) { if (!text.isEmpty()) { value = native.text(text) } }
            if (tile.isNull()) {
                tile = native.retain(native.require(native.get(app, "dockTile"), "Dock tile"))
                previous = native.retain(native.get(tile, "badgeLabel"))
            }
            native.set(tile, "setBadgeLabel:", value)
            native.release(last)
            last = native.retain(native.get(tile, "badgeLabel"))
        } finally { native.release(value) }
    }

    func restore(native: MacShellApi): Unit {
        if (tile.isNull()) { return }
        let current = native.get(tile, "badgeLabel")
        var same = current.toUIntNative() == last.toUIntNative()
        if (!same && current.isNotNull() && last.isNotNull()) {
            same = unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>(native.symbol("objc_msgSend"))(
                current, native.sel("isEqualToString:"), last) }
        }
        // A different label installed by another owner wins over our saved value.
        if (same) { native.set(tile, "setBadgeLabel:", previous) }
        native.release(last); native.release(previous); native.release(tile)
        last = ShellRef(); previous = ShellRef(); tile = ShellRef()
    }
}
