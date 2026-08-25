package chui.scene3d

import chui.core.{UiContext, Widget, drawFocusRing, emit, focusableControlIdentity}
import chui.host.{HostNativeSurfaceService, NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceFrame,
    NativeSurfaceRenderer}
import sdl.{GamepadAxis, GamepadButton, GamepadConnectionState, GamepadDevice, MouseButton, Rect, Size, UiEvent}

/** Logical placement requested by one Scene3DView inside a normal CangHui layout. */
public struct Scene3DViewPlacement {
    public let viewId: String
    public let x: Float32
    public let y: Float32
    public let width: Float32
    public let height: Float32
    public let scale: Float32

    public init(viewId: String, x: Float32, y: Float32, width: Float32, height: Float32, scale: Float32) {
        if (viewId.isEmpty() || width <= 0.0 || height <= 0.0 || scale <= 0.0) {
            throw IllegalArgumentException("scene3d view placement must have identity and positive geometry")
        }
        this.viewId = viewId
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        this.scale = scale
    }
}

/** Placement receipt is distinct from renderer lifecycle and never carries a native handle. */
public struct Scene3DViewHostReceipt {
    public let ok: Bool
    public let operation: String
    public let code: String
    public let viewId: String
    public let detail: String

    public init(ok: Bool, operation: String, code: String, viewId: String, detail: String) {
        this.ok = ok
        this.operation = operation
        this.code = code
        this.viewId = viewId
        this.detail = detail
    }
}

/** Host extension that positions a native child surface under a normal widget. */
public interface Scene3DViewHost <: HostNativeSurfaceService {
    func place(placement: Scene3DViewPlacement): Scene3DViewHostReceipt
    func remove(viewId: String): Scene3DViewHostReceipt
}

/** Supplies one immutable product scene at a host frame boundary. */
public interface Scene3DViewFrameSource {
    func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot
}

/** Input delivered in widget-local coordinates after Scene3DView owns focus. */
public enum Scene3DViewInputEvent {
    | PointerDown(Float32, Float32, Scene3DHitTestResult)
    | PointerMove(Float32, Float32)
    | PointerUp(Float32, Float32)
    | PointerWheel(Float32, Float32, Float32, Float32)
    | GamepadConnectionChanged(GamepadDevice, GamepadConnectionState)
    | GamepadAxisMotion(UInt32, GamepadAxis, Float32)
    | GamepadButtonDown(UInt32, GamepadButton)
    | GamepadButtonUp(UInt32, GamepadButton)
}

/**
 * Retained bridge between an ephemeral widget and host/provider lifecycle.
 * Applications retain one controller and may rebuild Scene3DView values freely.
 */
public class Scene3DViewController <: NativeSurfaceRenderer {
    private let viewId: String
    private let host: Scene3DViewHost
    private let provider: Scene3DProvider
    private let resource: Scene3DResource
    private let frameSource: Scene3DViewFrameSource
    private let inputHandler: (Scene3DViewInputEvent) -> Bool
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var lastFrameId: Int64 = -1
    private var attached = false
    private var placed = false
    private var placementX: Float32 = 0.0
    private var placementY: Float32 = 0.0
    private var placementWidth: Float32 = 0.0
    private var placementHeight: Float32 = 0.0
    private var placementScale: Float32 = 0.0
    private var lastLifecycleReceipt = Scene3DReceipt(false, "initialize", "not-attached", 0, -1,
        "waiting for a host surface")
    private var lastHostReceipt = Scene3DViewHostReceipt(false, "place", "not-placed", "",
        "waiting for widget layout")

    public init(
        viewId: String,
        host: Scene3DViewHost,
        provider: Scene3DProvider,
        resource: Scene3DResource,
        frameSource: Scene3DViewFrameSource,
        onInput!: (Scene3DViewInputEvent) -> Bool = { _ => false }
    ) {
        if (viewId.isEmpty()) { throw IllegalArgumentException("scene3d view id must be present") }
        this.viewId = viewId
        this.host = host
        this.provider = provider
        this.resource = resource
        this.frameSource = frameSource
        this.inputHandler = onInput
        this.lastHostReceipt = Scene3DViewHostReceipt(false, "place", "not-placed", viewId,
            "waiting for widget layout")
        host.bind(this)
    }

