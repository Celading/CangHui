package chui.system

/** Optional application-level badge SPI. Existing shell providers need not implement it.
 * None or an empty label clears the badge; appearance remains platform-defined. */
public interface SystemShellBadgeProvider {
    func setBadge(label: ?String): SystemShellResult
}

internal func validateApplicationBadge(label: ?String): Unit {
    if (let Some(text) <- label) {
        if (text.contains("\u{0}")) { throw IllegalArgumentException("application badge contains NUL") }
    }
}
