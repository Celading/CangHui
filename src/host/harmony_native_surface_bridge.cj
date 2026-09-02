package chui.host

import chui.core.PointerInputBridge
import sdl.{InputCoordinateSpace, InputTransform, PointerDeviceKind, PointerEvent, PointerPhase, UiEvent}
import std.sync.Mutex

private let HARMONY_BRIDGE_ACCEPTED: Int64 = 0
private let HARMONY_BRIDGE_INVALID_ARGUMENT: Int64 = -1
private let HARMONY_BRIDGE_STALE_GENERATION: Int64 = -2
private let HARMONY_BRIDGE_REJECTED: Int64 = -3
private let HARMONY_MAX_SURFACE_DIMENSION: Int64 = 65535
private let HARMONY_MIN_SCALE_MILLI: Int64 = 100
private let HARMONY_MAX_SCALE_MILLI: Int64 = 16000

/** Immutable integer-only snapshot shared with the Harmony XComponent host adapter. */
public struct HarmonyNativeSurfaceSnapshot {
    public let attached: Bool
    public let handle: Int64
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scaleMilli: Int64
    public let generation: Int64
    public let surfaceRevision: Int64
    public let frameId: Int64
    public let timestampNanos: Int64
    public let targetTimestampNanos: Int64

    public init(
        attached: Bool,
        handle: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64,
        surfaceRevision: Int64,
        frameId: Int64,
        timestampNanos: Int64,
        targetTimestampNanos: Int64
    ) {
        this.attached = attached
        this.handle = handle
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.scaleMilli = scaleMilli
        this.generation = generation
        this.surfaceRevision = surfaceRevision
        this.frameId = frameId
        this.timestampNanos = timestampNanos
        this.targetTimestampNanos = targetTimestampNanos
    }
}

/**
 * Harmony XComponent ingress. Native callbacks commit only mutex-protected,
 * integer facts; the Scene3D host applies them later on CangHui's UI owner.
 */
public class HarmonyNativeSurfaceBridge {
    private let stateMutex = Mutex()
    private let pointerBridge = PointerInputBridge()
    private var attached = false
    private var handle: Int64 = 0
    private var pixelWidth: Int64 = 0
    private var pixelHeight: Int64 = 0
    private var scaleMilli: Int64 = 1000
    private var generation: Int64 = 0
    private var surfaceRevision: Int64 = 0
    private var frameId: Int64 = -1
    private var timestampNanos: Int64 = 0
    private var targetTimestampNanos: Int64 = 0
    private var attachCount: Int64 = 0
    private var resizeCount: Int64 = 0
    private var detachCount: Int64 = 0
    private var frameCount: Int64 = 0
    private var orientationRevision: Int64 = 0