    public func id(): String { viewId }
    public func isAttached(): Bool { attached }
    public func currentGeneration(): Int64 { generation }
    public func currentFrameId(): Int64 { lastFrameId }
    public func lifecycleReceipt(): Scene3DReceipt { lastLifecycleReceipt }
    public func hostReceipt(): Scene3DViewHostReceipt { lastHostReceipt }

    public func place(rect: Rect, scale: Float32): Scene3DViewHostReceipt {
        if (rect.w <= 0.0 || rect.h <= 0.0 || scale <= 0.0) {
            lastHostReceipt = Scene3DViewHostReceipt(false, "place", "invalid-geometry", viewId,
                "widget geometry and scale must be positive")
            return lastHostReceipt
        }
        if (placed && rect.x == placementX && rect.y == placementY && rect.w == placementWidth &&
            rect.h == placementHeight && scale == placementScale) {
            lastHostReceipt = Scene3DViewHostReceipt(true, "place", "unchanged", viewId,
                "placement already matches the host")
            return lastHostReceipt
        }
        let receipt = host.place(Scene3DViewPlacement(viewId, rect.x, rect.y, rect.w, rect.h, scale))
        lastHostReceipt = receipt
        if (receipt.ok) {
            placed = true
            placementX = rect.x
            placementY = rect.y
            placementWidth = rect.w
            placementHeight = rect.h
            placementScale = scale
        }
        receipt
    }

    public func remove(): Scene3DViewHostReceipt {
        let receipt = host.remove(viewId)
        lastHostReceipt = receipt
        if (receipt.ok) { placed = false }
        receipt
    }

    public func requestFrame(): Unit { host.requestFrame() }

    public func attach(surface: NativeSurfaceDescriptor): Unit {
        if (surface.generation <= 0) {
            lastLifecycleReceipt = reject("attach", "invalid-generation", surface.generation, 0,
                "host surface generation must be positive")
            return
        }
        let clock = Scene3DFrameClock(0, 0, 0)
        let receipt = provider.attach(toSceneSurface(surface), clock)
        lastLifecycleReceipt = receipt
        if (!receipt.ok) { return }
        attached = true
        surfaceId = surface.id
        generation = surface.generation
        lastFrameId = clock.frameId
        let loaded = provider.loadScene(resource)
        lastLifecycleReceipt = loaded
        if (!loaded.ok) {
            let _ = provider.detach(surface.id, surface.generation)
            attached = false
            surfaceId = ""
            generation = 0
            lastFrameId = -1
        }
    }

    public func resize(surface: NativeSurfaceDescriptor): Unit {
        if (!matches(surface.id, surface.generation)) {
            lastLifecycleReceipt = reject("resize", "stale-generation", surface.generation, lastFrameId,
                "resize does not match the attached host surface")
            return
        }
        lastLifecycleReceipt = provider.resize(toSceneSurface(surface))
    }

    public func draw(frame: NativeSurfaceFrame): Unit {
        if (!attached) {
            lastLifecycleReceipt = reject("frame", "not-attached", generation, frame.frameId,
                "frame arrived without an attached host surface")
            return
        }
        let clock = Scene3DFrameClock(frame.frameId, frame.timestampNanos, frame.targetTimestampNanos)
        let snapshot = frameSource.snapshot(clock)
        let submitted = provider.submit(snapshot, clock)
        lastLifecycleReceipt = submitted
        if (!submitted.ok) { return }
        let presented = provider.present(clock)
        lastLifecycleReceipt = presented
        if (presented.ok) { lastFrameId = frame.frameId }
    }

