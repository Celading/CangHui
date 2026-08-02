package cuic

@Test
func doctorOptionsKeepCompatibilityAndMachineModes(): Unit {
    let options = parseDoctorOptions([
        "cuic", "doctor", "ipad", "--project", "demo", "--json", "--verbose"
    ], 2)
    @Expect(options.target, "ios")
    @Expect(options.project, "demo")
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

@Test
func doctorIosReportsBootstrapAndNativeSurfaceAdapter(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorIosFrameworkChecks(framework)
    var readyBootstrapAssets: Int64 = 0
    var readySurfaceAssets: Int64 = 0
    var rendererReady = false
    for (check in checks) {
        if (startsWithText(check.id, "ios.bootstrap-") &&
            doctorStatusName(check.status) == "ready") {
            readyBootstrapAssets += 1
        }
        if (startsWithText(check.id, "ios.surface-") &&
            doctorStatusName(check.status) == "ready") {
            readySurfaceAssets += 1
        }
        if (check.id == "ios.renderer" && doctorStatusName(check.status) == "ready") {
            rendererReady = true
        }
    }
    @Expect(readyBootstrapAssets, Int64(3))
    @Expect(readySurfaceAssets, Int64(3))
    @Expect(rendererReady)
}

@Test
func doctorAndroidReportsBootstrapWithoutClaimingRuntimeCompletion(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorAndroidGroup(framework).checks
    var readySurfaceAssets: Int64 = 0
    var backendDegraded = false
    for (check in checks) {
        if (startsWithText(check.id, "android.surface-") &&
            doctorStatusName(check.status) == "ready") {
            readySurfaceAssets += 1
        }
        if (check.id == "android.backend" && doctorStatusName(check.status) == "degraded") {
            backendDegraded = true
        }
    }
    @Expect(readySurfaceAssets, Int64(4))
    @Expect(backendDegraded)
}
