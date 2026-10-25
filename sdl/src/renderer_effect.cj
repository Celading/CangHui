package sdl

import std.collection.ArrayList

/** Optional composited effects a 2D renderer adapter can perform. */
public enum RendererEffectCapability <: Equatable<RendererEffectCapability> {
    | BackdropSampling
    | Blur
    | Refraction
    | EdgeResponse
    | ShapeUnion

    public operator func ==(other: RendererEffectCapability): Bool {
        rendererEffectCapabilityName(this) == rendererEffectCapabilityName(other)
    }

    public operator func !=(other: RendererEffectCapability): Bool { !(this == other) }
}

public func rendererEffectCapabilityName(capability: RendererEffectCapability): String {
    match (capability) {
        case RendererEffectCapability.BackdropSampling => "backdrop-sampling"
        case RendererEffectCapability.Blur => "blur"
        case RendererEffectCapability.Refraction => "refraction"
        case RendererEffectCapability.EdgeResponse => "edge-response"
        case RendererEffectCapability.ShapeUnion => "shape-union"
    }
}

/** Immutable provider limits used before an effect request allocates native resources. */
public class RendererEffectCapabilities {
    public let providerId: String
    public let maxSamplePixels: Int64
    public let maxEffectsPerFrame: Int64
    private let values = ArrayList<RendererEffectCapability>()

    public init(
        providerId: String,
        capabilities: Array<RendererEffectCapability>,
        maxSamplePixels!: Int64 = 2097152,
        maxEffectsPerFrame!: Int64 = 8
    ) {
        if (providerId.isEmpty()) {
            throw IllegalArgumentException("renderer effect provider id must be present")
        }
        if (maxSamplePixels <= 0 || maxEffectsPerFrame <= 0) {
            throw IllegalArgumentException("renderer effect budgets must be positive")
        }
        this.providerId = providerId
        this.maxSamplePixels = maxSamplePixels
        this.maxEffectsPerFrame = maxEffectsPerFrame
        for (capability in capabilities) {
            if (has(capability)) {
                throw IllegalArgumentException(
                    "duplicate renderer effect capability: " + rendererEffectCapabilityName(capability))
            }
            values.add(capability)
        }
    }

    public func has(capability: RendererEffectCapability): Bool {
        for (value in values) {
            if (value == capability) { return true }
        }
        false
    }

    public func capabilityCount(): Int64 { values.size }
    public func capabilityAt(index: Int64): RendererEffectCapability { values[index] }
}

/** The live scene generation and geometry presented to one renderer-effect adapter. */
public struct RendererEffectFrame {
    public let generation: UInt64
    public let viewport: Rect
    public let scaleX: Float32
    public let scaleY: Float32

    public init(generation: UInt64, viewport: Rect, scaleX: Float32, scaleY: Float32) {
        this.generation = generation
        this.viewport = viewport
        this.scaleX = scaleX
        this.scaleY = scaleY
    }
}

/**
 * Bounded local lens optics for one backdrop request.
 *
 * A flat scalar `refraction` can only express a uniform shift; the reference material instead
 * bends structure locally and, in the lens window, magnifies/inverts content around an optical
 * centre. Carrying centre, radius and displacement strength here keeps that difference expressible
 * without letting a style package own any renderer fork.
 *
 * `centerX`/`centerY` are normalized to the resolved bounds (0..1); `radius` is a fraction of the
 * shorter resolved bounds edge. `sampleRadius` bounds how far a provider may read behind the shape.
 * All values are clamped, so an over-eager request degrades instead of escaping the surface.
 */
public struct BackdropLensOptics <: Equatable<BackdropLensOptics> {
    public let centerX: Float32
    public let centerY: Float32
    public let radius: Float32
    public let displacementStrength: Float32
    public let sampleRadius: Float32
    public let invertInsideLens: Bool

    public init(
        centerX!: Float32 = 0.5,
        centerY!: Float32 = 0.5,
        radius!: Float32 = 0.5,
        displacementStrength!: Float32 = 0.0,
        sampleRadius!: Float32 = 0.0,
        invertInsideLens!: Bool = false
    ) {
        this.centerX = max(0.0, min(1.0, centerX))
        this.centerY = max(0.0, min(1.0, centerY))
        this.radius = max(0.0, min(1.0, radius))
        this.displacementStrength = max(0.0, min(1.0, displacementStrength))
        this.sampleRadius = max(0.0, min(1.0, sampleRadius))
        this.invertInsideLens = invertInsideLens
    }

