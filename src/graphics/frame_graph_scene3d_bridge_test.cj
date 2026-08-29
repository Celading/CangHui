package chui.graphics

@Test
func scene3DNativeChildBridgeIsExplicitlyNotUnifiedPixels(): Unit {
    let bridged = bridgeScene3DExternalSurface(
        "private-view-name",
        3,
        0,
        FrameExternalMode.NativeChildSurfaceBarrier,
        bounds: Some(FrameDamageRect(10, 20, 200, 120)))
    @Expect(bridged.ok)
    @Expect(bridged.code, "native-child-surface-barrier")
    @Expect(!bridged.unifiedPixels)
    @Expect(!bridged.clipOcclusionUnified)
    match (bridged.pass()) {
        case Some(value) =>
            @Expect(value.kind == FramePassKind.ExternalScene3D)
            @Expect(value.externalMode == FrameExternalMode.NativeChildSurfaceBarrier)
            @Expect(!value.id.key.contains("private-view-name"))
        case None => @Expect(false)
    }
}

@Test
func scene3DSharedTextureRequiresProviderProofAndExecutorCapability(): Unit {
    let unproved = bridgeScene3DExternalSurface(
        "scene", 1, 0, FrameExternalMode.SharedTexture)
    @Expect(!unproved.ok)
    @Expect(unproved.code, "shared-texture-unproven")

    let proved = bridgeScene3DExternalSurface(
        "scene", 1, 0, FrameExternalMode.SharedTexture,
        providerProvedSharedTexture: true)
    @Expect(proved.ok)
    @Expect(proved.unifiedPixels)
    let resource = proved.resource().getOrThrow()
    let pass = proved.pass().getOrThrow()
    let graph = FrameGraph("scene.surface", 1, 1, 320, 180, [resource], [pass])
    let unsupported = compileFrameGraph(
        graph, FrameGraphCompilerState(), FrameGraphExecutorCapabilities())
    @Expect(!unsupported.ok)
    @Expect(unsupported.code, "unsupported-shared-texture")
}
