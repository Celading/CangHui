package chui.scene3d

@Test
func scene3dNamesAndProtocolStayStable(): Unit {
    @Expect(CANGHUI_SCENE3D_PROTOCOL, "canghui.scene3d.v0")
    @Expect(scene3dBackendName(Scene3DBackend.Metal), "metal")
    @Expect(scene3dBackendName(Scene3DBackend.D3D12), "d3d12")
    @Expect(scene3dEntityKindName(Scene3DEntityKind.UserMarker), "user-marker")
    @Expect(scene3dDebugGeometryFamilyName(Scene3DDebugGeometryFamily.Ribbon), "ribbon")
    @Expect(scene3dSemanticColorName(Scene3DSemanticColor.RouteAccent), "route-accent")
}

@Test
func scene3dDebugProjectionMapsAllGenericEntityKinds(): Unit {
    let floor = projectScene3DEntity(Scene3DEntitySnapshot(
        "floor", 0.0, -1.0, 0.0, kind: Scene3DEntityKind.Floor
    ))
    let route = projectScene3DEntity(Scene3DEntitySnapshot(
        "route", 0.0, -0.8, 0.2, kind: Scene3DEntityKind.Route
    ))
    let vehicle = projectScene3DEntity(Scene3DEntitySnapshot(
        "vehicle", -0.8, -0.3, 0.0, kind: Scene3DEntityKind.Vehicle
    ))
    let user = projectScene3DEntity(Scene3DEntitySnapshot(
        "user", 1.0, -0.2, 0.0, visible: false, kind: Scene3DEntityKind.UserMarker
    ))

    @Expect(floor.geometryFamily == Scene3DDebugGeometryFamily.Slab)
    @Expect(floor.semanticColor == Scene3DSemanticColor.GroundNeutral)
    @Expect(floor.scaleX == 3.8)
    @Expect(route.geometryFamily == Scene3DDebugGeometryFamily.Ribbon)
    @Expect(route.semanticColor == Scene3DSemanticColor.RouteAccent)
    @Expect(route.green == 0.63)
    @Expect(vehicle.geometryFamily == Scene3DDebugGeometryFamily.Box)
    @Expect(vehicle.entityId, "vehicle")
    @Expect(vehicle.x == -0.8)
    @Expect(user.geometryFamily == Scene3DDebugGeometryFamily.Marker)
    @Expect(user.semanticColor == Scene3DSemanticColor.UserHighlight)
    @Expect(!user.visible)
}

@Test
func scene3dEntitySnapshotKeepsLegacyDefaultKind(): Unit {
    let entity = Scene3DEntitySnapshot("legacy", 1.0, 2.0, 3.0)
    @Expect(entity.kind == Scene3DEntityKind.Vehicle)
    @Expect(entity.visible)
}

@Test
func fakeScene3dRunsValidatedLifecycle(): Unit {
    let provider = FakeScene3DProvider()
    let surface = Scene3DHostSurface(
        "station",
        Scene3DBackend.Metal,
        UInt64(7),
        640.0,
        480.0,
        1280,
        960,
        2.0,
        1
    )
    let clock = Scene3DFrameClock(1, 100, 200)
    let resource = Scene3DResource("station-pack", "station.pack", "sha256:fixture", 128)
    let snapshot = Scene3DFrameSnapshot("station-demo")
    snapshot.add(Scene3DEntitySnapshot("platform", 0.0, 0.0, 0.0))

    @Expect(provider.attach(surface, clock).ok)
    @Expect(provider.loadScene(resource).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.present(Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.currentSceneId(), "station-demo")
    @Expect(snapshot.isSealed())
    @Expect(snapshot.entityCount(), 1)
    @Expect(snapshot.entityAt(0).id, "platform")
    @Expect(provider.detach("station", 1).ok)
    @Expect(!provider.isAttached())
}

@Test
func fakeScene3dRejectsStaleSurfaceAndRegressedFrame(): Unit {
    let provider = FakeScene3DProvider()
    let surface = Scene3DHostSurface(
        "station",
        Scene3DBackend.Vulkan,
        UInt64(8),
        320.0,
        240.0,
        640,
        480,
        2.0,
        2
    )
    @Expect(provider.attach(surface, Scene3DFrameClock(4, 400, 500)).ok)
    @Expect(provider.resize(Scene3DHostSurface(
        "station", Scene3DBackend.Vulkan, UInt64(8), 320.0, 240.0, 640, 480, 2.0, 1
    )).code, "stale-generation")

    let resource = Scene3DResource("station-pack", "station.pack", "sha256:fixture", 128)
    let snapshot = Scene3DFrameSnapshot("station-demo")
    snapshot.add(Scene3DEntitySnapshot("gate", 1.0, 0.0, 0.0))
    @Expect(provider.loadScene(resource).ok)
    @Expect(provider.submit(snapshot, Scene3DFrameClock(3, 300, 350)).code, "frame-regressed")
}

@Test
func fakeScene3dReattachDropsPreviousSceneState(): Unit {
    let provider = FakeScene3DProvider()
    let first = Scene3DHostSurface(
        "station", Scene3DBackend.Metal, UInt64(8), 320.0, 240.0, 640, 480, 2.0, 1
    )
    @Expect(provider.attach(first, Scene3DFrameClock(1, 100, 200)).ok)
    @Expect(provider.loadScene(Scene3DResource("pack", "station.pack", "sha256:first", 1)).ok)

    let replacement = Scene3DHostSurface(
        "station", Scene3DBackend.Metal, UInt64(9), 320.0, 240.0, 640, 480, 2.0, 2
    )
    @Expect(provider.attach(replacement, Scene3DFrameClock(2, 200, 300)).ok)
    @Expect(provider.currentSceneId(), "")
    @Expect(provider.submit(Scene3DFrameSnapshot("stale-scene"), Scene3DFrameClock(3, 300, 400)).code,
        "scene-not-loaded")
}

@Test
func scene3dContractsRejectInvalidIdentity(): Unit {
    var surfaceRejected = false
    try {
        let _ = Scene3DHostSurface(
            "", Scene3DBackend.Software, UInt64(0), 1.0, 1.0, 1, 1, 1.0, 0
        )
    } catch (_: IllegalArgumentException) {
        surfaceRejected = true
    }
    @Expect(surfaceRejected)

    var resourceRejected = false
    try {
        let _ = Scene3DResource("pack", "pack", "", 1)
    } catch (_: IllegalArgumentException) {
        resourceRejected = true
    }
    @Expect(resourceRejected)
}