    /** A lens only exists when it can actually displace something. */
    public func active(): Bool {
        displacementStrength > 0.0 && radius > 0.0
    }

    public operator func ==(other: BackdropLensOptics): Bool {
        centerX == other.centerX && centerY == other.centerY && radius == other.radius &&
            displacementStrength == other.displacementStrength &&
            sampleRadius == other.sampleRadius && invertInsideLens == other.invertInsideLens
    }

    public operator func !=(other: BackdropLensOptics): Bool { !(this == other) }
}

/**
 * One bounded request for pixels already drawn behind a surface. `bounds` is the layout rectangle;
 * `transformedBounds`, when present, is the final axis-aligned coverage after a caller-owned
 * transform. A non-zero expected generation rejects stale retained requests.
 */
public class BackdropEffectRequest {
    public let bounds: Rect
    public let transformedBounds: ?Rect
    public let cornerRadius: Float32
    public let blurRadius: Float32
    public let refraction: Float32
    public let edgeResponse: Float32
    public let groupId: String
    public let requireShapeUnion: Bool
    public let expectedFrameGeneration: UInt64
    /** Local lens optics; inactive by default so existing uniform requests stay unchanged. */
    public let lens: BackdropLensOptics
    /** Edges energy already measured by the caller, used to gate transient chromatic response. */
    public let motionEnergy: Float32

    public init(
        bounds: Rect,
        transformedBounds!: ?Rect = None,
        cornerRadius!: Float32 = 0.0,
        blurRadius!: Float32 = 12.0,
        refraction!: Float32 = 0.25,
        edgeResponse!: Float32 = 0.5,
        groupId!: String = "",
        requireShapeUnion!: Bool = false,
        expectedFrameGeneration!: UInt64 = UInt64(0),
        lens!: BackdropLensOptics = BackdropLensOptics(),
        motionEnergy!: Float32 = 0.0
    ) {
        validateEffectRect(bounds, "backdrop bounds")
        match (transformedBounds) {
            case Some(value) => validateEffectRect(value, "backdrop transformed bounds")
            case None => ()
        }
        if (!effectFinite(cornerRadius) || !effectFinite(blurRadius) ||
            !effectFinite(refraction) || !effectFinite(edgeResponse)) {
            throw IllegalArgumentException("renderer effect values must be finite")
        }
        if (groupId.size > 128) {
            throw IllegalArgumentException("renderer effect group id must be at most 128 bytes")
        }
        this.bounds = bounds
        this.transformedBounds = transformedBounds
        this.cornerRadius = max(0.0, cornerRadius)
        this.blurRadius = max(0.0, min(48.0, blurRadius))
        this.refraction = max(0.0, min(1.0, refraction))
        this.edgeResponse = max(0.0, min(1.0, edgeResponse))
        this.groupId = groupId
        this.requireShapeUnion = requireShapeUnion
        this.expectedFrameGeneration = expectedFrameGeneration
        this.lens = lens
        this.motionEnergy = if (!effectFinite(motionEnergy)) {
            throw IllegalArgumentException("renderer effect motion energy must be finite")
        } else {
            max(0.0, min(1.0, motionEnergy))
        }
    }

    /** True when this request asks for a bounded local lens instead of a uniform shift. */
    public func hasActiveLens(): Bool { lens.active() }

    /** Chromatic separation is a transition-only response, never a settled decoration. */
    public func requestedChromaticEdge(): Float32 {
        if (!lens.active()) { return 0.0 }
        max(0.0, min(1.0, motionEnergy * lens.displacementStrength))
    }

    public func resolvedBounds(): Rect {
        match (transformedBounds) {
            case Some(value) => value
            case None => bounds
        }
    }
}

public enum RendererEffectStatus <: Equatable<RendererEffectStatus> {
    | Applied
    | Degraded
    | Unsupported
    | Rejected