    public func detach(id: String, value: Int64): Unit {
        if (!matches(id, value)) {
            lastLifecycleReceipt = reject("detach", "stale-generation", value, lastFrameId,
                "detach does not match the attached host surface")
            return
        }
        let receipt = provider.detach(id, value)
        lastLifecycleReceipt = receipt
        if (receipt.ok) {
            attached = false
            surfaceId = ""
            generation = 0
            lastFrameId = -1
        }
    }

    public func hitTest(x: Float32, y: Float32): Scene3DHitTestResult {
        if (!attached || lastFrameId < 0) { return Scene3DHitTestResult.none(generation, lastFrameId) }
        provider.hitTest(Scene3DHitTestRequest(x, y, generation, lastFrameId))
    }

    public func dispatchInput(event: Scene3DViewInputEvent): Bool { inputHandler(event) }

    private func matches(id: String, value: Int64): Bool {
        attached && id == surfaceId && value == generation
    }

    private func reject(operation: String, code: String, value: Int64, frameId: Int64,
        detail: String): Scene3DReceipt {
        Scene3DReceipt(false, operation, code, value, frameId, detail)
    }
}

/** Embedded scene leaf; size/placement participates in the same layout as every other widget. */
public class Scene3DView <: Widget {
    private let controller: Scene3DViewController
    private let controlId: String
    private let preferredWidth: Float32
    private let preferredHeight: Float32
    private var frame = Rect.zero()

    public init(controller: Scene3DViewController, width!: Float32 = 320.0, height!: Float32 = 240.0) {
        if (width <= 0.0 || height <= 0.0) {
            throw IllegalArgumentException("scene3d view preferred size must be positive")
        }
        this.controller = controller
        this.controlId = focusableControlIdentity(controller.id())
        this.preferredWidth = width
        this.preferredHeight = height
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, preferredWidth), min(available.h, preferredHeight))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let _ = controller.place(rect, ctx.displayScale)
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.field)
        if (ctx.showFocusRing(controlId)) { drawFocusRing(ctx, frame, ctx.theme.smallRadius) }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                ctx.requestFrame()
                controller.requestFrame()
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    let localX = x - frame.x
                    let localY = y - frame.y
                    let _ = controller.dispatchInput(Scene3DViewInputEvent.PointerDown(localX, localY,
                        controller.hitTest(localX, localY)))
                    return true
                }
            case UiEvent.MouseMove(x, y) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerMove(x - frame.x, y - frame.y))
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerUp(x - frame.x, y - frame.y))
                }
            case UiEvent.MouseWheel(dx, dy, x, y) =>
                if (ctx.hasFocus(controlId) && frame.contains(x, y)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.PointerWheel(dx, dy,
                        x - frame.x, y - frame.y))
                }
            case UiEvent.GamepadConnectionChanged(device, state) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadConnectionChanged(device, state))
                }
            case UiEvent.GamepadAxisMotion(id, axis, value) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadAxisMotion(id, axis, value))
                }
            case UiEvent.GamepadButtonDown(id, button) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadButtonDown(id, button))
                }
            case UiEvent.GamepadButtonUp(id, button) =>
                if (ctx.hasFocus(controlId)) {
                    return controller.dispatchInput(Scene3DViewInputEvent.GamepadButtonUp(id, button))
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String { Some(controlId) }
    public func interactionOwnerIds(): Array<String> { [controlId] }
}

private func toSceneSurface(surface: NativeSurfaceDescriptor): Scene3DHostSurface {
    Scene3DHostSurface(surface.id, sceneBackend(surface.backend), surface.opaqueHandle,
        surface.logicalWidth, surface.logicalHeight, surface.pixelWidth, surface.pixelHeight,
        surface.scale, surface.generation)
}

private func sceneBackend(backend: NativeSurfaceBackend): Scene3DBackend {
    match (backend) {
        case NativeSurfaceBackend.Metal => Scene3DBackend.Metal
        case NativeSurfaceBackend.Vulkan => Scene3DBackend.Vulkan
        case NativeSurfaceBackend.OpenGLES => Scene3DBackend.OpenGLES
        case NativeSurfaceBackend.Software => Scene3DBackend.Software
    }
}
