package chui.core

@Test
func iosDeviceProfileClassifiesPhonesAndBreakpoints(): Unit {
    let portrait = classifyIOSDevice(IOS_IDIOM_PHONE, 402.0, 874.0, scale: 3.0,
        horizontalSizeClass: 1, verticalSizeClass: 2)
    @Expect(portrait.deviceClass, IOSDeviceClass.IPhone)
    @Expect(portrait.breakpoint, IOSLayoutBreakpoint.Compact)
    @Expect(portrait.orientation, IOSDeviceOrientation.Portrait)
    @Expect(!portrait.usesSidebar)
    @Expect(portrait.recommendedColumns(), 1)

    let landscape = classifyIOSDevice(IOS_IDIOM_PHONE, 956.0, 440.0, scale: 3.0,
        horizontalSizeClass: 2, verticalSizeClass: 1)
    @Expect(landscape.deviceClass, IOSDeviceClass.IPhone)
    @Expect(landscape.breakpoint, IOSLayoutBreakpoint.Medium)
    @Expect(landscape.orientation, IOSDeviceOrientation.Landscape)
    @Expect(!landscape.usesSidebar)
}

@Test
func iosDeviceProfileClassifiesFoldablePhone(): Unit {
    let unfolded = classifyIOSDevice(IOS_IDIOM_PHONE, 700.0, 900.0, scale: 3.0)
    @Expect(unfolded.deviceClass, IOSDeviceClass.IPhoneDuo)
    @Expect(unfolded.breakpoint, IOSLayoutBreakpoint.Medium)
    @Expect(unfolded.usesSidebar)
    let wide = classifyIOSDevice(IOS_IDIOM_PHONE, 1000.0, 800.0, scale: 3.0)
    @Expect(wide.deviceClass, IOSDeviceClass.IPhoneDuo)
    @Expect(wide.breakpoint, IOSLayoutBreakpoint.Medium)
    @Expect(wide.orientation, IOSDeviceOrientation.Landscape)
}

@Test
func iosDeviceProfileSeparatesMiniAndLargePads(): Unit {
    let miniPortrait = classifyIOSDevice(IOS_IDIOM_PAD, 744.0, 1133.0, scale: 2.0)
    @Expect(miniPortrait.deviceClass, IOSDeviceClass.IPadMini)
    @Expect(miniPortrait.breakpoint, IOSLayoutBreakpoint.Medium)
    @Expect(miniPortrait.usesSidebar)

    let miniLandscape = classifyIOSDevice(IOS_IDIOM_PAD, 1133.0, 744.0, scale: 2.0)
    @Expect(miniLandscape.deviceClass, IOSDeviceClass.IPadMini)
    @Expect(miniLandscape.breakpoint, IOSLayoutBreakpoint.Expanded)
    @Expect(miniLandscape.recommendedColumns(), 3)

    let largePortrait = classifyIOSDevice(IOS_IDIOM_PAD, 834.0, 1210.0, scale: 2.0)
    @Expect(largePortrait.deviceClass, IOSDeviceClass.IPadLarge)
    @Expect(largePortrait.breakpoint, IOSLayoutBreakpoint.Medium)

    let largeWide = classifyIOSDevice(IOS_IDIOM_PAD, 1210.0, 834.0, scale: 2.0)
    @Expect(largeWide.deviceClass, IOSDeviceClass.IPadLarge)
    @Expect(largeWide.breakpoint, IOSLayoutBreakpoint.Expanded)
    @Expect(largeWide.orientation, IOSDeviceOrientation.Landscape)
}

@Test
func iosDeviceProfileKeepsUnspecifiedIdiomHonest(): Unit {
    let profile = classifyIOSDevice(0, 900.0, 900.0, scale: 1.0)
    @Expect(profile.deviceClass, IOSDeviceClass.Unspecified)
    @Expect(profile.breakpoint, IOSLayoutBreakpoint.Medium)
    @Expect(!profile.usesSidebar)
}

@Test
func iosDeviceProfileRejectsInvalidInput(): Unit {
    var rejected = false
    try {
        let _ = classifyIOSDevice(IOS_IDIOM_PAD, 0.0, 1000.0)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)

    rejected = false
    try {
        let _ = classifyIOSDevice(9, 900.0, 900.0)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)

    rejected = false
    try {
        let _ = classifyIOSLayoutBreakpoint(-1.0)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

@Test
func iosDeviceProfileJsonCarriesStableFields(): Unit {
    let profile = classifyIOSDevice(IOS_IDIOM_PAD, 1133.0, 744.0, scale: 2.0)
    let json = profile.json()
    @Expect(json.contains("\"deviceClass\":\"ipad-mini\""))
    @Expect(json.contains("\"breakpoint\":\"expanded\""))
    @Expect(json.contains("\"orientation\":\"landscape\""))
    @Expect(json.contains("\"usesSidebar\":true"))
    @Expect(json.contains("\"recommendedColumns\":3"))
}
