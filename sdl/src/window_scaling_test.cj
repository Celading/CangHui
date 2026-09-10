package sdl

@Test
func macAndWindowsDensityUseDifferentWindowEventDivisors(): Unit {
    let settings = Some(WindowScaleSettings())
    let mac = resolveWindowTransform(2.0, 2.0, 1.0, settings)
    let windows = resolveWindowTransform(2.0, 1.0, 1.0, settings)
    @Expect(mac.renderScale, Float32(2.0))
    @Expect(windows.renderScale, Float32(2.0))
    @Expect(mac.windowScale, Float32(1.0))
    @Expect(windows.windowScale, Float32(2.0))
    @Expect(mac.windowToLogical(Point(200.0, 100.0)).x, Float32(200.0))
    @Expect(windows.windowToLogical(Point(400.0, 200.0)).x, Float32(200.0))
}

@Test
func zoomAndImeUseExactInverseAtEveryScale(): Unit {
    for (density in [Float32(1.0), Float32(2.0)]) {
        for (zoom in [Float32(1.0), Float32(1.25), Float32(1.5), Float32(2.0), Float32(1.0)]) {
            let transform = resolveWindowTransform(2.0, density, 1.0,
                Some(WindowScaleSettings(zoom: zoom)))
            let caret = transform.logicalToWindow(Rect(160.0, 80.0, 8.0, 16.0))
            let hit = transform.windowToLogical(Point(caret.x, caret.y))
            @Expect(hit.x, Float32(160.0))
            @Expect(hit.y, Float32(80.0))
            let event = scaleEventCoordinates(UiEvent.MouseMove(caret.x, caret.y), transform.windowScale)
            match (event) {
                case UiEvent.MouseMove(x, y) => @Expect(x, hit.x); @Expect(y, hit.y)
                case _ => @Expect(false)
            }
        }
    }
}

@Test
func legacyWindowScaleAndIndependentUiZoomHaveExplicitSemantics(): Unit {
    let legacy = resolveWindowTransform(2.0, 2.0, 1.5, None<WindowScaleSettings>)
    @Expect(legacy.windowScale, Float32(1.5))
    @Expect(legacy.renderScale, Float32(3.0))
    let independent = resolveWindowTransform(3.0, 2.0, 1.5,
        Some(WindowScaleSettings(followSystem: false, zoom: 1.25)))
    @Expect(independent.windowScale, Float32(1.25))
    @Expect(independent.renderScale, Float32(2.5))
}

@Test
func densityAndZoomTransactionsAdvanceRevisionAndKeepNativePixels(): Unit {
    let before = WindowMetrics(800, 600, 1600, 1200, 2.0, UInt64(1), pixelDensity: 2.0)
    let zoomed = measuredWindowMetrics(before, 1600, 1200, WindowCoordinateTransform(2.5, 2.0))
    @Expect(zoomed.logicalWidth, Int32(640))
    @Expect(zoomed.pixelWidth, Int32(1600))
    @Expect(zoomed.transformRevision, UInt64(2))
    let repeated = measuredWindowMetrics(zoomed, 1600, 1200, WindowCoordinateTransform(2.5, 2.0))
    @Expect(repeated.transformRevision, UInt64(2))
    let changedUnits = measuredWindowMetrics(repeated, 1600, 1200, WindowCoordinateTransform(2.5, 1.0))
    @Expect(changedUnits.logicalWidth, repeated.logicalWidth)
    @Expect(changedUnits.transformRevision, UInt64(3))
    let restored = measuredWindowMetrics(changedUnits, 1600, 1200, WindowCoordinateTransform(2.0, 2.0))
    @Expect(restored.logicalWidth, before.logicalWidth)
}

@Test
func richWindowCoordinatesUseCaptureDensityAndRejectStaleZoom(): Unit {
    let event = PointerEvent(PointerPhase.Down, PointerDeviceKind.Touch, UInt64(9), 250.0, 125.0,
        coordinateSpace: InputCoordinateSpace.WindowCoordinates,
        capturedDisplayScale: 2.5, capturedPixelDensity: 2.0, transformRevision: UInt64(3))
    let current = InputTransform(2.5, UInt64(3), pixelDensity: 2.0)
    let result = normalizePointerEvent(event, current)
    @Expect(result.accepted())
    @Expect(result.event.getOrThrow().x, Float32(200.0))
    @Expect(result.event.getOrThrow().y, Float32(100.0))
    let stale = normalizePointerEvent(event, InputTransform(3.0, UInt64(4), pixelDensity: 2.0))
    @Expect(!stale.accepted())
    @Expect(stale.code, "stale-window-coordinate-transform")
}
