package chui.desktop

import sdl.{Rect, WindowCoordinateTransform, WindowMetrics}

@Test
func accessibilityPhysicalGeometryUsesExistingRenderScaleNotWindowUnits(): Unit {
    let metrics = WindowMetrics(400, 300, 1000, 750, 2.5, UInt64(3), pixelDensity: 2.0)
    let geometry = DesktopAccessibilityGeometry(metrics, "unknown", None)
    let frame = Rect(10.0, 20.0, 40.0, 32.0)
    let physical = geometry.logicalToPixels(frame)
    @Expect(physical.x, 25.0)
    @Expect(physical.y, 50.0)
    @Expect(physical.w, 100.0)
    @Expect(physical.h, 80.0)
    let window = WindowCoordinateTransform(2.5, 2.0).logicalToWindow(frame)
    @Expect(window.x, 12.5)
    @Expect(window.y, 25.0)
    @Expect(window.w, 50.0)
    @Expect(window.h, 40.0)
    @Expect(geometry.screen.isNone()) // Unknown origin is not the origin0,0.
}

@Test
func accessibilityTransformIdentityRejectsSameRevisionWithDifferentGeometry(): Unit {
    let first = WindowMetrics(400, 300, 800, 600, 2.0, UInt64(1))
    @Expect(sameAccessibilityTransform(first, first))
    for (other in [WindowMetrics(400, 300, 800, 600, 2.0, UInt64(2)),
        WindowMetrics(400, 300, 800, 600, 2.0, UInt64(1), pixelDensity: 2.0),
        WindowMetrics(200, 150, 800, 600, 4.0, UInt64(1)),
        WindowMetrics(400, 300, 801, 600, 2.0, UInt64(1))]) {
        @Expect(!sameAccessibilityTransform(first, other))
    }
}

@Test
func accessibilityScreenBoundsAcceptNegativeMonitorOriginButRejectInvalidExtent(): Unit {
    let bounds = DesktopAccessibilityScreenBounds(Rect(-1800.0, -300.0, 800.0, 600.0),
        Rect(-1801.0, -325.0, 802.0, 626.0))
    @Expect(bounds.inner.x, -1800.0)
    var rejected = false
    try { let _ = DesktopAccessibilityScreenBounds(Rect(0.0, 0.0, -1.0, 10.0), Rect.zero()) }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}