    public operator func ==(other: RendererEffectStatus): Bool {
        rendererEffectStatusName(this) == rendererEffectStatusName(other)
    }

    public operator func !=(other: RendererEffectStatus): Bool { !(this == other) }
}

public func rendererEffectStatusName(status: RendererEffectStatus): String {
    match (status) {
        case RendererEffectStatus.Applied => "applied"
        case RendererEffectStatus.Degraded => "degraded"
        case RendererEffectStatus.Unsupported => "unsupported"
        case RendererEffectStatus.Rejected => "rejected"
    }
}

/** Machine-readable effect or lifecycle result; a non-applied paint result selects style fallback. */
public struct RendererEffectReceipt {
    public let status: RendererEffectStatus
    public let operation: String
    public let code: String
    public let providerId: String
    public let frameGeneration: UInt64
    public let sampledPixels: Int64
    public let effectIndex: Int64
    public let detail: String

    public init(
        status: RendererEffectStatus,
        operation: String,
        code: String,
        providerId!: String = "none",
        frameGeneration!: UInt64 = UInt64(0),
        sampledPixels!: Int64 = 0,
        effectIndex!: Int64 = 0,
        detail!: String = ""
    ) {
        if (operation.isEmpty() || code.isEmpty()) {
            throw IllegalArgumentException("renderer effect receipt operation and code must be present")
        }
        this.status = status
        this.operation = operation
        this.code = code
        this.providerId = providerId
        this.frameGeneration = frameGeneration
        this.sampledPixels = max(Int64(0), sampledPixels)
        this.effectIndex = max(Int64(0), effectIndex)
        this.detail = detail
    }

    public func applied(): Bool { status == RendererEffectStatus.Applied }
}

/** Host/provider seam. Backends own native handles; Surface and style packages own no renderer fork. */
public interface RendererEffectAdapter {
    func capabilities(): RendererEffectCapabilities
    func beginFrame(frame: RendererEffectFrame): Unit
    func apply(renderer: Renderer, frame: RendererEffectFrame, request: BackdropEffectRequest): RendererEffectReceipt
    func endFrame(frame: RendererEffectFrame): Unit
    func release(): RendererEffectReceipt
}

