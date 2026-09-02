package chui.core

import sdl.{InputTransform, MouseButton, PointerEvent, PointerNormalizationReceipt, UiEvent,
    normalizePointerEvent}

/**
 * Thread-safe pointer input bridge that collects synthetic platform pointer
 * events (down/move/up/click) and hands them to the CangHui UI thread.
 *
 * This is the generalized Harmony input mailbox: an ArkTS/native host can
 * call pushDown/pushMove/pushUp from any thread, while the CangHui render
 * loop drains events and injects them through DesktopApp's queuePointer*
 * APIs (or an equivalent host adapter).
 */
public class PointerInputBridge {
    private let mailbox: BoundedMailbox<UiEvent>

    public init(capacity!: Int64 = 64) {
        this.mailbox = BoundedMailbox<UiEvent>(capacity: capacity)
    }

    public func pushDown(x: Float32, y: Float32): Unit {
        mailbox.push(UiEvent.MouseDown(MouseButton.Left, x, y))
    }

    public func pushMove(x: Float32, y: Float32): Unit {
        mailbox.push(UiEvent.MouseMove(x, y))
    }

    public func pushUp(x: Float32, y: Float32): Unit {
        mailbox.push(UiEvent.MouseUp(MouseButton.Left, x, y))
    }

    public func pushClick(x: Float32, y: Float32): Unit {
        pushDown(x, y)
        pushUp(x, y)
    }

    /**
     * Normalizes one rich provider sample at the bridge boundary and retains its metadata.
     * Rejected stale samples never enter the UI queue.
     */
    public func push(event: PointerEvent, transform: InputTransform): PointerNormalizationReceipt {
        let receipt = normalizePointerEvent(event, transform)
        match (receipt.event) {
            case Some(normalized) => mailbox.push(UiEvent.Pointer(normalized))
            case None => ()
        }
        receipt
    }

    /** Removes and returns all buffered events in FIFO order. */
    public func drain(): Array<UiEvent> {
        mailbox.drain()
    }

    public func clear(): Unit {
        mailbox.clear()
    }

    public func size(): Int64 {
        mailbox.size()
    }
}
