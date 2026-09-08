package cuic

@Test
func linuxRuntimeRequestKeepsMetadataOnlyBuildsAndAcceptsSameHost(): Unit {
    validateLinuxRuntimeRequest("linux", "macos", "")
    validateLinuxRuntimeRequest("windows", "macos", "")
    validateLinuxRuntimeRequest("linux", "linux", "pack/runtime.json")
}

@Test
func linuxRuntimeRequestRejectsCrossHostAndEscapingPaths(): Unit {
    for ((platform, host, path) in [("linux", "macos", "runtime.json"),
        ("macos", "linux", "runtime.json"), ("linux", "linux", "/tmp/runtime.json"),
        ("linux", "linux", "../runtime.json")]) {
        var rejected = false
        try { validateLinuxRuntimeRequest(platform, host, path) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
}
