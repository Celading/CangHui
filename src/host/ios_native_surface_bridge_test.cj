package cui.host

@Test
func iosNativeSurfaceBridgeRejectsStaleGenerations(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(17, 320000, 480000, 640, 960, 2000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.resize(360000, 640000, 720, 1280, 2000, 1), 0)
    @Expect(bridge.detach(1), 0)
    @Expect(bridge.frame(3000, 4000, 1), -2)
    @Expect(bridge.attach(23, 360000, 640000, 720, 1280, 2000, 1), -2)
    @Expect(bridge.attach(23, 360000, 640000, 720, 1280, 2000, 2), 0)
    @Expect(bridge.currentGeneration(), 2)
    @Expect(bridge.totalAttachCount(), 2)
    @Expect(bridge.totalResizeCount(), 1)
    @Expect(bridge.totalDetachCount(), 1)
    @Expect(bridge.totalFrameCount(), 1)
}

@Test
func iosNativeSurfaceBridgeCapturesHostFactsThroughOwnerQueue(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(29, 393000, 852000, 1179, 2556, 3000, 1), 0)
    @Expect(bridge.updateSafeArea(59000, 0, 34000, 0), 0)
    @Expect(bridge.updateLifecycle(1), 0)
    @Expect(bridge.touch(0, 7, 120500, 240250, 1234, 1), 0)
    @Expect(bridge.currentSafeTopMilli(), 59000)
    @Expect(bridge.currentSafeBottomMilli(), 34000)
    @Expect(bridge.currentLifecycleState(), 1)
    @Expect(bridge.currentTouchPhase(), 0)
    @Expect(bridge.currentTouchId(), 7)
    @Expect(bridge.currentTouchXMilli(), 120500)
    @Expect(bridge.currentTouchYMilli(), 240250)
    @Expect(bridge.currentTouchTimestampMillis(), 1234)
    @Expect(bridge.totalTouchCount(), 1)
    @Expect(bridge.clearColorArgb(), 4290054911)
}

@Test
func iosNativeSurfaceBridgeValidatesIntegerAbiInputs(): Unit {
    let bridge = IOSNativeSurfaceBridge()
    @Expect(bridge.attach(0, 320000, 480000, 640, 960, 2000, 1), -1)
    @Expect(bridge.attach(17, 0, 480000, 640, 960, 2000, 1), -1)
    @Expect(bridge.updateSafeArea(-1, 0, 0, 0), -1)
    @Expect(bridge.updateLifecycle(6), -1)
    @Expect(bridge.touch(4, 0, 0, 0, 0, 1), -1)
}
