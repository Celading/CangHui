package sdl

public struct WindowSpec {
    public let title: String
    public let width: Int32
    public let height: Int32
    public let resizable: Bool
    public let highDpi: Bool
    /** Whether the platform draws its native title bar and window border. */
    public let decorated: Bool
    /** Convenience alias: `frameless: true` is equivalent to `decorated: false`. */
    public let frameless: Bool
    /**
     * Native window-shape corner radius in logical pixels. A positive radius creates a
     * transparent shaped window and is intended for custom/frameless chrome. Decorated
     * platform windows should normally leave this at zero and use the system's own corners.
     */
    public let cornerRadius: Float32
    public let scale: Float32
    /** None preserves explicit legacy window-unit scale. Some enables system-aware UI zoom. */
    public let scaling: ?WindowScaleSettings
    // Whether the renderer waits for the vertical blank on present. On (the default) prevents
    // tearing and is the right choice for real applications. Off lets the frame loop run
    // uncapped, which is how a benchmark measures true per-frame work: with vsync on, every
    // frame period snaps to a refresh multiple (16.7/33.3/50 ms at 60 Hz), so any improvement
    // smaller than a whole refresh interval is invisible.
    public let vsync: Bool
    // Supersample factor per axis (1 = off, 2 = default 4x-samples anti-aliasing). Higher is
    // smoother but pays for that many times the pixels every frame; lower trades edge smoothness
    // for fill cost. 2 suits a hardware renderer; a software renderer may want 1.
    public let supersample: Int32

    public init(
        title: String,
        width: Int32,
        height: Int32,
        resizable!: Bool = true,
        highDpi!: Bool = true,
        scale!: Float32 = 1.0,
        vsync!: Bool = true,
        supersample!: Int32 = 2,
        decorated!: Bool = true,
        frameless!: Bool = false,
        cornerRadius!: Float32 = 0.0,
        scaling!: ?WindowScaleSettings = None
    ) {
        this.title = title
        this.width = width
        this.height = height
        this.resizable = resizable
        this.highDpi = highDpi
        this.decorated = decorated
        this.frameless = frameless
        this.cornerRadius = normalizedCornerRadius(cornerRadius)
        this.scale = normalizedScale(scale)
        this.scaling = scaling
        this.vsync = vsync
        this.supersample = supersample
    }
}

