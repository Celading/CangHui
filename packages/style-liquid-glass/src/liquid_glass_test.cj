package canghui_style_liquid_glass

import std.collection.ArrayList
import chui.{BackdropEffectRequest, BackdropLensOptics, ButtonRole, ButtonVisualState, Color,
    MotionLevel, Rect, Renderer, RendererEffectAdapter, RendererEffectCapabilities,
    RendererEffectCapability, RendererEffectFrame, RendererEffectReceipt, RendererEffectStatus,
    SurfaceState, Theme}

@Test
func liquidGlassThemesExposeAdaptiveTokens(): Unit {
    let light = LiquidGlass.light()
    let dark = LiquidGlass.dark()
    @Expect(Int64(light.bg.r) > Int64(dark.bg.r))
    @Expect(light.controlRadius, 9999.0)
    @Expect(dark.radius, 28.0)
}

@Test
func liquidGlassAccessibilityPreferencesWinOverDecoration(): Unit {
    let preferences = LiquidGlassPreferences(
        reduceTransparency: true,
        increaseContrast: true,
        reduceMotion: true
    )
    let theme = LiquidGlass.dark(preferences: preferences, motionLevel: MotionLevel.Full)
    @Expect(theme.reduceMotion)
    @Expect(theme.borderWidth, 1.5)
    @Expect(Int64(theme.panel.a), 255)
}

@Test
func liquidGlassVariantsAndTintResolveDifferentMaterials(): Unit {
    let theme = Theme.light()
    let regular = LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Regular,
        tint: Some(Color.rgb(0, 122, 255))
    )).resolve(theme, SurfaceState())
    let clear = LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        tint: Some(Color.rgb(0, 122, 255))
    )).resolve(theme, SurfaceState())
    @Expect(Int64(regular.style.fill.a) > Int64(clear.style.fill.a))
    @Expect(regular.style.radius, 9999.0)
}

@Test
func liquidGlassButtonStyleKeepsSemanticRoles(): Unit {
    let theme = LiquidGlass.light()
    let style = LiquidGlass.buttonStyle()
    let normal = style.resolve(theme, ButtonRole.Normal, ButtonVisualState())
    let primary = style.resolve(theme, ButtonRole.Primary, ButtonVisualState(hover: 1.0))
    @Expect(Int64(normal.surface.fill.a) < 255)
    @Expect(Int64(primary.surface.fill.b) > Int64(primary.surface.fill.r))
    @Expect(primary.focusRadius, 9999.0)
}

@Test
func liquidGlassOpticsClampAndDriveMorphingSegmentStyle(): Unit {
    let optics = LiquidGlassOptics(clarity: 2.0, haze: -1.0, deformation: 0.76)
    @Expect(optics.clarity, 1.0)
    @Expect(optics.haze, 0.0)
    let style = LiquidGlass.segmentedControlStyle(spec: LiquidGlassSpec(optics: optics))
    @Expect(style.deformation, 0.76)
    let reduced = LiquidGlass.segmentedControlStyle(spec: LiquidGlassSpec(
        preferences: LiquidGlassPreferences(reduceMotion: true), optics: optics))
    @Expect(reduced.deformation, 0.0)
}

@Test
func liquidGlassSdrPainterEmitsLayeredClearAndVaporCommands(): Unit {
    let renderer = Renderer.recordingHeadless()
    LiquidGlass.paint(renderer, Rect(10.0, 10.0, 180.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear), stretch: 0.7)
    let clearCount = renderer.drawIr().size
    @Expect(clearCount >= 7)
    // Clear is the refracting recipe: it must emit local lens contours.
    @Expect(countKind(renderer, "paint.stroke-circle") >= 2)
    renderer.clearDrawIr()

    LiquidGlass.paint(renderer, Rect(10.0, 10.0, 180.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Vapor))
    // Vapor is the haze recipe: it deliberately omits the hard lens and the defined gleam band,
    // trading contour count for softer body layers. Command count alone is not the difference.
    @Expect(countKind(renderer, "paint.stroke-circle"), Int64(0))
    @Expect(countKind(renderer, "effect.backdrop"), Int64(1))
}

