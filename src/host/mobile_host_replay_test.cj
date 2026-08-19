package cui.host

func replayFixtureReceipt(): MobileHostPackageReceipt {
    MobileHostPackageReceipt(
        MobileApplicationPlatform.Android,
        MobilePackageKind.AndroidApplicationPackage,
        MobilePackageStage.InputTree,
        "dev.canghui.replay",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        permissions: [
            MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired),
            MobilePermissionReceipt(HostCapability.TouchInput, MobilePermissionState.Granted)
        ],
        inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libcanghui.so"],
        limitations: ["unsigned consumer fixture", "no device proof"]
    )
}

@Test
func mobileHostSemanticReplayClassifiesCurrentAndStaleCallbacks(): Unit {
    let replay = replayMobileHostSemantics(replayFixtureReceipt(), contexts: [
        MobileHostCallbackContext("player.toggle", 4, 9),
        MobileHostCallbackContext("player.seek", 3, 9),
        MobileHostCallbackContext("player.open", 4, 8),
        MobileHostCallbackContext("player.close", 3, 8)
    ])
    @Expect(replay.protocol, CANGHUI_MOBILE_HOST_REPLAY_PROTOCOL)
    @Expect(replay.callbacks.size, Int64(4))
    @Expect(replay.callbacks[0].accepted)
    @Expect(replay.callbacks[0].decision, MobileHostCallbackDecision.Current)
    @Expect(replay.callbacks[1].decision, MobileHostCallbackDecision.StaleLifecycle)
    @Expect(replay.callbacks[2].decision, MobileHostCallbackDecision.StaleSurface)
    @Expect(replay.callbacks[3].decision, MobileHostCallbackDecision.StaleLifecycleAndSurface)
}

@Test
func mobileHostSemanticReplayRendersHonestPackageAndPermissionState(): Unit {
    let json = renderMobileHostSemanticReplay(replayFixtureReceipt(), contexts: [
        MobileHostCallbackContext("player.toggle", 4, 9)
    ])
    @Expect(json.contains("\"protocol\":\"canghui.mobile-host-replay.v0\""))
    @Expect(json.contains("\"stage\":\"input-tree\""))
    @Expect(json.contains("\"signing\":\"unsigned\""))
    @Expect(json.contains("\"installable\":false"))
    @Expect(json.contains("\"deviceProven\":false"))
    @Expect(json.contains("\"capability\":\"notifications\""))
    @Expect(json.contains("\"decision\":\"current\""))
}

@Test
func mobileHostSemanticReplayEscapesConsumerControlledStrings(): Unit {
    let receipt = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.ContractReady,
        "dev.canghui.\"quoted\"",
        AppLifecycleState.Launching,
        0,
        0,
        limitations: ["line one\nline two"]
    )
    let json = renderMobileHostSemanticReplay(receipt)
    @Expect(json.contains("dev.canghui.\\\"quoted\\\""))
    @Expect(json.contains("line one\\nline two"))
}

@Test
func mobileSigningPreparationStaysBlockedWithoutSecretCapabilities(): Unit {
    let source = replayFixtureReceipt()
    let receipt = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest("player.apk")
    )
    @Expect(receipt.state, MobileSigningPreparationState.Blocked)
    @Expect(receipt.missingCapabilities.size, Int64(2))
    @Expect(!receipt.signedPackage())
    @Expect(!receipt.installable())
}

@Test
func mobileSigningPreparationBecomesReadyOnlyForExternalSigner(): Unit {
    let source = MobileHostPackageReceipt(
        MobileApplicationPlatform.IOS,
        MobilePackageKind.IOSApplicationBundle,
        MobilePackageStage.InputTree,
        "dev.canghui.ios.signing",
        AppLifecycleState.Active,
        4,
        9,
        signing: MobileSigningState.Unsigned,
        inputFiles: ["Info.plist", "CangHuiRuntimeBootstrap.m"]
    )
    let receipt = prepareMobileSigning(
        source,
        MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["ios-signing-identity", "ios-provisioning-profile"]
        )
    )
    @Expect(receipt.state, MobileSigningPreparationState.RequirementsSatisfied)
    @Expect(receipt.missingCapabilities.size, Int64(0))
    @Expect(receipt.toJson().contains("\"signedPackage\":false"))
    @Expect(receipt.toJson().contains("external platform signer is still required"))
}

@Test
func mobileSigningPreparationRejectsPathLikeLabels(): Unit {
    var rejected = false
    try {
        let _ = MobileSigningPreparationRequest(
            "CangHui.app",
            declaredCapabilities: ["../private-key"]
        )
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}