extend Renderer {
    /** Replaces the host effect adapter after releasing the previous one. */
    public func installEffectAdapter(adapter: RendererEffectAdapter): RendererEffectReceipt {
        let previous = match (rendererEffectAdapter) {
            case Some(value) =>
                try {
                    if (rendererEffectSceneOpen) { value.endFrame(rendererEffectFrame) }
                    value.release()
                } catch (error: Exception) {
                    RendererEffectReceipt(
                        RendererEffectStatus.Rejected, "release", "provider-failed",
                        providerId: value.capabilities().providerId,
                        frameGeneration: rendererEffectFrame.generation,
                        detail: error.message
                    )
                }
            case None => RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "release", "no-effect-adapter",
                frameGeneration: rendererEffectFrame.generation
            )
        }
        rendererEffectAdapter = Some(adapter)
        rendererEffectCount = 0
        if (rendererEffectSceneOpen) {
            try {
                adapter.beginFrame(rendererEffectFrame)
            } catch (error: Exception) {
                rendererEffectLastReceipt = Some(RendererEffectReceipt(
                    RendererEffectStatus.Rejected, "install", "begin-frame-failed",
                    providerId: adapter.capabilities().providerId,
                    frameGeneration: rendererEffectFrame.generation,
                    detail: error.message
                ))
                return rendererEffectLastReceipt.getOrThrow()
            }
        }
        rendererEffectLastReceipt = Some(RendererEffectReceipt(
            RendererEffectStatus.Applied, "install", "installed",
            providerId: adapter.capabilities().providerId,
            frameGeneration: rendererEffectFrame.generation
        ))
        match (previous.status) {
            case RendererEffectStatus.Rejected => previous
            case _ => rendererEffectLastReceipt.getOrThrow()
        }
    }

    /** Current provider capability snapshot, or `None` when effects are unavailable. */
    public func effectCapabilities(): ?RendererEffectCapabilities {
        match (rendererEffectAdapter) {
            case Some(value) => Some(value.capabilities())
            case None => None
        }
    }

    /** Current scene generation. Zero means no scene has begun yet. */
    public func effectFrameGeneration(): UInt64 { rendererEffectFrame.generation }

    /** Last adapter or fallback result for diagnostics and CUIC Draw IR. */
    public func lastEffectReceipt(): ?RendererEffectReceipt { rendererEffectLastReceipt }

    /** Attempts one bounded current-frame backdrop effect and never substitutes a hidden fallback. */
    public func applyBackdropEffect(request: BackdropEffectRequest): RendererEffectReceipt {
        let provider = match (rendererEffectAdapter) {
            case Some(value) => value
            case None => return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "no-effect-adapter",
                frameGeneration: rendererEffectFrame.generation,
                detail: "the renderer has no backdrop effect adapter"
            ), request)
        }
        let capabilities = provider.capabilities()
        if (!rendererEffectSceneOpen) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Rejected, "backdrop", "scene-not-open",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                detail: "backdrop effects are valid only between beginScene and endScene"
            ), request)
        }
        if (request.expectedFrameGeneration != UInt64(0) &&
            request.expectedFrameGeneration != rendererEffectFrame.generation) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Rejected, "backdrop", "stale-frame",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                detail: "the request targets an inactive scene generation"
            ), request)
        }
        if (!capabilities.has(RendererEffectCapability.BackdropSampling)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "backdrop-sampling-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation
            ), request)
        }
        if (request.blurRadius > 0.0 && !capabilities.has(RendererEffectCapability.Blur)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "blur-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation
            ), request)
        }
        if (request.refraction > 0.0 && !capabilities.has(RendererEffectCapability.Refraction)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "refraction-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation
            ), request)
        }
        // A local lens is a stronger claim than uniform refraction: a provider that cannot refract
        // would otherwise silently receive `hasActiveLens()` and ignore it.
        if (request.hasActiveLens() && !capabilities.has(RendererEffectCapability.Refraction)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Degraded, "backdrop", "lens-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                detail: "local lens displacement requires refraction capability; flat fallback selected"
            ), request)
        }
        if (request.edgeResponse > 0.0 && !capabilities.has(RendererEffectCapability.EdgeResponse)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "edge-response-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation
            ), request)
        }
        if (request.requireShapeUnion && !capabilities.has(RendererEffectCapability.ShapeUnion)) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "shape-union-unsupported",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                detail: "overlapping surfaces remain independent effect requests"
            ), request)
        }
        if (rendererEffectCount >= capabilities.maxEffectsPerFrame) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Degraded, "backdrop", "effect-budget-exceeded",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                effectIndex: rendererEffectCount,
                detail: "the per-frame effect count budget selected style fallback"
            ), request)
        }
        let resolved = request.resolvedBounds().intersection(rendererEffectFrame.viewport)
        if (resolved.w <= 0.0 || resolved.h <= 0.0) {
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Rejected, "backdrop", "outside-viewport",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation
            ), request)
        }
        // The lens sample radius is an additional read region and must widen the bounded sample,
        // otherwise a large lens could read far beyond the declared budget undetected.
        let lensMargin: Float32 = if (request.hasActiveLens()) {
            request.lens.sampleRadius * min(resolved.w, resolved.h)
        } else {
            0.0
        }
        let margin = request.blurRadius + request.refraction * 8.0 + lensMargin + 2.0
        let sampled = resolved.inset(-margin).intersection(rendererEffectFrame.viewport)
        let samplePixels = effectPixelRect(
            sampled, rendererEffectFrame.scaleX, rendererEffectFrame.scaleY)
        let pixels = Int64(samplePixels.w) * Int64(samplePixels.h)
        if (pixels > capabilities.maxSamplePixels) {
            // A large surface (notably a full-screen glass container) exceeds a single readback
            // budget on its own: its *visible* area alone is over the cap, so shrinking blur or
            // refraction cannot help. The honest fix is to sample it in horizontal bands, each
            // within budget, so the material still appears instead of silently vanishing.
            let bands = effectBandCount(resolved, rendererEffectFrame, capabilities)
            if (bands > 1) {
                var applied: Int64 = 0
                var degraded: ?RendererEffectReceipt = None
                var bandIndex: Int64 = 0
                let bandH = resolved.h / Float32(bands)
                while (bandIndex < bands) {
                    let band = Rect(resolved.x, resolved.y + Float32(bandIndex) * bandH,
                        resolved.w, bandH)
                    let bandMargin = request.blurRadius + request.refraction * 8.0 +
                        (if (request.hasActiveLens()) {
                            request.lens.sampleRadius * min(band.w, band.h)
                        } else {
                            0.0
                        }) + 2.0
                    let bandRect = effectPixelRect(
                        band.inset(-bandMargin).intersection(rendererEffectFrame.viewport),
                        rendererEffectFrame.scaleX, rendererEffectFrame.scaleY)
                    let bandPixels = Int64(bandRect.w) * Int64(bandRect.h)
                    if (bandPixels <= capabilities.maxSamplePixels) {
                        rendererEffectCount += 1
                        let bandReceipt = try {
                            provider.apply(this, rendererEffectFrame,
                                BackdropEffectRequest(
                                    band,
                                    cornerRadius: request.cornerRadius,
                                    blurRadius: request.blurRadius,
                                    refraction: request.refraction,
                                    edgeResponse: request.edgeResponse,
                                    expectedFrameGeneration: request.expectedFrameGeneration,
                                    requireShapeUnion: request.requireShapeUnion,
                                    lens: request.lens,
                                    motionEnergy: request.motionEnergy))
                        } catch (error: Exception) {
                            RendererEffectReceipt(
                                RendererEffectStatus.Degraded, "backdrop", "provider-failed",
                                providerId: capabilities.providerId,
                                frameGeneration: rendererEffectFrame.generation,
                                detail: error.message)
                        }
                        match (bandReceipt.status) {
                            case RendererEffectStatus.Applied => applied += 1
                            case _ =>
                                if (degraded.isNone()) { degraded = Some(bandReceipt) }
                        }
                    } else if (degraded.isNone()) {
                        degraded = Some(RendererEffectReceipt(
                            RendererEffectStatus.Degraded, "backdrop", "sample-budget-exceeded",
                            providerId: capabilities.providerId,
                            frameGeneration: rendererEffectFrame.generation,
                            sampledPixels: bandPixels,
                            detail: "bounded native readback would exceed the provider pixel budget"
                        ))
                    }
                    bandIndex += 1
                }
                let finalReceipt = match (degraded) {
                    case Some(value) => value
                    case None => RendererEffectReceipt(
                        RendererEffectStatus.Applied, "backdrop", "applied-banded",
                        providerId: capabilities.providerId,
                        frameGeneration: rendererEffectFrame.generation,
                        sampledPixels: pixels,
                        detail: "surface sampled in " + bands.toString() +
                            " bounded bands (" + applied.toString() + " applied)"
                    )
                }
                return rememberEffectReceipt(finalReceipt, request)
            }
            return rememberEffectReceipt(RendererEffectReceipt(
                RendererEffectStatus.Degraded, "backdrop", "sample-budget-exceeded",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                sampledPixels: pixels,
                effectIndex: rendererEffectCount,
                detail: "bounded native readback would exceed the provider pixel budget"
            ), request)
        }
        rendererEffectCount += 1
        let providerReceipt = try {
            provider.apply(this, rendererEffectFrame, request)
        } catch (error: Exception) {
            RendererEffectReceipt(
                RendererEffectStatus.Degraded, "backdrop", "provider-failed",
                providerId: capabilities.providerId,
                frameGeneration: rendererEffectFrame.generation,
                sampledPixels: pixels,
                effectIndex: rendererEffectCount,
                detail: error.message
            )
        }
        let receipt = RendererEffectReceipt(
            providerReceipt.status,
            providerReceipt.operation,
            providerReceipt.code,
            providerId: providerReceipt.providerId,
            frameGeneration: rendererEffectFrame.generation,
            sampledPixels: if (providerReceipt.sampledPixels > 0) {
                providerReceipt.sampledPixels
            } else {
                pixels
            },
            effectIndex: if (providerReceipt.effectIndex > 0) {
                providerReceipt.effectIndex
            } else {
                rendererEffectCount
            },
            detail: providerReceipt.detail
        )
        rememberEffectReceipt(receipt, request)
    }

    private func rememberEffectReceipt(
        receipt: RendererEffectReceipt,
        request: BackdropEffectRequest
    ): RendererEffectReceipt {
        rendererEffectLastReceipt = Some(receipt)
        recordDrawIr("effect.backdrop", "\"status\":" +
            drawIrQuote(rendererEffectStatusName(receipt.status)) + ",\"code\":" +
            drawIrQuote(receipt.code) + ",\"provider\":" + drawIrQuote(receipt.providerId) +
            ",\"frameGeneration\":" + receipt.frameGeneration.toString() +
            ",\"sampledPixels\":" + receipt.sampledPixels.toString() +
            ",\"effectIndex\":" + receipt.effectIndex.toString() + "," +
            drawIrRect(request.resolvedBounds()) + ",\"groupId\":" + drawIrQuote(request.groupId))
        receipt
    }
}

