package sdl

/** Coordinate space in which a platform captured a pointer sample. */
public enum InputCoordinateSpace {
    | LogicalViewport
    | WindowPixel
    | SurfacePixel
    | ScreenPixel
}

/** Portable physical source. Platform-specific tool types remain provider metadata. */
public enum PointerDeviceKind {
    | Mouse
    | Touch
    | Pen
    | Unknown
}

public enum PointerPhase {
    | Down
    | Move
    | Up
    | Cancel
}

/**
 * Versioned transform used at the only physical-to-logical input boundary.
 * Layout and hit testing always consume logical viewport coordinates.
 */
public struct InputTransform {
    public let displayScale: Float32
    public let revision: UInt64
    public let orientationRevision: UInt64
    public let surfaceGeneration: UInt64

    public init(
        displayScale: Float32,
        revision: UInt64,
        orientationRevision!: UInt64 = UInt64(0),
        surfaceGeneration!: UInt64 = UInt64(0)
    ) {
        if (displayScale <= 0.0) {
            throw IllegalArgumentException("input display scale must be greater than zero")
        }
        if (revision == UInt64(0)) {
            throw IllegalArgumentException("input transform revision must be non-zero")
        }
        this.displayScale = displayScale
        this.revision = revision
        this.orientationRevision = orientationRevision
        this.surfaceGeneration = surfaceGeneration
    }
}

/** Exact logical/backing geometry after one atomic scale transaction. */
public struct WindowMetrics {
    public let logicalWidth: Int32
    public let logicalHeight: Int32
    public let pixelWidth: Int32
    public let pixelHeight: Int32
    public let displayScale: Float32
    public let transformRevision: UInt64

    public init(
        logicalWidth: Int32,
        logicalHeight: Int32,
        pixelWidth: Int32,
        pixelHeight: Int32,
        displayScale: Float32,
        transformRevision: UInt64
    ) {
        if (logicalWidth < 0 || logicalHeight < 0 || pixelWidth < 0 || pixelHeight < 0) {
            throw IllegalArgumentException("window metrics dimensions must not be negative")
        }
        if (displayScale <= 0.0 || transformRevision == UInt64(0)) {
            throw IllegalArgumentException("window metrics require a positive scale and revision")
        }
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.displayScale = displayScale
        this.transformRevision = transformRevision
    }

    public func inputTransform(): InputTransform {
        InputTransform(displayScale, transformRevision)
    }
}

/** Rich provider input retained until the compatibility edge lowers it to mouse-shaped events. */
public struct PointerEvent {
    public let phase: PointerPhase
    public let device: PointerDeviceKind
    public let pointerId: UInt64
    public let sourceDeviceId: UInt64
    public let originalX: Float32
    public let originalY: Float32
    public let x: Float32
    public let y: Float32
    public let coordinateSpace: InputCoordinateSpace
    public let buttons: UInt64
    public let pressure: Float32
    public let contactWidth: Float32
    public let contactHeight: Float32
    public let tiltX: Float32
    public let tiltY: Float32
    public let timestampNs: UInt64
    public let capturedDisplayScale: Float32
    public let transformRevision: UInt64
    public let orientationRevision: UInt64
    public let surfaceGeneration: UInt64

    public init(
        phase: PointerPhase,
        device: PointerDeviceKind,
        pointerId: UInt64,
        x: Float32,
        y: Float32,
        coordinateSpace!: InputCoordinateSpace = InputCoordinateSpace.LogicalViewport,
        sourceDeviceId!: UInt64 = UInt64(0),
        buttons!: UInt64 = UInt64(0),
        pressure!: Float32 = -1.0,
        contactWidth!: Float32 = 0.0,
        contactHeight!: Float32 = 0.0,
        tiltX!: Float32 = 0.0,
        tiltY!: Float32 = 0.0,
        timestampNs!: UInt64 = UInt64(0),
        capturedDisplayScale!: Float32 = 1.0,
        transformRevision!: UInt64 = UInt64(1),
        orientationRevision!: UInt64 = UInt64(0),
        surfaceGeneration!: UInt64 = UInt64(0),
        logicalX!: ?Float32 = None,
        logicalY!: ?Float32 = None
    ) {
        if (capturedDisplayScale <= 0.0 || transformRevision == UInt64(0)) {
            throw IllegalArgumentException("pointer input requires a positive captured scale and revision")
        }
        if (pressure < -1.0 || pressure > 1.0 || contactWidth < 0.0 || contactHeight < 0.0) {
            throw IllegalArgumentException("pointer pressure/contact metadata is outside its portable range")
        }
        this.phase = phase
        this.device = device
        this.pointerId = pointerId
        this.sourceDeviceId = sourceDeviceId
        this.originalX = x
        this.originalY = y
        this.x = match (logicalX) { case Some(value) => value case None => x }
        this.y = match (logicalY) { case Some(value) => value case None => y }
        this.coordinateSpace = coordinateSpace
        this.buttons = buttons
        this.pressure = pressure
        this.contactWidth = contactWidth
        this.contactHeight = contactHeight
        this.tiltX = tiltX
        this.tiltY = tiltY
        this.timestampNs = timestampNs
        this.capturedDisplayScale = capturedDisplayScale
        this.transformRevision = transformRevision
        this.orientationRevision = orientationRevision
        this.surfaceGeneration = surfaceGeneration
    }
}

