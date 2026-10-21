package chui_public_api_consumer

import chui.{BoundedMailbox, ExternalFramePlane, ExternalFrameSnapshot, InputCoordinateSpace,
    InputTransform, PointerDeviceKind, PointerEvent, PointerInputBridge,
    PointerNormalizationDisposition, PointerNormalizationReceipt, PointerPhase,
    Rect, Renderer, SymbolPainter, TextAreaVisualLine, UiEvent, WindowMetrics,
    normalizePointerEvent, pointerEventToLegacyUiEvent}

func require(condition: Bool, message: String): Unit {
    if (!condition) { throw IllegalStateException(message) }
}

private class FrameProvider <: ExternalFramePlane {
    private var playing = false
    private var position: Int64 = 0
    private var closed = false

    public func render(_: Renderer, _: Rect): Bool { !closed }
    public func snapshot(): ?ExternalFrameSnapshot {
        if (closed) { return None }
        Some(ExternalFrameSnapshot(UInt64(1), UInt32(640), UInt32(360), position,
            Int64(1000), Int32(0), playing, true))
    }
    public func play(): Bool { playing = true; !closed }
    public func pause(): Bool { playing = false; !closed }
    public func seek(value: Int64): Bool { position = value; !closed }
    public func close(): Unit { closed = true }
}

func verifyFacadeContracts(): Unit {
    let line = TextAreaVisualLine(logicalLine: 2, startByte: 3, endByte: 9, width: 24.0)
    require(line.logicalLine == 2 && line.startByte == 3 && line.endByte == 9,
        "explicit facade visual-line fields")
    let painter: SymbolPainter = {_, _, _ => ()}
    painter(Renderer.headless(), Rect.zero(), symbolPaintForFixture())
    let queue = BoundedMailbox<Int64>(capacity: 2)
    queue.push(1); queue.push(2); queue.push(3)
    let queued = queue.drain()
    require(queued.size == 2 && queued[0] == 2 && queued[1] == 3, "bounded mailbox order")

    let metrics = WindowMetrics(Int32(100), Int32(80), Int32(200), Int32(160), 2.0, UInt64(2))
    let transform: InputTransform = metrics.inputTransform()
    let event = PointerEvent(PointerPhase.Down, PointerDeviceKind.Touch, UInt64(7), 40.0, 60.0,
        coordinateSpace: InputCoordinateSpace.WindowPixel, capturedDisplayScale: 2.0,
        transformRevision: UInt64(2), pressure: 0.5)
    let receipt: PointerNormalizationReceipt = normalizePointerEvent(event, transform)
    match (receipt.disposition) {
        case PointerNormalizationDisposition.Accepted => ()
        case _ => throw IllegalStateException("normalization disposition")
    }
    match (receipt.event) {
        case Some(normalized) =>
            require(normalized.x == 20.0 && normalized.y == 30.0 && normalized.pressure == 0.5,
                "capture coordinates and metadata")
            match (pointerEventToLegacyUiEvent(normalized)) {
                case UiEvent.MouseDown(_, x, y) => require(x == 20.0 && y == 30.0, "legacy edge")
                case _ => throw IllegalStateException("legacy pointer event")
            }
        case None => throw IllegalStateException("accepted event missing")
    }
    let bridge = PointerInputBridge(capacity: 4)
    require(bridge.push(event, transform).accepted(), "rich pointer bridge")
    let rejected = bridge.push(event, InputTransform(2.0, UInt64(2), orientationRevision: UInt64(1)))
    require(!rejected.accepted() && bridge.size() == 1, "stale pointer must not enter queue")
    require(bridge.drain().size == 1, "bridge drain")

    let plane: ExternalFramePlane = FrameProvider()
    require(plane.play() && plane.seek(400) && plane.render(Renderer.headless(), Rect.zero()),
        "external provider calls")
    match (plane.snapshot()) {
        case Some(snapshot) => require(snapshot.playing && snapshot.currentTimeMs == 400 &&
            snapshot.width == UInt32(640), "external snapshot fields")
        case None => throw IllegalStateException("frame snapshot missing")
    }
    require(plane.pause(), "external pause")
    plane.close()
    require(plane.snapshot().isNone(), "external close")
}
