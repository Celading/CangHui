package canghui_mobile_host_replay

import cui.*
import cui.kmode.macros.*

private let mobileReceipt = MobileHostPackageReceipt(
    MobileApplicationPlatform.Android,
    MobilePackageKind.AndroidApplicationPackage,
    MobilePackageStage.InputTree,
    "dev.canghui.mobile.replay",
    AppLifecycleState.Active,
    4,
    9,
    signing: MobileSigningState.Unsigned,
    permissions: [
        MobilePermissionReceipt(HostCapability.Notifications, MobilePermissionState.PermissionRequired),
        MobilePermissionReceipt(HostCapability.TouchInput, MobilePermissionState.Granted)
    ],
    inputFiles: ["AndroidManifest.xml", "lib/arm64-v8a/libcanghui.so"],
    limitations: ["unsigned consumer fixture", "no APK or device proof"]
)

private let replayHandler = mobileHostReplayHandler(mobileReceipt)

@KModeLink["mobile.demo.host.replay"]
func replayMobileHost(payload: String): String {
    replayHandler(payload)
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    println("Use cuic kmode call mobile-host-replay mobile.demo.host.replay [payload].")
    0
}
