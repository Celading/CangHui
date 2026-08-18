package cuic

@Test
func applicationManifestParsesIdentityAssetsSystemsAndScripts(): Unit {
    let manifest = parseApplicationManifest(
        "[application]\n" +
        "name = \"Demo\"\n" +
        "identifier = \"dev.example.demo\"\n" +
        "version = \"1.2.3\"\n" +
        "publisher = \"Celading\"\n\n" +
        "[assets]\n" +
        "application-icon = \"assets/app.png\"\n" +
        "resources = [\"assets/data\", \"assets/i18n\"]\n\n" +
        "[system]\n" +
        "single-instance = true\n" +
        "status-item = false\n" +
        "notifications = true\n" +
        "settings = true\n\n" +
        "[scripts]\n" +
        "check = [\"doctor\", \"test\"]\n"
    )
    @Expect(manifest.name, "Demo")
    @Expect(manifest.identifier, "dev.example.demo")
    @Expect(manifest.applicationIcon, "assets/app.png")
    @Expect(manifest.resources.size, Int64(2))
    @Expect(manifest.notifications)
    validateApplicationManifest(manifest, "")
}

@Test
func applicationManifestRejectsMissingIdentityAndEscapingPaths(): Unit {
    var missingRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nversion = \"1.0.0\"\n"
        ), "")
    } catch (_: CuicError) {
        missingRejected = true
    }
    @Expect(missingRejected)

    var absoluteRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\napplication-icon = \"/tmp/app.png\"\n"
        ), "")
    } catch (_: CuicError) {
        absoluteRejected = true
    }
    @Expect(absoluteRejected)

    var traversalRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"assets/../secret\"]\n"
        ), "")
    } catch (_: CuicError) {
        traversalRejected = true
    }
    @Expect(traversalRejected)

    var missingAssetRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"definitely-missing-as-p1-resource\"]\n"
        ), currentDirectory())
    } catch (_: CuicError) {
        missingAssetRejected = true
    }
    @Expect(missingAssetRejected)

    var unsafeNameRejected = false
    try {
        validateApplicationManifest(parseApplicationManifest(
            "[application]\nname = \"../Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
        ), "")
    } catch (_: CuicError) {
        unsafeNameRejected = true
    }
    @Expect(unsafeNameRejected)
}

@Test
func applicationManifestRejectsDuplicateRolesAndResourcePaths(): Unit {
    var roleRejected = false
    try {
        let _ = parseApplicationManifest(
            "[application]\nname = \"Demo\"\nname = \"Other\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n"
        )
    } catch (_: CuicError) {
        roleRejected = true
    }
    @Expect(roleRejected)

    var resourceRejected = false
    try {
        let _ = parseApplicationManifest(
            "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
            "[assets]\nresources = [\"assets/data\", \"assets/data\"]\n"
        )
    } catch (_: CuicError) {
        resourceRejected = true
    }
    @Expect(resourceRejected)
}

@Test
func packagingPlanIsDeterministicAndKeepsNativeGatesVisible(): Unit {
    let manifest = parseApplicationManifest(
        "[application]\nname = \"Demo\"\nidentifier = \"dev.example.demo\"\nversion = \"1.0.0\"\n" +
        "[assets]\napplication-icon = \"assets/app.png\"\nresources = []\n" +
        "[system]\nstatus-item = true\nnotifications = true\n"
    )
    validateApplicationManifest(manifest, "")
    let first = renderApplicationPackagingPlanJson(
        applicationPackagingPlanForManifest("/work/demo", "macos", manifest)
    )
    let second = renderApplicationPackagingPlanJson(
        applicationPackagingPlanForManifest("/work/demo", "macos", manifest)
    )
    @Expect(first, second)
    @Expect(first.contains("\"schema\":\"canghui.packaging-plan.v0\""))
    @Expect(first.contains("Info.plist"))
    @Expect(first.contains("native-provider-pending"))
    @Expect(first.contains("status-item-icon-not-declared"))
    @Expect(first.contains("notification-icon-not-declared"))
}

@Test
func initializedManifestIsAValidMinimalApplicationDeclaration(): Unit {
    let manifest = parseApplicationManifest(defaultProjectManifest(packageName: "hello_app"))
    validateApplicationManifest(manifest, "")
    @Expect(manifest.identifier, "dev.canghui.hello_app")
    @Expect(manifest.resources.isEmpty())
}
