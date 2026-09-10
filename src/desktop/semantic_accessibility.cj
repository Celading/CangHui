package chui.desktop

import sdl.SdlWindow
import chui.core.{SemanticActionKind, SemanticActionRequest, SemanticActionReceipt,
    SemanticNativeSession, SemanticNativeSnapshot, SemanticTreeSnapshot, UiOwnerQueue}

/** One copied native action; IDs and revision belong to exactly one adapter instance. */
public struct DesktopAccessibilityAction {
    public let nativeId: UInt64
    public let revision: UInt64
    public let action: SemanticActionKind

    public init(nativeId: UInt64, revision: UInt64, action: SemanticActionKind) {
        this.nativeId = nativeId
        this.revision = revision
        this.action = action
    }
}

/**
 * Optional native accessibility port. Every method runs on the window's UI owner.
 * Native threads may only copy requests into a bounded adapter-owned inbox, never
 * invoke widgets/managed callbacks. poll returns None when empty and must not block.
 * publish receives full logical-coordinate trees, not screen/DPI-converted bounds.
 * close must revoke native callbacks and be idempotent. Factory results must be fresh
 * per window; do not share an instance across windows or adapter reopen operations.
 * This contract alone is not an installed platform provider or a debug input channel.
 */
public interface DesktopAccessibilityAdapter <: Resource {
    func publish(snapshot: SemanticNativeSnapshot): Unit
    func setWindowFocused(focused: Bool): Unit
    func poll(): ?DesktopAccessibilityAction
}

/** Called once per window with (semanticWindowId, windowTitle); throwing aborts opening. */
public type DesktopAccessibilityFactory = (String, String) -> DesktopAccessibilityAdapter

/** Uses the window's EXISTING queue/runtime. No second event loop or semantic owner. */
internal class DesktopSemanticAccessibility <: Resource {
    private let session: SemanticNativeSession
    private let adapter: DesktopAccessibilityAdapter
    private let queue: UiOwnerQueue
    private let dispatch: (SemanticActionRequest) -> SemanticActionReceipt
    private var closed = false

    init(windowId: String, adapter: DesktopAccessibilityAdapter, queue: UiOwnerQueue,
        dispatch: (SemanticActionRequest) -> SemanticActionReceipt) {
        session = SemanticNativeSession(windowId)
        this.adapter = adapter
        this.queue = queue
        this.dispatch = dispatch
    }

    func publish(tree: SemanticTreeSnapshot): Unit {
        if (closed) { return }
        try {
            session.publish(tree)
            adapter.publish(session.snapshot().getOrThrow())
        } catch (error: Exception) {
            // A partially updated backend may not be trusted for later actions.
            failClosed()
            throw error
        }
    }

    func updateGeometry(window: SdlWindow): Unit {
        if (closed) { return }
        try {
            if (let Some(provider) <- (adapter as DesktopAccessibilityGeometryAdapter)) {
                provider.setWindowGeometry(desktopAccessibilityGeometry(window))
            }
        } catch (error: Exception) { failClosed(); throw error }
    }

    /** Poll even while idle so native actions can wake the existing owner/render path. */
    func service(focused: Bool): Unit {
        if (closed) { return }
        try {
            adapter.setWindowFocused(focused)
            // Match the bounded native inbox. Continuous producers cannot starve paint/close.
            for (_ in 0..128) {
                let action = match (adapter.poll()) { case Some(value) => value; case None => break }
                let _ = session.postUnchangedTargetAction(queue, action.nativeId, action.revision,
                    action.action, {request =>
                        let receipt = dispatch(request)
                        if (!receipt.ok) {
                            throw IllegalStateException("native accessibility action rejected: ${receipt.code}")
                        }
                    })
            }
        } catch (error: Exception) {
            failClosed()
            throw error
        }
    }

    public func close(): Unit {
        if (closed) { return }
        closed = true
        session.close() // Revoke queued work BEFORE native deregistration can throw/reenter.
        adapter.close()
    }

    public func isClosed(): Bool { closed }

    private func failClosed(): Unit {
        try { close() } catch (_: Exception) { () } // Preserve the original backend failure.
    }
}