public enum PointerNormalizationDisposition {
    | Accepted
    | Reprojected
    | Rejected
}

/** Explicit result; stale samples are never silently interpreted with the newest scale. */
public struct PointerNormalizationReceipt {
    public let disposition: PointerNormalizationDisposition
    public let code: String
    public let event: ?PointerEvent

    public init(
        disposition: PointerNormalizationDisposition,
        code: String,
        event!: ?PointerEvent = None
    ) {
        this.disposition = disposition
        this.code = code
        this.event = event
    }

    public func accepted(): Bool {
        match (disposition) {
            case PointerNormalizationDisposition.Accepted => true
            case PointerNormalizationDisposition.Reprojected => true
            case PointerNormalizationDisposition.Rejected => false
        }
    }
}

/** Normalize once using capture-time facts; screen coordinates require a provider-owned window origin. */
public func normalizePointerEvent(
    event: PointerEvent,
    current: InputTransform
): PointerNormalizationReceipt {
    if (event.surfaceGeneration != UInt64(0) && current.surfaceGeneration != UInt64(0) &&
        event.surfaceGeneration != current.surfaceGeneration) {
        return PointerNormalizationReceipt(PointerNormalizationDisposition.Rejected,
            "stale-surface-generation")
    }
    if (event.orientationRevision != current.orientationRevision) {
        return PointerNormalizationReceipt(PointerNormalizationDisposition.Rejected,
            "stale-orientation-transform")
    }
    var logicalX = event.originalX
    var logicalY = event.originalY
    match (event.coordinateSpace) {
        case InputCoordinateSpace.LogicalViewport => ()
        case InputCoordinateSpace.WindowPixel =>
            logicalX = logicalX / event.capturedDisplayScale
            logicalY = logicalY / event.capturedDisplayScale
        case InputCoordinateSpace.SurfacePixel =>
            logicalX = logicalX / event.capturedDisplayScale
            logicalY = logicalY / event.capturedDisplayScale
        case InputCoordinateSpace.ScreenPixel =>
            return PointerNormalizationReceipt(PointerNormalizationDisposition.Rejected,
                "screen-origin-required")
    }
    let normalized = PointerEvent(
        event.phase, event.device, event.pointerId, event.originalX, event.originalY,
        coordinateSpace: event.coordinateSpace,
        sourceDeviceId: event.sourceDeviceId,
        buttons: event.buttons,
        pressure: event.pressure,
        contactWidth: event.contactWidth,
        contactHeight: event.contactHeight,
        tiltX: event.tiltX,
        tiltY: event.tiltY,
        timestampNs: event.timestampNs,
        capturedDisplayScale: event.capturedDisplayScale,
        transformRevision: current.revision,
        orientationRevision: current.orientationRevision,
        surfaceGeneration: current.surfaceGeneration,
        logicalX: Some(logicalX),
        logicalY: Some(logicalY))
    if (event.transformRevision == current.revision) {
        PointerNormalizationReceipt(PointerNormalizationDisposition.Accepted,
            "current-transform", event: Some(normalized))
    } else {
        PointerNormalizationReceipt(PointerNormalizationDisposition.Reprojected,
            "capture-transform-reprojected", event: Some(normalized))
    }
}

/** Compatibility edge for existing widgets; rich metadata remains available on `UiEvent.Pointer`. */
public func pointerEventToLegacyUiEvent(event: PointerEvent): UiEvent {
    match (event.phase) {
        case PointerPhase.Down => UiEvent.MouseDown(MouseButton.Left, event.x, event.y)
        case PointerPhase.Move => UiEvent.MouseMove(event.x, event.y)
        case PointerPhase.Up => UiEvent.MouseUp(MouseButton.Left, event.x, event.y)
        case PointerPhase.Cancel => UiEvent.MouseUp(MouseButton.Left, event.x, event.y)
    }
}
