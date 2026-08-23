package canghui_scene3d_bgfx

import chui.scene3d.*
import bgfx4cj.bgfx.*

/**
 * Minimal bgfx4cj driver. The platform host injects the native window pointer;
 * CangHui surface ids and generations remain serializable protocol data.
 */
public class Bgfx4cjDriver <: Scene3DDriver {
    private let nativeWindow: CPointer<Unit>
    private let nativeWindowIdentity: UInt64
    private var initialized = false
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var resourceId = ""
    private var sceneId = ""
    private var lastFrameId: Int64 = -1
    private var pixelWidth: Int64 = 0
    private var pixelHeight: Int64 = 0
    private let clearColor: UInt32

    public init(
        nativeWindow: CPointer<Unit>,
        nativeWindowIdentity: UInt64,
        clearColor!: UInt32 = 0x20242AFF
    ) {
        if (nativeWindow.isNull() || nativeWindowIdentity == UInt64(0)) {
            throw IllegalArgumentException("bgfx4cj native window pointer and identity must be present")
        }
        this.nativeWindow = nativeWindow
        this.nativeWindowIdentity = nativeWindowIdentity
        this.clearColor = clearColor
    }

    public func driverName(): String { "bgfx4cj" }

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DDriverResult {
        if (initialized) {
            return Scene3DDriverResult.rejected("already-attached", "bgfx is already initialized")
        }
        if (surface.opaqueHandle != nativeWindowIdentity) {
            return Scene3DDriverResult.rejected(
                "surface-handle-mismatch", "injected native window does not match the host surface identity"
            )
        }
        let initPtr = unsafe { LibC.malloc<Init>() }
        unsafe { initPtr.write(Init()) }
        bgfx_init_ctor_cj(initPtr)

        var params = unsafe { initPtr.read() }
        params.`type` = rendererFor(surface.backend).value()
        params.platformData.nwh = nativeWindow
        params.resolution.width = UInt32(surface.pixelWidth)
        params.resolution.height = UInt32(surface.pixelHeight)
        params.resolution.reset = RESET_VSYNC
        params.resolution.numBackBuffers = 2
        params.resolution.maxFrameLatency = 2
        params.resolution.debugTextScale = 1
        unsafe { initPtr.write(params) }

        if (surface.backend == Scene3DBackend.Metal) {
            let _ = bgfx_render_frame_cj(0)
        }
        let ok = bgfx_init_cj(initPtr)
        unsafe { LibC.free(initPtr) }
        if (!ok) {
            return Scene3DDriverResult.rejected("bgfx-init-failed", "bgfx_init returned false")
        }
        initialized = true
        surfaceId = surface.id
        generation = surface.generation
        pixelWidth = surface.pixelWidth
        pixelHeight = surface.pixelHeight
        resourceId = ""
        sceneId = ""
        lastFrameId = clock.frameId
        bgfx_set_view_clear_cj(0, CLEAR_COLOR, clearColor, 1.0, 0)
        setViewRect()
        Scene3DDriverResult.accepted(detail: "bgfx initialized")
    }

    public func resize(surface: Scene3DHostSurface): Scene3DDriverResult {
        if (!matches(surface.generation)) {
            return Scene3DDriverResult.rejected("stale-generation", "bgfx resize generation mismatch")
        }
        bgfx_reset_cj(UInt32(surface.pixelWidth), UInt32(surface.pixelHeight), RESET_VSYNC, 0)
        pixelWidth = surface.pixelWidth
        pixelHeight = surface.pixelHeight
        setViewRect()
        Scene3DDriverResult.accepted(detail: "bgfx backbuffer reset")
    }

    public func loadScene(resource: Scene3DResource): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        resourceId = resource.id
        Scene3DDriverResult(
            true, "metadata-staged", "resource metadata staged; native upload is not yet implemented"
        )
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DDriverResult {
        if (!initialized || resourceId.isEmpty()) {
            return Scene3DDriverResult.rejected("scene-not-ready", "bgfx scene metadata is not ready")
        }
        sceneId = snapshot.sceneId
        lastFrameId = clock.frameId
        setViewRect()
        bgfx_touch_cj(0)
        Scene3DDriverResult(
            true, "clear-frame-only", "bgfx clear-frame commands submitted; geometry upload is not implemented"
        )
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        Scene3DHitTestResult.none(request.generation, request.frameId)
    }

    public func present(clock: Scene3DFrameClock): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        lastFrameId = clock.frameId
        let _ = bgfx_frame_cj(false)
        Scene3DDriverResult.accepted(detail: "bgfx frame advanced")
    }

    /** Requests the current backbuffer. bgfx writes a TGA beside the requested path. */
    public func requestBackbufferCapture(path: String): Scene3DDriverResult {
        if (!initialized) {
            return Scene3DDriverResult.rejected("not-attached", "bgfx is not initialized")
        }
        if (path.isEmpty()) {
            return Scene3DDriverResult.rejected("capture-path-missing", "capture path must not be empty")
        }
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            bgfx_request_screen_shot_cj(FrameBufferHandle(), pathResource.value)
        }
        Scene3DDriverResult.accepted(detail: "bgfx backbuffer capture requested")
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DDriverResult {
        if (surfaceId != this.surfaceId || !matches(generation)) {
            return Scene3DDriverResult.rejected("stale-generation", "bgfx detach generation mismatch")
        }
        bgfx_shutdown_cj()
        initialized = false
        this.surfaceId = ""
        this.generation = 0
        resourceId = ""
        sceneId = ""
        lastFrameId = -1
        pixelWidth = 0
        pixelHeight = 0
        Scene3DDriverResult.accepted(detail: "bgfx shut down")
    }

    public func isInitialized(): Bool { initialized }

    private func matches(value: Int64): Bool {
        initialized && value == generation
    }

    private func rendererFor(backend: Scene3DBackend): RendererType {
        match (backend) {
            case Scene3DBackend.Metal => RendererType.Metal
            case Scene3DBackend.Vulkan => RendererType.Vulkan
            case Scene3DBackend.OpenGLES => RendererType.OpenGLES
            case Scene3DBackend.D3D11 => RendererType.Direct3D11
            case Scene3DBackend.D3D12 => RendererType.Direct3D12
            case Scene3DBackend.Software => RendererType.Noop
        }
    }

    private func setViewRect(): Unit {
        bgfx_set_view_rect_cj(0, 0, 0, UInt16(pixelWidth), UInt16(pixelHeight))
    }
}

public func createBgfxScene3DProvider(
    nativeWindow: CPointer<Unit>,
    nativeWindowIdentity: UInt64,
    clearColor!: UInt32 = 0x20242AFF
): DriverScene3DProvider {
    DriverScene3DProvider(Bgfx4cjDriver(nativeWindow, nativeWindowIdentity, clearColor: clearColor))
}
