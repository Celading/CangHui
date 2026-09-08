package chui.desktop

import sdl.{Rect, SdlWindow, WindowMetrics, WindowCoordinateTransform}

/** Measured physical screen rectangles. inner is the client area, outer includes decoration. */
public struct DesktopAccessibilityScreenBounds {
    public let inner: Rect
    public let outer: Rect

    public init(inner: Rect, outer: Rect) {
        if (!validAccessibilityRect(inner) || !validAccessibilityRect(outer)) {
            throw IllegalArgumentException("accessibility screen bounds must be finite and non-negative in size")
        }
        this.inner = inner
        this.outer = outer
    }
}

/** Geometry from the existing window owner; None means no trustworthy screen origin. */
public struct DesktopAccessibilityGeometry {
    public let metrics: WindowMetrics
    public let videoDriver: String
    public let screen: ?DesktopAccessibilityScreenBounds

    public init(metrics: WindowMetrics, videoDriver: String, screen: ?DesktopAccessibilityScreenBounds) {
        this.metrics = metrics
        this.videoDriver = videoDriver
        this.screen = screen
    }

    public func logicalToPixels(rect: Rect): Rect {
        WindowCoordinateTransform(metrics.displayScale, metrics.pixelDensity).logicalToPixels(rect)
    }
}

/** Optional companion port. Adapter decorators must forward it if the inner adapter requires it. */
public interface DesktopAccessibilityGeometryAdapter {
    func setWindowGeometry(geometry: DesktopAccessibilityGeometry): Unit
}

internal func desktopAccessibilityGeometry(window: SdlWindow): DesktopAccessibilityGeometry {
    let metrics = window.currentMetrics()
    let driver = window.videoDriver()
    var screen: ?DesktopAccessibilityScreenBounds = None
    // SDL X11 window units are root-screen pixels. Other backends need their own
    // native position contract; backing-pixel density is not a guessed screen scale.
    if (driver == "x11" && metrics.pixelDensity == 1.0) {
        let position = window.position()
        let border = window.borderSize()
        let inner = Rect(Float32(position.x), Float32(position.y),
            Float32(metrics.pixelWidth), Float32(metrics.pixelHeight))
        screen = Some(DesktopAccessibilityScreenBounds(inner,
            Rect(inner.x - Float32(border.left), inner.y - Float32(border.top),
                inner.w + Float32(border.left) + Float32(border.right),
                inner.h + Float32(border.top) + Float32(border.bottom))))
    }
    DesktopAccessibilityGeometry(metrics, driver, screen)
}

private func validAccessibilityRect(rect: Rect): Bool {
    rect.x >= -Float32.Max && rect.x <= Float32.Max &&
        rect.y >= -Float32.Max && rect.y <= Float32.Max &&
        rect.w >= 0.0 && rect.w <= Float32.Max && rect.h >= 0.0 && rect.h <= Float32.Max
}

internal func sameAccessibilityTransform(first: WindowMetrics, second: WindowMetrics): Bool {
    first.transformRevision == second.transformRevision && first.displayScale == second.displayScale &&
        first.pixelDensity == second.pixelDensity && first.pixelWidth == second.pixelWidth &&
        first.pixelHeight == second.pixelHeight && first.logicalWidth == second.logicalWidth &&
        first.logicalHeight == second.logicalHeight
}
