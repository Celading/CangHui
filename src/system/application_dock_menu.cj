package chui.system

/** Optional application Dock menu SPI; old providers remain source compatible.
 * None removes the custom menu. AppMenu action IDs share the Shell registry. */
public interface SystemShellDockMenuProvider {
    func setDockMenu(menu: ?AppMenu): SystemShellResult
}

/** Snapshot mutable caller arrays before queuing or exposing a native surface. */
internal func copyApplicationDockMenu(menu: ?AppMenu): ?AppMenu {
    if (let Some(value) <- menu) {
        if (value.title.contains("\u{0}") || value.actionIds.size > 256) {
            throw IllegalArgumentException("Dock menu requires a NUL-free title and at most 256 actions")
        }
        for (i in 0..value.actionIds.size) {
            validateAppActionId(value.actionIds[i])
            for (j in (i + 1)..value.actionIds.size) {
                if (value.actionIds[i] == value.actionIds[j]) {
                    throw IllegalArgumentException("duplicate Dock menu action: " + value.actionIds[i])
                }
            }
        }
        return Some(AppMenu(value.id, value.title, actionIds: value.actionIds.clone()))
    }
    None
}