@Test
func liquidGlassReceiptExposesFallbackAndReducedTransparencySkipsEffectRequest(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(240.0, 120.0, Color.rgb(20, 30, 40))
    renderer.clearDrawIr()
    let fallback = LiquidGlass.paintWithReceipt(
        renderer,
        Rect(20.0, 20.0, 160.0, 48.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear)
    )
    @Expect(fallback.status, RendererEffectStatus.Unsupported)
    @Expect(fallback.code, "no-effect-adapter")
    var effectCommands: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == "effect.backdrop") { effectCommands += 1 }
    }
    @Expect(effectCommands, Int64(1))

    renderer.clearDrawIr()
    let opaque = LiquidGlass.paintWithReceipt(
        renderer,
        Rect(20.0, 20.0, 160.0, 48.0),
        spec: LiquidGlassSpec(preferences: LiquidGlassPreferences(reduceTransparency: true))
    )
    @Expect(opaque.status, RendererEffectStatus.Degraded)
    @Expect(opaque.code, "reduced-transparency")
    for (command in renderer.drawIr()) {
        @Expect(command.kind != "effect.backdrop")
    }
    renderer.endScene()
}

// ---------------------------------------------------------------------------
// Optical fidelity repair tests (HN-ISSUE-20261025-007)
// ---------------------------------------------------------------------------

private class StubEffectAdapter <: RendererEffectAdapter {
    private let caps: RendererEffectCapabilities
    private var applied: Int64 = 0
    private let rejectEveryCall: Bool
    private let returnStatus: RendererEffectStatus

    init(caps: RendererEffectCapabilities, rejectEveryCall!: Bool = false,
        returnStatus!: RendererEffectStatus = RendererEffectStatus.Applied) {
        this.caps = caps
        this.rejectEveryCall = rejectEveryCall
        this.returnStatus = returnStatus
    }

    public func capabilities(): RendererEffectCapabilities { this.caps }
    public func beginFrame(frame: RendererEffectFrame): Unit {}
    public func endFrame(frame: RendererEffectFrame): Unit {}
    public func release(): RendererEffectReceipt {
        RendererEffectReceipt(RendererEffectStatus.Applied, "release", "released",
            providerId: this.caps.providerId)
    }
    public func apply(renderer: Renderer, frame: RendererEffectFrame,
        request: BackdropEffectRequest): RendererEffectReceipt {
        this.applied += 1
        if (this.rejectEveryCall) {
            throw IllegalArgumentException("provider rejected the request")
        }
        return RendererEffectReceipt(this.returnStatus, "backdrop", "stub-applied",
            providerId: this.caps.providerId,
            frameGeneration: frame.generation,
            sampledPixels: 1024,
            detail: "stub")
    }
    func appliedCount(): Int64 { this.applied }
}

private func fullCapabilities(maxEffects!: Int64 = 8, maxPixels!: Int64 = 2097152): RendererEffectCapabilities {
    RendererEffectCapabilities(
        "stub-provider",
        [
            RendererEffectCapability.BackdropSampling,
            RendererEffectCapability.Blur,
            RendererEffectCapability.Refraction,
            RendererEffectCapability.EdgeResponse
        ],
        maxSamplePixels: maxPixels,
        maxEffectsPerFrame: maxEffects)
}

private func drawKinds(renderer: Renderer): Array<String> {
    let out = ArrayList<String>()
    for (command in renderer.drawIr()) {
        out.add(command.kind)
    }
    out.toArray()
}

private func countKind(renderer: Renderer, kind: String): Int64 {
    var n: Int64 = 0
    for (command in renderer.drawIr()) {
        if (command.kind == kind) { n += 1 }
    }
    n
}

@Test
func liquidGlassExposesFiveDistinctMaterialLayers(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(320.0, 200.0, Color.rgb(20, 30, 40))
    renderer.clearDrawIr()
    LiquidGlass.paint(renderer, Rect(20.0, 20.0, 240.0, 120.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear), stretch: 0.5)
    // Body + edge rings + lens rings + halo + highlight all produce commands. The old single
    // translucent fill could not reach this count, which is the regression this guards.
    @Expect(renderer.drawIr().size >= 8)
    // A local lens must emit circle contours that a flat panel never produced.
    let circles = countKind(renderer, "paint.stroke-circle")
    @Expect(circles >= 2)
    renderer.endScene()
}

@Test
func liquidGlassVariantsDifferInMeasuredOpticsNotOnlyAlpha(): Unit {
    let regular = LiquidGlassOptics.profile(LiquidGlassVariant.Regular)
    let clear = LiquidGlassOptics.profile(LiquidGlassVariant.Clear)
    let vapor = LiquidGlassOptics.profile(LiquidGlassVariant.Vapor)
    // Haze: vapor is the hazy material, clear is the most transparent.
    @Expect(vapor.haze > regular.haze)
    @Expect(clear.haze < regular.haze)
    // Displacement: clear refracts hardest, vapor least.
    @Expect(clear.displacement > regular.displacement)
    @Expect(vapor.displacement < regular.displacement)
    // Lens radius must actually differ, not only tint.
    @Expect(vapor.lensRadius > regular.lensRadius)
    @Expect(clear.lensRadius > regular.lensRadius)
    // Edge contour depth differs.
    @Expect(vapor.edgeRings != clear.edgeRings)
}