/** First native implementation: bounded synchronous SDL readback with a strict per-frame budget. */
internal class SdlReadbackRendererEffectAdapter <: RendererEffectAdapter {
    private let offered = RendererEffectCapabilities(
        "sdl-readback",
        [
            RendererEffectCapability.BackdropSampling,
            RendererEffectCapability.Blur,
            RendererEffectCapability.Refraction,
            RendererEffectCapability.EdgeResponse
        ],
        maxSamplePixels: 2097152,
        maxEffectsPerFrame: 8
    )
    private var activeGeneration: UInt64 = UInt64(0)
    private var released = false

    public func capabilities(): RendererEffectCapabilities { offered }

    public func beginFrame(frame: RendererEffectFrame): Unit {
        if (released) { throw CuiException("renderer effect adapter is released") }
        activeGeneration = frame.generation
    }

    public func apply(
        renderer: Renderer,
        frame: RendererEffectFrame,
        request: BackdropEffectRequest
    ): RendererEffectReceipt {
        if (released || activeGeneration != frame.generation) {
            return RendererEffectReceipt(
                RendererEffectStatus.Rejected, "backdrop", "stale-adapter-frame",
                providerId: offered.providerId,
                frameGeneration: frame.generation
            )
        }
        if (renderer.ptr.isNull()) {
            return RendererEffectReceipt(
                RendererEffectStatus.Unsupported, "backdrop", "headless-renderer",
                providerId: offered.providerId,
                frameGeneration: frame.generation
            )
        }
        let visible = request.resolvedBounds().intersection(frame.viewport)
        let margin = request.blurRadius + request.refraction * 8.0 + 2.0
        let capture = visible.inset(-margin).intersection(frame.viewport)
        var raw = effectPixelRect(capture, frame.scaleX, frame.scaleY)
        let sampledPixels = Int64(raw.w) * Int64(raw.h)
        let rawSurface = unsafe { SDL_RenderReadPixels(renderer.ptr, inout raw) }
        if (rawSurface.isNull()) {
            throw CuiException("SDL_RenderReadPixels failed: ${lastSdlError()}")
        }
        var texture: ?Texture = None
        try (surface = Surface(rawSurface)) {
            texture = Some(renderer.textureFromSurface(surface))
        }
        let sampledTexture = texture.getOrThrow()
        try {
            paintSdlBackdrop(renderer, sampledTexture, frame, request, capture, visible)
        } finally {
            sampledTexture.close()
        }
        RendererEffectReceipt(
            RendererEffectStatus.Applied, "backdrop", "applied",
            providerId: offered.providerId,
            frameGeneration: frame.generation,
            sampledPixels: sampledPixels,
            detail: "bounded synchronous SDL readback on " + renderer.driverName()
        )
    }

