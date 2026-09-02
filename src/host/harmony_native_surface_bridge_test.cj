package chui.host

import sdl.UiEvent

@Test
func harmonyNativeSurfaceBridgeRejectsStaleGenerations(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(17, 1080, 1920, 3000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.resize(1200, 2000, 3000, 1), 0)
    @Expect(bridge.detach(1), 0)
    @Expect(bridge.frame(3000, 4000, 1), -2)
    @Expect(bridge.attach(23, 1200, 2000, 3000, 1), -2)
    @Expect(bridge.attach(23, 1200, 2000, 3000, 2), 0)
    let snapshot = bridge.snapshot()
    @Expect(snapshot.attached)
    @Expect(snapshot.generation, Int64(2))
    @Expect(snapshot.handle, Int64(23))
    @Expect(bridge.totalAttachCount(), Int64(2))
    @Expect(bridge.totalResizeCount(), Int64(1))
    @Expect(bridge.totalDetachCount(), Int64(1))
    @Expect(bridge.totalFrameCount(), Int64(1))
}

@Test
func harmonyNativeSurfaceBridgeValidatesIntegerAbiInputs(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(0, 1080, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 0, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 0, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 3000, 0), -1)
    @Expect(bridge.attach(-1, 1080, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 65536, 1920, 3000, 1), -1)
    @Expect(bridge.attach(17, 1080, 1920, 16001, 1), -1)
    @Expect(bridge.frame(-1, 0, 1), -1)
}

@Test
func harmonyPointerIngressKeepsCaptureScaleMetadataAndRejectsStaleOrientation(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(17, 1000, 500, 1250, 1), 0)
    @Expect(bridge.pointer(
        0, 1, 7, 44, 250000, 125000, 1, 1,
        500, 10000, 8000, 0, 0, 10, 1250, 1, 0, 1), 0)
    var events = bridge.drainPointerEvents()
    @Expect(events.size, 1)
    match (events[0]) {
        case UiEvent.Pointer(event) =>
            @Expect(event.x, 200.0)
            @Expect(event.y, 100.0)
            @Expect(event.sourceDeviceId, UInt64(44))
            @Expect(event.pressure, 0.5)
            @Expect(event.surfaceGeneration, UInt64(1))
        case _ => @Fail("Harmony ingress should retain a rich pointer event")
    }

    @Expect(bridge.resize(1600, 800, 2000, 1), 0)
    @Expect(bridge.pointer(
        1, 1, 7, 44, 250000, 125000, 1, 0,
        500, 10000, 8000, 0, 0, 20, 1250, 1, 0, 1), 0)
    events = bridge.drainPointerEvents()
    match (events[0]) {
        case UiEvent.Pointer(event) =>
            @Expect(event.x, 200.0)
            @Expect(event.transformRevision, UInt64(2))
        case _ => @Fail("capture-time scale should reproject after a scale change")
    }

    @Expect(bridge.updateOrientationRevision(1, 1), 0)
    @Expect(bridge.pointer(
        1, 1, 7, 44, 400000, 200000, 1, 0,
        500, 10000, 8000, 0, 0, 30, 2000, 3, 0, 1), -3)
    @Expect(bridge.drainPointerEvents().size, 0)
}

@Test
func harmonyNativeSurfaceBridgeRejectsRegressedFrameTime(): Unit {
    let bridge = HarmonyNativeSurfaceBridge()
    @Expect(bridge.attach(31, 1080, 1920, 3000, 1), 0)
    @Expect(bridge.frame(1000, 2000, 1), 0)
    @Expect(bridge.frame(999, 2000, 1), -1)
    @Expect(bridge.totalFrameCount(), Int64(1))
}
