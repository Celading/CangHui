package sdl

/** User content zoom, independent of the OS's backing-pixel density. */
public struct WindowScaleSettings {
    public let followSystem: Bool
    public let zoom: Float32

    public init(followSystem!: Bool = true, zoom!: Float32 = 1.0) {
        if (!(zoom >= 0.25 && zoom <= 4.0)) {
            throw IllegalArgumentException("window zoom must be finite and between 0.25 and 4")
        }
        this.followSystem = followSystem
        this.zoom = zoom
    }
}

/** One transform for drawing, window-unit input and IME anchors. No bitmap stretching policy. */
public struct WindowCoordinateTransform {
    public let pixelDensity: Float32
    public let renderScale: Float32
    public let windowScale: Float32

    public init(renderScale: Float32, pixelDensity: Float32) {
        if (!(renderScale > 0.0 && renderScale <= 256.0) ||
            !(pixelDensity > 0.0 && pixelDensity <= 64.0)) {
            throw IllegalArgumentException("window transform scales must be finite and positive")
        }
        this.renderScale = renderScale
        this.pixelDensity = pixelDensity
        this.windowScale = renderScale / pixelDensity
    }

    public func windowToLogical(point: Point): Point {
        Point(point.x / windowScale, point.y / windowScale)
    }

    public func logicalToWindow(rect: Rect): Rect {
        Rect(rect.x * windowScale, rect.y * windowScale, rect.w * windowScale, rect.h * windowScale)
    }
}

internal func resolveWindowTransform(
    systemScale: Float32,
    pixelDensity: Float32,
    legacyWindowScale: Float32,
    settings: ?WindowScaleSettings
): WindowCoordinateTransform {
    let renderScale = match (settings) {
        case Some(value) =>
            (if (value.followSystem) { systemScale } else { pixelDensity }) * value.zoom
        // Existing explicit scale means SDL window units per logical unit, not framebuffer pixels.
        case None => legacyWindowScale * pixelDensity
    }
    WindowCoordinateTransform(renderScale, pixelDensity)
}

/** Native-free transaction: pixel density changes must advance input identity too. */
internal func measuredWindowMetrics(
    current: WindowMetrics,
    pixelWidth: Int32,
    pixelHeight: Int32,
    transform: WindowCoordinateTransform
): WindowMetrics {
    let width = Int32(Float32(pixelWidth) / transform.renderScale)
    let height = Int32(Float32(pixelHeight) / transform.renderScale)
    let changed = current.displayScale != transform.renderScale ||
        current.pixelDensity != transform.pixelDensity || current.pixelWidth != pixelWidth ||
        current.pixelHeight != pixelHeight || current.logicalWidth != width || current.logicalHeight != height
    WindowMetrics(width, height, pixelWidth, pixelHeight, transform.renderScale,
        current.transformRevision + (if (changed) { UInt64(1) } else { UInt64(0) }),
        pixelDensity: transform.pixelDensity)
}