    public func endFrame(frame: RendererEffectFrame): Unit {
        if (activeGeneration == frame.generation) { activeGeneration = UInt64(0) }
    }

    public func release(): RendererEffectReceipt {
        if (released) {
            return RendererEffectReceipt(
                RendererEffectStatus.Degraded, "release", "already-released",
                providerId: offered.providerId,
                frameGeneration: activeGeneration
            )
        }
        let generation = activeGeneration
        activeGeneration = UInt64(0)
        released = true
        RendererEffectReceipt(
            RendererEffectStatus.Applied, "release", "released",
            providerId: offered.providerId,
            frameGeneration: generation,
            detail: "the readback adapter retains no cross-frame native texture"
        )
    }
}

private func paintSdlBackdrop(
    renderer: Renderer,
    texture: Texture,
    frame: RendererEffectFrame,
    request: BackdropEffectRequest,
    capture: Rect,
    visible: Rect
): Unit {
    let localX = (visible.x - capture.x) * frame.scaleX
    let localY = (visible.y - capture.y) * frame.scaleY
    let localW = visible.w * frame.scaleX
    let localH = visible.h * frame.scaleY
    let lensInsetX = min(localW * 0.08, request.refraction * 4.0 * frame.scaleX)
    let lensInsetY = min(localH * 0.08, request.refraction * 3.0 * frame.scaleY)
    let source = Rect(
        localX + lensInsetX,
        localY + lensInsetY,
        max(1.0, localW - lensInsetX * 2.0),
        max(1.0, localH - lensInsetY * 2.0)
    )
    renderer.pushClip(visible)
    try {
        texture.setBlendMode(TextureBlendMode.None)
        texture.setAlpha(255)
        if (request.hasActiveLens()) {
            // A uniform blit cannot bend a structural line: it only translates/scales the whole
            // sample. The reference material displaces content *locally* around an optical centre,
            // so the backdrop is composited as a grid of cells whose source rect is offset by a
            // radial displacement field. Clipping to the shape keeps the field from escaping.
            paintLensedBackdrop(renderer, texture, frame, request, source, visible)
        } else {
            renderer.texture(texture, visible, source: Some(source))
        }
        if (request.blurRadius > 0.0) {
            texture.setBlendMode(TextureBlendMode.Blend)
            texture.setAlpha(Int64(18.0 + request.edgeResponse * 18.0))
            let stepX = min(3.0, request.blurRadius * 0.18) * frame.scaleX
            let stepY = min(3.0, request.blurRadius * 0.18) * frame.scaleY
            renderer.texture(texture, visible, source: Some(source.shift(-stepX, 0.0)))
            renderer.texture(texture, visible, source: Some(source.shift(stepX, 0.0)))
            renderer.texture(texture, visible, source: Some(source.shift(0.0, -stepY)))
            renderer.texture(texture, visible, source: Some(source.shift(0.0, stepY)))
        }
    } finally {
        renderer.popClip()
    }
}

