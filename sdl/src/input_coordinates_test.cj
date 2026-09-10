package sdl

@Test
func pointerCancelRemainsDistinctFromReleaseAfterNormalization(): Unit {
    let event = PointerEvent(PointerPhase.Cancel, PointerDeviceKind.Touch, UInt64(7), 30.0, 40.0,
        capturedDisplayScale: 2.0, transformRevision: UInt64(1))
    let receipt = normalizePointerEvent(event, InputTransform(2.0, UInt64(1)))
    @Expect(receipt.accepted())
    match (pointerEventToLegacyUiEvent(receipt.event.getOrThrow())) {
        case UiEvent.PointerCancelled => @Expect(true)
        case _ => @Fail("Cancellation must not become a successful mouse release")
    }
}

private func normalizedPointerAt(scale: Float32): PointerNormalizationReceipt {
    normalizePointerEvent(
        PointerEvent(PointerPhase.Move, PointerDeviceKind.Touch, UInt64(9),
            150.0 * scale, 90.0 * scale,
            coordinateSpace: InputCoordinateSpace.SurfacePixel,
            sourceDeviceId: UInt64(4),
            pressure: 0.75,
            contactWidth: 12.0,
            contactHeight: 8.0,
            capturedDisplayScale: scale,
            transformRevision: UInt64(3),
            surfaceGeneration: UInt64(5)),
        InputTransform(scale, UInt64(3), surfaceGeneration: UInt64(5)))
}

@Test
func pointerNormalizationIsStableAcrossCommonDisplayScales(): Unit {
    let scales: Array<Float32> = [1.0, 1.25, 1.5, 2.0]
    for (scale in scales) {
        let receipt = normalizedPointerAt(scale)
        @Expect(receipt.accepted())
        match (receipt.event) {
            case Some(event) =>
                @Expect(event.x, 150.0)
                @Expect(event.y, 90.0)
                @Expect(event.sourceDeviceId, UInt64(4))
                @Expect(event.pressure, 0.75)
                @Expect(event.contactWidth, 12.0)
            case None => @Fail("normalized pointer should retain its event")
        }
    }
}

@Test
func staleTransformReprojectsWithCaptureScaleInsteadOfCurrentScale(): Unit {
    let event = PointerEvent(PointerPhase.Down, PointerDeviceKind.Pen, UInt64(7), 300.0, 150.0,
        coordinateSpace: InputCoordinateSpace.WindowPixel,
        capturedDisplayScale: 1.5,
        transformRevision: UInt64(10))
    let receipt = normalizePointerEvent(event, InputTransform(2.0, UInt64(11)))
    match (receipt.disposition) {
        case PointerNormalizationDisposition.Reprojected => @Expect(true)
        case _ => @Fail("stale transform should be explicitly reprojected")
    }
    match (receipt.event) {
        case Some(value) =>
            @Expect(value.x, 200.0)
            @Expect(value.y, 100.0)
            @Expect(value.transformRevision, UInt64(11))
        case None => @Fail("reprojected pointer should remain usable")
    }
}

@Test
func staleSurfaceAndOrientationEventsAreRejected(): Unit {
    let staleSurface = PointerEvent(PointerPhase.Up, PointerDeviceKind.Touch, UInt64(1), 1.0, 1.0,
        surfaceGeneration: UInt64(3))
    @Expect(!normalizePointerEvent(staleSurface,
        InputTransform(1.0, UInt64(1), surfaceGeneration: UInt64(4))).accepted())

    let staleOrientation = PointerEvent(PointerPhase.Move, PointerDeviceKind.Touch, UInt64(1), 1.0, 1.0,
        orientationRevision: UInt64(2))
    @Expect(!normalizePointerEvent(staleOrientation,
        InputTransform(1.0, UInt64(1), orientationRevision: UInt64(3))).accepted())
}

@Test
func screenCoordinatesRequireProviderOwnedWindowOrigin(): Unit {
    let event = PointerEvent(PointerPhase.Move, PointerDeviceKind.Mouse, UInt64(0), 500.0, 300.0,
        coordinateSpace: InputCoordinateSpace.ScreenPixel)
    let receipt = normalizePointerEvent(event, InputTransform(1.0, UInt64(1)))
    @Expect(!receipt.accepted())
    @Expect(receipt.code, "screen-origin-required")
}