public class SdlWindow <: Resource {
    internal let windowPtr: CPointer<Unit>
    private let rendererPtr: CPointer<Unit>
    private let ownerThreadId: UInt64
    private let closeGate: WindowCloseGate
    private let runtime: SdlRuntime
    private var backingPixelWidth: Int32
    private var backingPixelHeight: Int32
    private var backingDensity: Float32 = 1.0
    private let legacyWindowScale: Float32
    private var scalingSettings: ?WindowScaleSettings
    private var shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested,
        0.0, 0.0, 0, 0)

    public var width: Int32
    public var height: Int32
    public var scale: Float32
    public var transformRevision: UInt64
    public let cornerRadius: Float32
    public let renderer: Renderer
    public let id: WindowId

    /**
     * Throws `CuiException` when SDL cannot create or initialize the window, renderer, or text input.
     */
    public init(spec: WindowSpec) {
        this.width = spec.width
        this.height = spec.height
        this.scale = spec.scale
        this.legacyWindowScale = spec.scale
        this.scalingSettings = spec.scaling
        this.transformRevision = UInt64(1)
        this.backingPixelWidth = scaledDimension(spec.width, spec.scale)
        this.backingPixelHeight = scaledDimension(spec.height, spec.scale)
        this.cornerRadius = spec.cornerRadius
        this.runtime = SdlRuntime()

        let flags = windowCreationFlags(spec)

        var window = CPointer<Unit>()
        var createdRenderer = CPointer<Unit>()
        var nativeWindowId = UInt32(0)
        var initialDensity: Float32 = 1.0
        var initialScale = spec.scale
        var initialPixelWidth: Int32 = 0
        var initialPixelHeight: Int32 = 0
        var initialShapeReceipt = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested,
            spec.cornerRadius, 0.0, 0, 0)
        let titleText = unsafe { LibC.mallocCString(spec.title) }
        try (titleResource = titleText.asResource()) {
            try {
                let pixelWidth = scaledDimension(spec.width, spec.scale)
                let pixelHeight = scaledDimension(spec.height, spec.scale)
                let ok = unsafe {
                    SDL_CreateWindowAndRenderer(titleResource.value, pixelWidth, pixelHeight, flags, inout window,
                        inout createdRenderer)
                }
                if (!ok || window.isNull() || createdRenderer.isNull()) {
                    throw CuiException("SDL_CreateWindowAndRenderer failed: ${lastSdlError()}")
                }
                initialDensity = unsafe { SDL_GetWindowPixelDensity(window) }
                let transform = resolveWindowTransform(unsafe { SDL_GetWindowDisplayScale(window) },
                    initialDensity, spec.scale, spec.scaling)
                initialScale = transform.renderScale
                if (spec.scaling.isSome()) {
                    ensureSdl(unsafe { SDL_SetWindowSize(window,
                        scaledDimension(spec.width, transform.windowScale),
                        scaledDimension(spec.height, transform.windowScale)) }, "SDL_SetWindowSize")
                }
                ensureSdl(unsafe { SDL_GetWindowSizeInPixels(window, inout initialPixelWidth,
                    inout initialPixelHeight) }, "SDL_GetWindowSizeInPixels")
                configureRenderer(createdRenderer, initialScale, spec.vsync)
                initialShapeReceipt = applyRoundedWindowShape(window, initialPixelWidth, initialPixelHeight,
                    spec.cornerRadius * initialScale)
                if (!unsafe { SDL_StartTextInput(window) }) {
                    throw CuiException("SDL_StartTextInput failed: ${lastSdlError()}")
                }
                nativeWindowId = unsafe { SDL_GetWindowID(window) }
                if (nativeWindowId == UInt32(0)) {
                    throw CuiException("SDL_GetWindowID failed: ${lastSdlError()}")
                }
            } catch (error: Exception) {
                destroyCreatedResources(window, createdRenderer)
                runtime.close()
                throw error
            }
        }

        this.windowPtr = window
        this.rendererPtr = createdRenderer
        let nativeOwner = unsafe { SDL_GetCurrentThreadID() }
        this.ownerThreadId = nativeOwner
        this.closeGate = WindowCloseGate(nativeOwner)
        this.renderer = Renderer(createdRenderer, contentScale: initialScale, supersample: spec.supersample)
        this.scale = initialScale
        this.backingDensity = initialDensity
        this.backingPixelWidth = initialPixelWidth
        this.backingPixelHeight = initialPixelHeight
        this.width = Int32(Float32(initialPixelWidth) / initialScale)
        this.height = Int32(Float32(initialPixelHeight) / initialScale)
        this.id = WindowId(nativeWindowId)
        this.shapeReceiptValue = initialShapeReceipt
    }

    /** Snapshot used by render, input and probes to agree on one transform revision. */
    public func currentMetrics(): WindowMetrics {
        WindowMetrics(width, height, backingPixelWidth, backingPixelHeight, scale, transformRevision,
            pixelDensity: backingDensity)
    }

    public func coordinateTransform(): WindowCoordinateTransform {
        WindowCoordinateTransform(scale, backingDensity)
    }

    /** UI-owner operation. Keeps native window size, relayouts content at the selected zoom. */
    public func setScaling(settings: WindowScaleSettings): WindowMetrics {
        ensureScaleOwner()
        let previous = scalingSettings
        scalingSettings = Some(settings)
        try {
            return refreshDisplayScale()
        } catch (error: Exception) {
            scalingSettings = previous
            throw error
        }
    }

    /** Shared lowering for the single-window and application-level event pumps. */
    public func normalizeWindowEvent(event: UiEvent): UiEvent {
        match (event) {
            // Query a complete native snapshot, not one possibly stale queued size payload.
            case UiEvent.WindowDisplayScaleChanged => UiEvent.WindowMetricsChanged(refreshDisplayScale())
            case UiEvent.WindowPixelSizeChanged(_, _) => UiEvent.WindowMetricsChanged(refreshDisplayScale())
            case UiEvent.WindowResized(_, _) => UiEvent.WindowMetricsChanged(refreshDisplayScale())
            case UiEvent.WindowMaximized =>
                ensureScaleOwner()
                refreshRoundedShape(backingPixelWidth, backingPixelHeight)
                event
            case UiEvent.WindowRestored =>
                ensureScaleOwner()
                refreshRoundedShape(backingPixelWidth, backingPixelHeight)
                event
            case _ => scaleEventCoordinates(event, coordinateTransform().windowScale)
        }
    }

    /**
     * Atomically publishes a provider scale/backing-size change. Logical layout remains stable;
     * the renderer and physical shape resources switch before the new revision is returned.
     */
    public func applyDisplayScale(
        displayScale: Float32,
        pixelWidth: Int32,
        pixelHeight: Int32
    ): WindowMetrics {
        let next = nextWindowMetrics(currentMetrics(), displayScale, pixelWidth, pixelHeight)
        return commitMetrics(next)
    }

    private func commitMetrics(next: WindowMetrics): WindowMetrics {
        renderer.setScale(next.displayScale)
        width = next.logicalWidth
        height = next.logicalHeight
        scale = next.displayScale
        backingDensity = next.pixelDensity
        transformRevision = next.transformRevision
        backingPixelWidth = next.pixelWidth
        backingPixelHeight = next.pixelHeight
        refreshRoundedShape(next.pixelWidth, next.pixelHeight)
        next
    }

    /** Samples backing size and both scale facts together on the native UI owner. */
    public func refreshDisplayScale(): WindowMetrics {
        ensureScaleOwner()
        var pixelWidth: Int32 = 0
        var pixelHeight: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowSizeInPixels(windowPtr, inout pixelWidth, inout pixelHeight) },
            "SDL_GetWindowSizeInPixels")
        let nativeDisplayScale = unsafe { SDL_GetWindowDisplayScale(windowPtr) }
        let nativePixelDensity = unsafe { SDL_GetWindowPixelDensity(windowPtr) }
        let transform = resolveWindowTransform(nativeDisplayScale, nativePixelDensity, legacyWindowScale, scalingSettings)
        commitMetrics(measuredWindowMetrics(currentMetrics(), pixelWidth, pixelHeight, transform))
    }

    /** Explicit native-state barrier; normal event processing does not call this. */
    public func sync(): Unit {
        ensureScaleOwner()
        ensureSdl(unsafe { SDL_SyncWindow(windowPtr) }, "SDL_SyncWindow")
    }

    private func ensureScaleOwner(): Unit {
        if (isClosed() || !sameNativeThread(ownerThreadId, unsafe { SDL_GetCurrentThreadID() })) {
            throw IllegalStateException("window metrics require the open window's native UI owner")
        }
    }

    public func setTitle(title: String): Unit {
        let cTitle = unsafe { LibC.mallocCString(title) }
        try (titleResource = cTitle.asResource()) {
            ensureSdl(unsafe { SDL_SetWindowTitle(windowPtr, titleResource.value) }, "SDL_SetWindowTitle")
        }
    }

    /** Sets a live window icon where supported; application bundle/Dock identity is separate. */
    public func setIcon(icon: Surface): Unit {
        ensureScaleOwner()
        if (icon.isClosed()) { throw IllegalStateException("window icon surface is closed") }
        ensureSdl(unsafe { SDL_SetWindowIcon(windowPtr, icon.ptr) }, "SDL_SetWindowIcon")
    }

    public func setSize(width: Int32, height: Int32): Unit {
        let windowScale = coordinateTransform().windowScale
        let pixelWidth = scaledDimension(width, windowScale)
        let pixelHeight = scaledDimension(height, windowScale)
        ensureSdl(unsafe { SDL_SetWindowSize(windowPtr, pixelWidth, pixelHeight) }, "SDL_SetWindowSize")
        let _ = refreshDisplayScale()
    }

    public func refreshSize(): Size {
        let _ = refreshDisplayScale()
        Size(Float32(width), Float32(height))
    }

    /** Applies a CangHui-logical resize and rebuilds pixel-owned native shape resources. */
    public func updateLogicalSize(logicalWidth: Int32, logicalHeight: Int32): Unit {
        applyResizeUpdate(logicalWindowResizeUpdate(logicalWidth, logicalHeight, scale))
    }

    /** Applies an SDL drawable-pixel change without corrupting unchanged logical layout size. */
    public func updatePixelSize(pixelWidth: Int32, pixelHeight: Int32): Unit {
        applyResizeUpdate(backingPixelResizeUpdate(width, height, pixelWidth, pixelHeight))
    }

    /**
     * Compatibility conversion for callers holding content-scaled window coordinates.
     * `SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED` must use `updatePixelSize` instead.
     */
    public func updateSizeFromPixels(pixelWidth: Int32, pixelHeight: Int32): Unit {
        let logical = windowSizeFromPixels(pixelWidth, pixelHeight, scale)
        applyResizeUpdate(WindowResizeUpdate(
            Int32(logical.w), Int32(logical.h), pixelWidth, pixelHeight))
    }

    /**
     * Tells the OS where the text caret is, in the window's logical pixels (the same space
     * as events and drawing), so IME composition UI — the candidate window — appears at the
     * caret instead of a screen corner. The conversion to window pixels happens here.
     */
    public func setTextInputArea(rect: Rect): Unit {
        var raw = coordinateTransform().logicalToWindow(rect).toSdlRect()
        ensureSdl(unsafe { SDL_SetTextInputArea(windowPtr, inout raw, 0) }, "SDL_SetTextInputArea")
    }

    public func pollEvent(): ?UiEvent {
        match (pollEventEnvelope()) {
            case Some(envelope) => Some(envelope.event)
            case None => None
        }
    }

    /** Compatibility polling path. Multi-window applications should pump one shared `SdlRuntime`. */
    public func pollEventEnvelope(): ?SdlEventEnvelope {
        let currentThreadId = unsafe { SDL_GetCurrentThreadID() }
        if (!sameNativeThread(ownerThreadId, currentThreadId)) {
            throw CuiException(
                "SDL event polling moved across native threads (owner=${ownerThreadId}, current=${currentThreadId}); create or borrow the desktop window only after blocking startup work"
            )
        }
        match (runtime.pollEvent()) {
            case Some(envelope) =>
                let scaled = match (envelope.windowId) {
                    case Some(target) =>
                        if (target == id) {
                            SdlEventEnvelope(envelope.windowId, normalizeWindowEvent(envelope.event))
                        } else { envelope }
                    case None => envelope
                }
                Some(scaled)
            case None => None
        }
    }

    public func shapeReceipt(): WindowShapeReceipt { shapeReceiptValue }

    public func ticks(): UInt64 {
        unsafe { SDL_GetTicks() }
    }

    public func delay(ms: UInt32): Unit {
        unsafe { SDL_Delay(ms) }
    }

    public func isClosed(): Bool {
        closeGate.isClosed()
    }

    /**
     * Lends the SDL window pointer to a platform adapter for the duration of `body`.
     * The pointer is framework-owned: consumers must not destroy it or retain it after
     * this window closes. Application scene models should never store this value.
     */
    public func withBorrowedPlatformWindow<T>(body: (CPointer<Unit>) -> T): T {
        if (isClosed() || windowPtr.isNull()) {
            throw IllegalStateException("cannot borrow a closed SDL window")
        }
        body(windowPtr)
    }

    /**
     * Closes native window resources exactly once on the native thread that created them.
     *
     * A first close from another native thread fails before entering renderer or SDL
     * teardown. Once an owner-thread close has completed, repeated calls are no-ops from any
     * thread. Applications must keep creation, event pumping and first close on one native thread.
     */
    public func close(): Unit {
        let currentThreadId = unsafe { SDL_GetCurrentThreadID() }
        let result = closeGate.close(currentThreadId, { =>
            renderer.releaseResources()
            unsafe {
                if (windowPtr.isNotNull()) {
                    let _ = SDL_StopTextInput(windowPtr)
                }
                if (rendererPtr.isNotNull()) {
                    SDL_DestroyRenderer(rendererPtr)
                }
                if (windowPtr.isNotNull()) {
                    SDL_DestroyWindow(windowPtr)
                }
            }
            runtime.close()
        })
        match (result) {
            case WindowCloseResult.WrongThread =>
                throw CuiException(
                    "SDL window close moved across native threads; first close must run on the window owner thread"
                )
            case _ => ()
        }
    }

    private func refreshRoundedShape(pixelWidth: Int32, pixelHeight: Int32): Unit {
        // 最大化时满屏直角：清除已应用的圆角遮罩（还原时恢复配置圆角）
        let maximized = windowFlagsFromRaw(unsafe { SDL_GetWindowFlags(windowPtr) }).maximized
        if (maximized) {
            if (cornerRadius > 0.0 && shapeReceiptValue.status != WindowShapeApplyStatus.NotRequested) {
                try {
                    ensureSdl(unsafe { SDL_SetWindowShape(windowPtr, CPointer<Unit>()) }, "SDL_SetWindowShape(clear)")
                    shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.NotRequested, 0.0, 0.0,
                        pixelWidth, pixelHeight, detail: "shape cleared for maximized window")
                } catch (error: Exception) {
                    shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.Failed, 0.0,
                        shapeReceiptValue.appliedRadius, pixelWidth, pixelHeight,
                        detail: "shape clear failed: " + error.message)
                }
            }
            return
        }
        if (cornerRadius > 0.0) {
            try {
                shapeReceiptValue = applyRoundedWindowShape(windowPtr, pixelWidth, pixelHeight, cornerRadius * scale)
            } catch (error: Exception) {
                // Native shape allocation failure must not roll policy back after metrics committed.
                shapeReceiptValue = WindowShapeReceipt(WindowShapeApplyStatus.Failed, cornerRadius * scale,
                    0.0, pixelWidth, pixelHeight, detail: "shape refresh failed: " + error.message)
            }
        }
    }

    private func applyResizeUpdate(update: WindowResizeUpdate): Unit {
        width = update.logicalWidth
        height = update.logicalHeight
        backingPixelWidth = update.pixelWidth
        backingPixelHeight = update.pixelHeight
        refreshRoundedShape(update.pixelWidth, update.pixelHeight)
    }
}