/**
 * Local displacement field. The optical centre is normalized inside `visible`; every grid cell
 * samples the backdrop from a position pushed along the radial direction. Strength grows toward the
 * lens edge (spherical magnification) and falls to zero at the lens rim, so the displacement is
 * strictly local and cannot leak past the surface.
 *
 * The cell grid is bounded: at most LENS_GRID x LENS_GRID quads, which keeps the synchronous
 * readback path within its per-frame budget instead of issuing one draw per pixel.
 */
private let LENS_GRID: Int64 = 12

private func lensDisplacementAt(dx: Float32, dy: Float32, radius: Float32,
    strength: Float32): Float32 {
    if (radius <= 0.0) { return 0.0 }
    let dist = effectSqrt(dx * dx + dy * dy)
    if (dist > radius) { return 0.0 }
    // Normalized distance 0 at centre, 1 at rim. A convex lens bends hardest near the rim and
    // keeps a gentler, near-flat window in the middle, which is what reads as magnification.
    let t = dist / radius
    strength * t * (1.0 - t) * 4.0
}

private func paintLensedBackdrop(
    renderer: Renderer,
    texture: Texture,
    frame: RendererEffectFrame,
    request: BackdropEffectRequest,
    source: Rect,
    visible: Rect
): Unit {
    let lens = request.lens
    let cells = max(Int64(2), min(Int64(24), LENS_GRID))
    // Destination cells live in screen space; source cells live in texture space. Mixing the two
    // is what previously turned the lens into a uniform blit offset instead of a local bend.
    let cellScreenW = visible.w / Float32(cells)
    let cellScreenH = visible.h / Float32(cells)
    let srcCellW = source.w / Float32(cells)
    let srcCellH = source.h / Float32(cells)
    let shorterScreen = min(visible.w, visible.h)
    let lensRadius = max(1.0, shorterScreen * lens.radius)
    let centerX = visible.x + visible.w * lens.centerX
    let centerY = visible.y + visible.h * lens.centerY
    let strength = lens.displacementStrength * shorterScreen * 0.11
    let sign: Float32 = if (lens.invertInsideLens) { -1.0 } else { 1.0 }
    var row: Int64 = 0
    while (row < cells) {
        var col: Int64 = 0
        while (col < cells) {
            let destX = visible.x + Float32(col) * cellScreenW
            let destY = visible.y + Float32(row) * cellScreenH
            let srcX = source.x + Float32(col) * srcCellW
            let srcY = source.y + Float32(row) * srcCellH
            var sampleX = srcX
            var sampleY = srcY
            // Displace around the optical centre so samples converge toward the middle of the lens.
            let dx = (destX + cellScreenW * 0.5) - centerX
            let dy = (destY + cellScreenH * 0.5) - centerY
            let push = lensDisplacementAt(dx, dy, lensRadius, strength)
            if (push > 0.0) {
                let len = effectSqrt(dx * dx + dy * dy)
                if (len > 0.0) {
                    sampleX = srcX + dx / len * push * frame.scaleX * sign
                    sampleY = srcY + dy / len * push * frame.scaleY * sign
                }
            }
            let clampedX = max(source.x, min(source.x + source.w - srcCellW, sampleX))
            let clampedY = max(source.y, min(source.y + source.h - srcCellH, sampleY))
            renderer.texture(texture, Rect(destX, destY, cellScreenW, cellScreenH),
                source: Some(Rect(clampedX, clampedY, srcCellW, srcCellH)))
            col += 1
        }
        row += 1
    }
}

