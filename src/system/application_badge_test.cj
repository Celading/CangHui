package chui.system

@Test
func applicationBadgeHeadlessCaptureAndClear(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.badge", "1")), provider: provider)
    @Expect(shell.setBadge(Some("12")).status, SystemShellResultStatus.Queued)
    @Expect(provider.capturedBadge().getOrThrow(), "12")
    @Expect(shell.setBadge(Some("")).ok())
    @Expect(provider.capturedBadge().isNone())
    @Expect(shell.setBadge(Some("同步")).ok())
    @Expect(provider.capturedBadge().getOrThrow(), "同步")
    @Expect(shell.setBadge(None).ok())
    @Expect(provider.capturedBadge().isNone())
}

@Test
func applicationBadgeRejectsInvalidLabelWithoutMutationAndClosedShell(): Unit {
    let provider = HeadlessSystemShellProvider()
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.badge", "1")), provider: provider)
    let _ = shell.setBadge(Some("old"))
    var rejected = false
    try { let _ = shell.setBadge(Some("bad\u{0}label")) } catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
    @Expect(provider.capturedBadge().getOrThrow(), "old")
    shell.detach()
    @Expect(shell.setBadge(None).status, SystemShellResultStatus.Failed)
    @Expect(provider.capturedBadge().getOrThrow(), "old")
}

@Test
func applicationBadgeKeepsLegacyProvidersSourceCompatible(): Unit {
    // Existing fixture deliberately implements no badge SPI, even though its
    // historical capability projection reports fallback for all non-secure surfaces.
    let shell = ApplicationShell(ApplicationManifest(AppIdentity("Test", "dev.test.badge", "1")),
        provider: RuntimeShellFixture())
    @Expect(shell.setBadge(Some("1")).status, SystemShellResultStatus.Unsupported)
}