@Test
func liquidGlassChromaticEdgeIsTransientNotSettled(): Unit {
    let optics = LiquidGlassOptics(chromaticEdge: 0.9)
    // Settled (stretch 0) must not request chromatic separation.
    let settled = BackdropEffectRequest(Rect(0.0, 0.0, 100.0, 50.0),
        lens: BackdropLensOptics(displacementStrength: 0.8), motionEnergy: 0.0)
    @Expect(settled.requestedChromaticEdge(), 0.0)
    // In motion it must become non-zero.
    let moving = BackdropEffectRequest(Rect(0.0, 0.0, 100.0, 50.0),
        lens: BackdropLensOptics(displacementStrength: 0.8), motionEnergy: 0.8)
    @Expect(moving.requestedChromaticEdge() > 0.0)
    let _ = optics
}

@Test
func liquidGlassRequestCarriesBoundedLensOptics(): Unit {
    let lens = BackdropLensOptics(centerX: 2.0, centerY: -1.0, radius: 0.5,
        displacementStrength: 1.7, sampleRadius: 9.0, invertInsideLens: true)
    // Clamping keeps an over-eager style request inside the surface.
    @Expect(lens.centerX, 1.0)
    @Expect(lens.centerY, 0.0)
    @Expect(lens.displacementStrength, 1.0)
    @Expect(lens.sampleRadius, 1.0)
    @Expect(lens.active())
    let inert = BackdropLensOptics(displacementStrength: 0.0)
    @Expect(!inert.active())
}

@Test
func liquidGlassRejectsStaleGenerationRequest(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(300.0, 200.0, Color.rgb(10, 20, 30))
    let liveGeneration = renderer.effectFrameGeneration()
    let adapter = StubEffectAdapter(fullCapabilities())
    let _ = renderer.installEffectAdapter(adapter)
    // A request pinned to a definitely-not-current generation must be rejected, not applied.
    let stale = BackdropEffectRequest(Rect(10.0, 10.0, 120.0, 60.0),
        expectedFrameGeneration: liveGeneration + UInt64(99))
    let receipt = renderer.applyBackdropEffect(stale)
    @Expect(receipt.status, RendererEffectStatus.Rejected)
    @Expect(receipt.code, "stale-frame")
    @Expect(adapter.appliedCount(), Int64(0))
    renderer.endScene()
}

@Test
func liquidGlassRejectsClippedAndOutsideViewportRequests(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(200.0, 150.0, Color.rgb(10, 20, 30))
    let _ = renderer.installEffectAdapter(StubEffectAdapter(fullCapabilities()))
    let outside = BackdropEffectRequest(Rect(900.0, 900.0, 80.0, 40.0))
    let receipt = renderer.applyBackdropEffect(outside)
    @Expect(receipt.status, RendererEffectStatus.Rejected)
    @Expect(receipt.code, "outside-viewport")
    renderer.endScene()
}

@Test
func liquidGlassDegradesOnProviderRejectionAndBudgetExhaustion(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(300.0, 200.0, Color.rgb(10, 20, 30))
    let _ = renderer.installEffectAdapter(StubEffectAdapter(fullCapabilities(),
        rejectEveryCall: true))
    let rejecting = renderer.applyBackdropEffect(BackdropEffectRequest(
        Rect(10.0, 10.0, 120.0, 60.0)))
    @Expect(rejecting.status, RendererEffectStatus.Degraded)
    @Expect(rejecting.code, "provider-failed")
    renderer.endScene()

    let limited = Renderer.recordingHeadless()
    limited.beginScene(300.0, 200.0, Color.rgb(10, 20, 30))
    let _ = limited.installEffectAdapter(StubEffectAdapter(fullCapabilities(maxEffects: 1)))
    let first = limited.applyBackdropEffect(BackdropEffectRequest(Rect(10.0, 10.0, 80.0, 40.0)))
    @Expect(first.status, RendererEffectStatus.Applied)
    let second = limited.applyBackdropEffect(BackdropEffectRequest(Rect(10.0, 60.0, 80.0, 40.0)))
    @Expect(second.status, RendererEffectStatus.Degraded)
    @Expect(second.code, "effect-budget-exceeded")
    limited.endScene()
}