/**
 * How many horizontal bands a surface must be split into so every readback stays inside the
 * provider pixel budget. Returns 1 when the surface already fits.
 */
private func effectBandCount(rect: Rect, frame: RendererEffectFrame,
    capabilities: RendererEffectCapabilities): Int64 {
    if (capabilities.maxSamplePixels <= 0) { return 1 }
    var bands: Int64 = 1
    var attempt: Int64 = 0
    while (attempt < 8) {
        let bandH = rect.h / Float32(bands)
        let band = Rect(rect.x, rect.y, rect.w, bandH)
        let px = effectPixelRect(band, frame.scaleX, frame.scaleY)
        let pixels = Int64(px.w) * Int64(px.h)
        if (pixels <= capabilities.maxSamplePixels) { return bands }
        bands += 1
        attempt += 1
    }
    bands
}

private func clamp01(value: Float32): Float32 {
    if (value < 0.0) { return 0.0 }
    if (value > 1.0) { return 1.0 }
    value
}

private func effectSqrt(value: Float32): Float32 {
    if (value <= 0.0) { return 0.0 }
    // Newton iterations are enough for a displacement field and avoid depending on std.math here.
    let half: Float32 = 0.5
    let one: Float32 = 1.0
    var x: Float32 = if (value > one) { value * half } else { one }
    var i: Int64 = 0
    while (i < 18) {
        x = half * (x + value / x)
        i += 1
    }
    x
}

private func effectPixelRect(rect: Rect, scaleX: Float32, scaleY: Float32): SdlRect {
    var raw = SdlRect()
    raw.x = Int32(max(0.0, rect.x * scaleX))
    raw.y = Int32(max(0.0, rect.y * scaleY))
    let right = Int32(max(Float32(raw.x + 1), rect.right() * scaleX + 0.999))
    let bottom = Int32(max(Float32(raw.y + 1), rect.bottom() * scaleY + 0.999))
    raw.w = max(Int32(1), right - raw.x)
    raw.h = max(Int32(1), bottom - raw.y)
    raw
}

private func validateEffectRect(rect: Rect, label: String): Unit {
    if (!effectFinite(rect.x) || !effectFinite(rect.y) ||
        !effectFinite(rect.w) || !effectFinite(rect.h) || rect.w <= 0.0 || rect.h <= 0.0) {
        throw IllegalArgumentException(label + " must be finite with positive size")
    }
}

private func effectFinite(value: Float32): Bool { value - value == 0.0 }