    public func attach(
        handle: Int64,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (handle <= 0 || !validDimensions(pixelWidth, pixelHeight, scaleMilli) || generation <= 0) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (generation <= this.generation) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.attached = true
            this.handle = handle
            this.pixelWidth = pixelWidth
            this.pixelHeight = pixelHeight
            this.scaleMilli = scaleMilli
            this.generation = generation
            this.surfaceRevision += 1
            this.frameId = -1
            this.orientationRevision = 0
            this.timestampNanos = 0
            this.targetTimestampNanos = 0
            this.attachCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func resize(
        pixelWidth: Int64,
        pixelHeight: Int64,
        scaleMilli: Int64,
        generation: Int64
    ): Int64 {
        if (!validDimensions(pixelWidth, pixelHeight, scaleMilli)) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.pixelWidth = pixelWidth
            this.pixelHeight = pixelHeight
            this.scaleMilli = scaleMilli
            this.surfaceRevision += 1
            this.resizeCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func detach(generation: Int64): Int64 {
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            this.attached = false
            this.handle = 0
            this.pixelWidth = 0
            this.pixelHeight = 0
            this.surfaceRevision += 1
            this.detachCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func frame(
        timestampNanos: Int64,
        targetTimestampNanos: Int64,
        generation: Int64
    ): Int64 {
        if (timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            if ((frameId >= 0 && timestampNanos < this.timestampNanos) || frameId == Int64.Max) {
                return HARMONY_BRIDGE_INVALID_ARGUMENT
            }
            this.frameId += 1
            this.timestampNanos = timestampNanos
            this.targetTimestampNanos = targetTimestampNanos
            this.frameCount += 1
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    /**
     * Rich Harmony pointer ingress. Coordinates are milli-units in the declared capture space;
     * capture-time scale/revision facts prevent a monitor/rotation change from corrupting hit tests.
     */
    public func pointer(
        phase: Int64,
        kind: Int64,
        pointerId: Int64,
        sourceDeviceId: Int64,
        xMilli: Int64,
        yMilli: Int64,
        coordinateSpace: Int64,
        buttons: Int64,
        pressureMilli: Int64,
        contactWidthMilli: Int64,
        contactHeightMilli: Int64,
        tiltXMilli: Int64,
        tiltYMilli: Int64,
        timestampNanos: Int64,
        capturedScaleMilli: Int64,
        transformRevision: Int64,
        pointerOrientationRevision: Int64,
        generation: Int64
    ): Int64 {
        if (phase < 0 || phase > 3 || kind < 0 || kind > 2 || pointerId < 0 || sourceDeviceId < 0 ||
            coordinateSpace < 0 || coordinateSpace > 1 || buttons < 0 || pressureMilli < -1000 ||
            pressureMilli > 1000 || contactWidthMilli < 0 || contactHeightMilli < 0 || timestampNanos < 0 ||
            capturedScaleMilli <= 0 || transformRevision <= 0 || pointerOrientationRevision < 0) {
            return HARMONY_BRIDGE_INVALID_ARGUMENT
        }
        let transform = synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) {
                None<InputTransform>
            } else {
                Some(InputTransform(Float32(scaleMilli) / 1000.0, UInt64(surfaceRevision),
                    orientationRevision: UInt64(orientationRevision),
                    surfaceGeneration: UInt64(generation)))
            }
        }
        let current = match (transform) {
            case Some(value) => value
            case None => return HARMONY_BRIDGE_STALE_GENERATION
        }
        let packet = PointerEvent(
            pointerPhaseFromCode(phase), pointerKindFromCode(kind), UInt64(pointerId),
            Float32(xMilli) / 1000.0, Float32(yMilli) / 1000.0,
            coordinateSpace: if (coordinateSpace == 0) {
                InputCoordinateSpace.LogicalViewport
            } else {
                InputCoordinateSpace.SurfacePixel
            },
            sourceDeviceId: UInt64(sourceDeviceId),
            buttons: UInt64(buttons),
            pressure: Float32(pressureMilli) / 1000.0,
            contactWidth: Float32(contactWidthMilli) / 1000.0,
            contactHeight: Float32(contactHeightMilli) / 1000.0,
            tiltX: Float32(tiltXMilli) / 1000.0,
            tiltY: Float32(tiltYMilli) / 1000.0,
            timestampNs: UInt64(timestampNanos),
            capturedDisplayScale: Float32(capturedScaleMilli) / 1000.0,
            transformRevision: UInt64(transformRevision),
            orientationRevision: UInt64(pointerOrientationRevision),
            surfaceGeneration: UInt64(generation))
        let receipt = pointerBridge.push(packet, current)
        if (receipt.accepted()) { HARMONY_BRIDGE_ACCEPTED } else { HARMONY_BRIDGE_REJECTED }
    }

    /** Commits the host's newest orientation transform before samples in that space are accepted. */
    public func updateOrientationRevision(revision: Int64, generation: Int64): Int64 {
        if (revision < 0) { return HARMONY_BRIDGE_INVALID_ARGUMENT }
        synchronized(stateMutex) {
            if (!matchesAttachedGeneration(generation)) { return HARMONY_BRIDGE_STALE_GENERATION }
            if (revision < orientationRevision) { return HARMONY_BRIDGE_REJECTED }
            if (revision > orientationRevision) {
                orientationRevision = revision
                surfaceRevision += 1
            }
            HARMONY_BRIDGE_ACCEPTED
        }
    }

    public func drainPointerEvents(): Array<UiEvent> { pointerBridge.drain() }

    public func snapshot(): HarmonyNativeSurfaceSnapshot {
        synchronized(stateMutex) {
            HarmonyNativeSurfaceSnapshot(
                attached, handle, pixelWidth, pixelHeight, scaleMilli, generation,
                surfaceRevision, frameId, timestampNanos, targetTimestampNanos
            )
        }
    }

    public func totalAttachCount(): Int64 { synchronized(stateMutex) { attachCount } }
    public func totalResizeCount(): Int64 { synchronized(stateMutex) { resizeCount } }
    public func totalDetachCount(): Int64 { synchronized(stateMutex) { detachCount } }
    public func totalFrameCount(): Int64 { synchronized(stateMutex) { frameCount } }

    private func validDimensions(width: Int64, height: Int64, scaleMilli: Int64): Bool {
        width > 0 && width <= HARMONY_MAX_SURFACE_DIMENSION &&
            height > 0 && height <= HARMONY_MAX_SURFACE_DIMENSION &&
            scaleMilli >= HARMONY_MIN_SCALE_MILLI && scaleMilli <= HARMONY_MAX_SCALE_MILLI
    }

    private func matchesAttachedGeneration(generation: Int64): Bool {
        attached && generation > 0 && this.generation == generation
    }
}

private func pointerPhaseFromCode(code: Int64): PointerPhase {
    if (code == 0) { PointerPhase.Down }
    else if (code == 1) { PointerPhase.Move }
    else if (code == 2) { PointerPhase.Up }
    else { PointerPhase.Cancel }
}

private func pointerKindFromCode(code: Int64): PointerDeviceKind {
    if (code == 0) { PointerDeviceKind.Mouse }
    else if (code == 1) { PointerDeviceKind.Touch }
    else { PointerDeviceKind.Pen }
}

private let sharedHarmonyNativeSurfaceBridge = HarmonyNativeSurfaceBridge()

/** Shared bridge consumed by the native ABI and the public Scene3D host. */
public func harmonyNativeSurfaceBridge(): HarmonyNativeSurfaceBridge {
    sharedHarmonyNativeSurfaceBridge
}

/** Integer ABI v1. Native pointers never enter serializable CangHui receipts. */
@C public func canghui_harmony_xcomponent_host_abi_version(): Int64 { 1 }

@C
public func canghui_harmony_surface_attach(
    handle: Int64,
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.attach(handle, pixelWidth, pixelHeight, scaleMilli, generation)
}

@C
public func canghui_harmony_surface_resize(
    pixelWidth: Int64,
    pixelHeight: Int64,
    scaleMilli: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.resize(pixelWidth, pixelHeight, scaleMilli, generation)
}

@C public func canghui_harmony_surface_detach(generation: Int64): Int64 {
    sharedHarmonyNativeSurfaceBridge.detach(generation)
}

@C
public func canghui_harmony_surface_frame(
    timestampNanos: Int64,
    targetTimestampNanos: Int64,
    generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.frame(timestampNanos, targetTimestampNanos, generation)
}

@C
public func canghui_harmony_pointer_v2(
    phase: Int64, kind: Int64, pointerId: Int64, sourceDeviceId: Int64,
    xMilli: Int64, yMilli: Int64, coordinateSpace: Int64, buttons: Int64,
    pressureMilli: Int64, contactWidthMilli: Int64, contactHeightMilli: Int64,
    tiltXMilli: Int64, tiltYMilli: Int64, timestampNanos: Int64,
    capturedScaleMilli: Int64, transformRevision: Int64,
    orientationRevision: Int64, generation: Int64
): Int64 {
    sharedHarmonyNativeSurfaceBridge.pointer(
        phase, kind, pointerId, sourceDeviceId, xMilli, yMilli, coordinateSpace, buttons,
        pressureMilli, contactWidthMilli, contactHeightMilli, tiltXMilli, tiltYMilli,
        timestampNanos, capturedScaleMilli, transformRevision, orientationRevision, generation)
}

@C
public func canghui_harmony_orientation_revision(revision: Int64, generation: Int64): Int64 {
    sharedHarmonyNativeSurfaceBridge.updateOrientationRevision(revision, generation)
}
