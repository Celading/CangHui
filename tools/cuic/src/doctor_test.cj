package cuic

@Test
func doctorOptionsKeepCompatibilityAndMachineModes(): Unit {
    let options = parseDoctorOptions(["cuic", "doctor", "ipad", "--json", "--verbose"], 2)
    @Expect(options.target, "ios")
    @Expect(options.json)
    @Expect(options.verbose)
}
@Test
func doctorStatusOnlyCountsRequestedTargetBlockers(): Unit {
    let global = DoctorGroup("global", "Global", "all", [
        doctorReady("global.ready", "Ready", "ok", "")
    ])
    let macos = DoctorGroup("macos", "macOS", "macos", [
        doctorReady("macos.ready", "Ready", "ok", "")
    ])
    let android = DoctorGroup("android", "Android", "android", [
        doctorUnsupported("android.unsupported", "Unsupported", "missing", "none", "")
    ])
    let result = DoctorResult("macos", "arm64", "macos", [global, macos, android])
    @Expect(result.requestedBlockers(), Int64(0))
    @Expect(result.exitCode(), Int64(0))
    @Expect(doctorStatusName(result.requestedStatus()), "ready")
}

@Test
func doctorJsonKeepsStableSchemaAndActionShape(): Unit {
    let group = DoctorGroup("toolchain", "Toolchain", "all", [
        doctorDegraded("toolchain.sample", "Sample", "needs work", DoctorActionKind.Manual, "repair it", "/tmp/tool")
    ])
    let result = DoctorResult("macos", "arm64", "macos", [group])
    let json = renderDoctorJson(result, false)
    @Expect(json.contains("\"schema\":\"canghui.doctor.v0\""))
    @Expect(json.contains("\"status\":\"degraded\""))
    @Expect(json.contains("\"kind\":\"manual\""))
    @Expect(json.contains("\"evidence\":\"\""))
}
