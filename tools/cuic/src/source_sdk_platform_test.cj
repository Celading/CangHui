package cuic

private let SDK_PLATFORM_TEST_REVISION = "0123456789012345678901234567890123456789"
private let SDK_PLATFORM_TEST_LIBS = "libSDL3.so,libSDL3.so.0,libSDL3_ttf.so,libSDL3_ttf.so.0"

private func linuxSdkTestManifest(): String {
    "schema=canghui.source-sdk/v2\nsourceCommit=${SDK_PLATFORM_TEST_REVISION}\n" +
    "cuicVersion=0.6.0\nframeworkVersion=0.17.0\nkitVersion=0.1.0\ncompilerVersion=1.1.3\n" +
    "target=linux-arm64\nlibc=glibc\nminimumLibc=2.38\nnativeFiles=${SDK_PLATFORM_TEST_LIBS}\n"
}

private func sdkPlatformRejects(action: () -> Unit): Bool {
    try { action(); false } catch (_: CuicError) { true }
}

@Test
func sourceSdkExecutionSupportsOnlyImplementedTargets(): Unit {
    requireSourceSdkExecutionTarget("macos-arm64")
    requireSourceSdkExecutionTarget("linux-arm64")
    requireSourceSdkExecutionTarget("linux-x86_64")
    for (target in ["linux-riscv64", "windows-x86_64", ""]) {
        @Expect(sdkPlatformRejects({=> requireSourceSdkExecutionTarget(target) }))
    }
}

@Test
func sourceSdkInitPreservesMacRelocationWithoutPassingMachOFlagsToLinux(): Unit {
    @Expect(sourceSdkInitLinkOption(true, "macos").contains("headerpad_max_install_names"))
    @Expect(sourceSdkInitLinkOption(true, "linux"), "")
    @Expect(sourceSdkInitLinkOption(false, "macos"), "")
}

@Test
func sourceSdkLinuxHostPrerequisitesUseActualCompilerAndLibc(): Unit {
    if (!sourceSdkLinuxTarget(sourceSdkHostTarget())) { return }
    let manifest = linuxSdkTestManifest().replace("linux-arm64", sourceSdkHostTarget())
    let fields = sourceSdkFields(manifest, "", "", "", paired: false)
    fields["minimumLibc"] = "2.1"
    @Expect(sourceSdkHostCheck(fields), "prerequisites-match-not-runtime-proof")
    fields["minimumLibc"] = "999.0"
    @Expect(sourceSdkHostCheck(fields), "minimum-libc-not-met-or-unavailable")
    fields["target"] = "macos-arm64"
    @Expect(sourceSdkHostCheck(fields), "unsupported-host-target")
}

@Test
func sourceSdkHostTargetNormalizesLinuxArmWithoutChangingGlobalStagingNames(): Unit {
    @Expect(sourceSdkTargetForHost("linux", "aarch64"), "linux-arm64")
    @Expect(sourceSdkTargetForHost("linux", "arm64"), "linux-arm64")
    @Expect(sourceSdkTargetForHost("linux", "x86_64"), "linux-x86_64")
    @Expect(sourceSdkTargetForHost("macos", "arm64"), "macos-arm64")
    @Expect(sourceSdkTargetForHost("linux", "riscv64"), "linux-riscv64")
    @Expect(!sourceSdkLinuxTarget(sourceSdkTargetForHost("linux", "riscv64")))
}

@Test
func sourceSdkLinuxMetadataSeparatesLibcFromOSAndPairsExactTarget(): Unit {
    let manifest = linuxSdkTestManifest()
    let fields = sourceSdkFields(manifest, SDK_PLATFORM_TEST_REVISION, "0.6.0", "linux-arm64")
    @Expect(fields["minimumLibc"], "2.38")
    @Expect(!fields.contains("minimumOS"))
    @Expect(sourceSdkFields(manifest, "", "", "", paired: false)["target"], "linux-arm64")
    for (target in ["", "macos-arm64", "linux-x86_64", "linux-riscv64"]) {
        @Expect(sdkPlatformRejects({=> let _ = sourceSdkFields(manifest, SDK_PLATFORM_TEST_REVISION, "0.6.0", target) }))
    }
    for (bad in [manifest.replace("/v2", "/v1"), manifest.replace("libc=glibc", "libc=musl"),
        manifest.replace("minimumLibc=2.38\n", ""), manifest + "minimumOS=2.38\n",
        manifest.replace("minimumLibc=2.38", "minimumLibc=2.38;run")]) {
        @Expect(sdkPlatformRejects({=> let _ = sourceSdkFields(bad, "", "", "", paired: false) }))
    }
}