internal enum WindowCloseResult {
    | Closed
    | AlreadyClosed
    | WrongThread
}

/**
 * Keeps the native teardown body behind an owner-thread and exactly-once gate. The gate is kept
 * separate from SDL so its no-native-entry behavior can be proven without constructing a window.
 */
internal class WindowCloseGate {
    private let ownerThreadId: UInt64
    private var closed = false

    internal init(ownerThreadId: UInt64) {
        this.ownerThreadId = ownerThreadId
    }

    internal func isClosed(): Bool { closed }

    internal func close(currentThreadId: UInt64, nativeClose: () -> Unit): WindowCloseResult {
        if (closed) {
            return WindowCloseResult.AlreadyClosed
        }
        if (!sameNativeThread(ownerThreadId, currentThreadId)) {
            return WindowCloseResult.WrongThread
        }
        closed = true
        nativeClose()
        WindowCloseResult.Closed
    }
}

internal func sameNativeThread(ownerThreadId: UInt64, currentThreadId: UInt64): Bool {
    ownerThreadId == currentThreadId
}

internal func windowCreationFlags(spec: WindowSpec): UInt64 {
    var flags = UInt64(0)
    if (spec.resizable) {
        flags = flags | SDL_WINDOW_RESIZABLE
    }
    if (spec.highDpi) {
        flags = flags | SDL_WINDOW_HIGH_PIXEL_DENSITY
    }
    if (!spec.decorated || spec.frameless) {
        flags = flags | SDL_WINDOW_BORDERLESS
    }
    if (spec.cornerRadius > 0.0) {
        flags = flags | SDL_WINDOW_TRANSPARENT
    }
    flags
}

internal func normalizedCornerRadius(radius: Float32): Float32 {
    if (radius > 0.0) { radius } else { 0.0 }
}