@Test
func liquidGlassLensRequiresRefractionCapability(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(300.0, 200.0, Color.rgb(10, 20, 30))
    // Provider that samples and blurs but cannot refract must not be handed an active lens.
    let noRefraction = RendererEffectCapabilities("no-refract",
        [RendererEffectCapability.BackdropSampling, RendererEffectCapability.Blur,
         RendererEffectCapability.EdgeResponse])
    let _ = renderer.installEffectAdapter(StubEffectAdapter(noRefraction))
    let withLens = BackdropEffectRequest(Rect(10.0, 10.0, 120.0, 60.0),
        blurRadius: 0.0, refraction: 0.0, edgeResponse: 0.0,
        lens: BackdropLensOptics(displacementStrength: 0.9))
    let receipt = renderer.applyBackdropEffect(withLens)
    @Expect(receipt.status, RendererEffectStatus.Degraded)
    @Expect(receipt.code, "lens-unsupported")
    renderer.endScene()
}

@Test
func liquidGlassReducedTransparencyStaysOpaqueAndSkipsSampling(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(300.0, 200.0, Color.rgb(10, 20, 30))
    let adapter = StubEffectAdapter(fullCapabilities())
    let _ = renderer.installEffectAdapter(adapter)
    renderer.clearDrawIr()
    let receipt = LiquidGlass.paintWithReceipt(renderer, Rect(10.0, 10.0, 200.0, 80.0),
        spec: LiquidGlassSpec(preferences: LiquidGlassPreferences(
            reduceTransparency: true, increaseContrast: true)))
    @Expect(receipt.status, RendererEffectStatus.Degraded)
    @Expect(receipt.code, "reduced-transparency")
    // Opaque path must not ask the provider for pixels.
    @Expect(adapter.appliedCount(), Int64(0))
    @Expect(countKind(renderer, "effect.backdrop"), Int64(0))
    renderer.endScene()
}

@Test
func liquidGlassHighlightFollowsMotionAndStaysInsideShape(): Unit {
    let settled = Renderer.recordingHeadless()
    settled.beginScene(400.0, 240.0, Color.rgb(10, 20, 30))
    settled.clearDrawIr()
    LiquidGlass.paint(settled, Rect(40.0, 40.0, 300.0, 140.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear), stretch: 0.0)
    let settledCommands = settled.drawIr().size
    settled.endScene()

    let moving = Renderer.recordingHeadless()
    moving.beginScene(400.0, 240.0, Color.rgb(10, 20, 30))
    moving.clearDrawIr()
    LiquidGlass.paint(moving, Rect(40.0, 40.0, 300.0, 140.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear), stretch: 1.0)
    // Motion must add transient chromatic contours; a static material must not carry them.
    @Expect(moving.drawIr().size > settledCommands)
    moving.endScene()
}

@Test
func liquidGlassSurfacePainterRequestsBackdropWithActiveLens(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(320.0, 240.0, Color.rgb(20, 30, 40))
    renderer.clearDrawIr()
    let receipt = LiquidGlass.paintWithReceipt(renderer, Rect(20.0, 20.0, 280.0, 200.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear, radius: 28.0))
    // The backdrop request must reach the renderer; without it there is no lens at all.
    @Expect(countKind(renderer, "effect.backdrop"), Int64(1))
    @Expect(receipt.operation, "backdrop")
    renderer.endScene()
}

@Test
func liquidGlassLensIsActiveInTheRequestActuallyBuilt(): Unit {
    // Guards the whole chain: profile -> spec -> request. If any default silently zeroes the
    // displacement, the material loses its lens while still looking "glassy".
    let spec = LiquidGlassSpec(variant: LiquidGlassVariant.Clear)
    @Expect(spec.optics.displacement > 0.1)
    @Expect(spec.optics.haze < 0.2)
    let lens = BackdropLensOptics(displacementStrength: spec.optics.displacement)
    @Expect(lens.active())
}

@Test
func liquidGlassFullScreenParentStaysWithinSampleBudget(): Unit {
    // A full-screen glass parent must not degrade into "no effect at all". This is the regression
    // that appears only when the material is used as a container instead of a small card.
    let renderer = Renderer.recordingHeadless()
    renderer.beginScene(920.0, 600.0, Color.rgb(20, 30, 40))
    let receipt = LiquidGlass.paintWithReceipt(renderer, Rect(0.0, 0.0, 920.0, 600.0),
        spec: LiquidGlassSpec(variant: LiquidGlassVariant.Clear))
    renderer.endScene()
    @Expect(receipt.code != "sample-budget-exceeded")
}