@Test
func sourceSdkLinuxCompilerAndLibcChecksRejectAmbiguousVersionOrTarget(): Unit {
    let output = "Cangjie Compiler: 1.1.3 (cjnative)\nTarget: aarch64-unknown-linux-gnu\n"
    @Expect(sourceSdkCompilerMatches(output, target: "linux-arm64"))
    @Expect(!sourceSdkCompilerMatches(output, target: "macos-arm64"))
    @Expect(!sourceSdkCompilerMatches(output.replace("1.1.3", "1.1.30"), target: "linux-arm64"))
    @Expect(sourceSdkCompilerMatches(output.replace("aarch64", "x86_64"), target: "linux-x86_64"))
    @Expect(sourceSdkLibcMatches("glibc 2.41\n", "2.38"))
    @Expect(sourceSdkLibcMatches("glibc 2.38", "2.38.0"))
    for (bad in ["glibc 2.37", "musl 2.41", "2.41", "glibc 2.41;run", "glibc 2.41\nextra"]) {
        @Expect(!sourceSdkLibcMatches(bad, "2.38"))
    }
}

@Test
func sourceSdkLinuxNativeNamesNeedBothLinkerAndLoaderFiles(): Unit {
    @Expect(sourceSdkNativeNames(SDK_PLATFORM_TEST_LIBS, target: "linux-arm64").size, 4)
    for (bad in [SDK_PLATFORM_TEST_LIBS + ",libc.so.6", SDK_PLATFORM_TEST_LIBS + ",../libx.so",
        SDK_PLATFORM_TEST_LIBS + ",libSDL3.so", SDK_PLATFORM_TEST_LIBS.replace("libSDL3.so,", ""),
        SDK_PLATFORM_TEST_LIBS + ",libx.so..1", SDK_PLATFORM_TEST_LIBS + ",libx.so.1\n"]) {
        @Expect(sdkPlatformRejects({=> let _ = sourceSdkNativeNames(bad, target: "linux-arm64") }))
    }
    @Expect(sdkPlatformRejects({=> let _ = sourceSdkNativeNames(SDK_PLATFORM_TEST_LIBS) }))
}

@Test
func sourceSdkCrossPlatformComparisonReportsDifferentRequirementsWithoutInferringCompatibility(): Unit {
    let linuxFields = sourceSdkFields(linuxSdkTestManifest(), "", "", "", paired: false)
    let macManifest = linuxSdkTestManifest().replace("/v2", "/v1").replace("linux-arm64", "macos-arm64")
        .replace("libc=glibc\nminimumLibc=2.38", "minimumOS=15.0")
        .replace(SDK_PLATFORM_TEST_LIBS, "libSDL3.dylib,libSDL3_ttf.dylib")
    let macFields = sourceSdkFields(macManifest, "", "", "", paired: false)
    let linux = SourceSdkInspection(linuxFields, "linux-ledger")
    let mac = SourceSdkInspection(macFields, "mac-ledger")
    let report = sourceSdkComparisonJson(mac, linux)
    @Expect(report.contains("\"minimumOS\""))
    @Expect(report.contains("\"minimumLibc\""))
    @Expect(report.contains("requires-consumer-regression"))
    let inspected = sourceSdkInspectionJson(linux)
    @Expect(inspected.contains("\"minimumLibc\":\"2.38\""))
    @Expect(!inspected.contains("\"minimumOS\""))
    @Expect(inspected.contains("\"publisherAuthenticated\":false"))
    @Expect(inspected.contains("\"targetExecutionImplemented\":true"))
    let otherTargetFields = if (hostPlatform() == "linux") { macFields } else { linuxFields }
    otherTargetFields["sourceCommit"] = CUIC_BUILD_REVISION
    otherTargetFields["cuicVersion"] = VERSION
    @Expect(sourceSdkInspectionJson(SourceSdkInspection(otherTargetFields, "same-source-other-target"))
        .contains("\"pairedWithThisCuic\":false"))
}
