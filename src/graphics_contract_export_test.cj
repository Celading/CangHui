package chui

@Test
func umbrellaExportsProviderNeutralGraphicsContract(): Unit {
    let limits = GraphicsLimits(4096, 4, 8, 4)
    let capabilities = GraphicsAdapterCapabilities(
        "umbrella-fake",
        "adapter-0",
        GraphicsBackend.Software,
        GraphicsProfile.Core3D,
        limits,
        capabilities: [
            GraphicsCapability.RenderPipeline,
            GraphicsCapability.SampledTexture,
            GraphicsCapability.DepthTexture
        ]
    )
    let request = GraphicsAdapterRequest(
        GraphicsProfile.Core3D,
        requiredCapabilities: [GraphicsCapability.RenderPipeline]
    )

    @Expect(CANGHUI_GRAPHICS_PROTOCOL, "canghui.graphics.v0")
    @Expect(capabilities.supportsProfile(request.profile))
    @Expect(graphicsBackendName(capabilities.backend), "software")
}
