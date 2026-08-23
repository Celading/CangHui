package chui.scene3d

import std.collection.ArrayList

public let CANGHUI_SCENE3D_PROTOCOL = "canghui.scene3d.v0"

/** Renderer families understood by a Scene3D provider, without exposing engine handles. */
public enum Scene3DBackend <: Equatable<Scene3DBackend> {
    | Metal
    | Vulkan
    | OpenGLES
    | D3D11
    | D3D12
    | Software

    public operator func ==(other: Scene3DBackend): Bool {
        scene3dBackendName(this) == scene3dBackendName(other)
    }

    public operator func !=(other: Scene3DBackend): Bool {
        !(this == other)
    }
}

public func scene3dBackendName(backend: Scene3DBackend): String {
    match (backend) {
        case Scene3DBackend.Metal => "metal"
        case Scene3DBackend.Vulkan => "vulkan"
        case Scene3DBackend.OpenGLES => "opengles"
        case Scene3DBackend.D3D11 => "d3d11"
        case Scene3DBackend.D3D12 => "d3d12"
        case Scene3DBackend.Software => "software"
    }
}

/** Host surface identity for a 3D provider. Generation invalidates stale work. */
public struct Scene3DHostSurface {
    public let id: String
    public let backend: Scene3DBackend
    public let opaqueHandle: UInt64
    public let logicalWidth: Float32
    public let logicalHeight: Float32
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let scale: Float32
    public let generation: Int64

    public init(
        id: String,
        backend: Scene3DBackend,
        opaqueHandle: UInt64,
        logicalWidth: Float32,
        logicalHeight: Float32,
        pixelWidth: Int64,
        pixelHeight: Int64,
        scale: Float32,
        generation: Int64
    ) {
        if (id.isEmpty() || opaqueHandle == UInt64(0)) {
            throw IllegalArgumentException("scene3d surface identity and handle must be present")
        }
        if (logicalWidth <= 0.0 || logicalHeight <= 0.0 ||
            pixelWidth <= 0 || pixelHeight <= 0 || scale <= 0.0) {
            throw IllegalArgumentException("scene3d surface geometry must be positive")
        }
        if (generation <= 0) {
            throw IllegalArgumentException("scene3d surface generation must be positive")
        }
        this.id = id
        this.backend = backend
        this.opaqueHandle = opaqueHandle
        this.logicalWidth = logicalWidth
        this.logicalHeight = logicalHeight
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.scale = scale
        this.generation = generation
    }
}

/** One platform frame boundary. Providers must not create a competing clock. */
public struct Scene3DFrameClock {
    public let frameId: Int64
    public let timestampNanos: Int64
    public let targetTimestampNanos: Int64

    public init(frameId: Int64, timestampNanos: Int64, targetTimestampNanos: Int64) {
        if (frameId < 0 || timestampNanos < 0 || targetTimestampNanos < timestampNanos) {
            throw IllegalArgumentException("scene3d frame timing is invalid")
        }
        this.frameId = frameId
        this.timestampNanos = timestampNanos
        this.targetTimestampNanos = targetTimestampNanos
    }
}

/** Validated resource identity. Native handles remain private to a provider. */
public struct Scene3DResource {
    public let id: String
    public let uri: String
    public let checksum: String
    public let sizeBytes: Int64

    public init(id: String, uri: String, checksum: String, sizeBytes: Int64) {
        if (id.isEmpty() || uri.isEmpty() || checksum.isEmpty() || sizeBytes < 0) {
            throw IllegalArgumentException("scene3d resource identity and checksum are required")
        }
        this.id = id
        this.uri = uri
        this.checksum = checksum
        this.sizeBytes = sizeBytes
    }
}

/** Minimal immutable entity projection used by a provider for one frame. */
public struct Scene3DEntitySnapshot {
    public let id: String
    public let kind: Scene3DEntityKind
    public let x: Float32
    public let y: Float32
    public let z: Float32
    public let visible: Bool

    public init(
        id: String,
        x: Float32,
        y: Float32,
        z: Float32,
        visible!: Bool = true,
        kind!: Scene3DEntityKind = Scene3DEntityKind.Vehicle
    ) {
        if (id.isEmpty()) { throw IllegalArgumentException("scene3d entity id must be present") }
        this.id = id
        this.kind = kind
        this.x = x
        this.y = y
        this.z = z
        this.visible = visible
    }
}

/** Product-facing scene snapshot. It becomes immutable at the submit boundary. */
public class Scene3DFrameSnapshot {
    public let sceneId: String
    private let entities = ArrayList<Scene3DEntitySnapshot>()
    private var sealed = false

    public init(sceneId: String) {
        if (sceneId.isEmpty()) { throw IllegalArgumentException("scene3d scene id must be present") }
        this.sceneId = sceneId
    }

    public func add(entity: Scene3DEntitySnapshot): Unit {
        if (sealed) { throw IllegalStateException("scene3d snapshot is sealed") }
        entities.add(entity)
    }

    public func seal(): Unit { sealed = true }
    public func isSealed(): Bool { sealed }
    public func entityCount(): Int64 { entities.size }
    public func entityAt(index: Int64): Scene3DEntitySnapshot { entities[index] }
}

public struct Scene3DHitTestRequest {
    public let x: Float32
    public let y: Float32
    public let generation: Int64
    public let frameId: Int64

    public init(x: Float32, y: Float32, generation: Int64, frameId: Int64) {
        if (generation <= 0 || frameId < 0) {
            throw IllegalArgumentException("scene3d hit-test identity is invalid")
        }
        this.x = x
        this.y = y
        this.generation = generation
        this.frameId = frameId
    }
}

public struct Scene3DHitTestResult {
    public let hit: Bool
    public let entityId: String
    public let generation: Int64
    public let frameId: Int64

    public init(hit: Bool, entityId: String, generation: Int64, frameId: Int64) {
        if (hit && entityId.isEmpty()) {
            throw IllegalArgumentException("a scene3d hit must carry an entity id")
        }
        this.hit = hit
        this.entityId = entityId
        this.generation = generation
        this.frameId = frameId
    }

    public static func none(generation: Int64, frameId: Int64): Scene3DHitTestResult {
        Scene3DHitTestResult(false, "", generation, frameId)
    }
}

/** Structured lifecycle receipt shared by fake and native providers. */
public struct Scene3DReceipt {
    public let ok: Bool
    public let operation: String
    public let code: String
    public let generation: Int64
    public let frameId: Int64
    public let detail: String

    public init(
        ok: Bool,
        operation: String,
        code: String,
        generation: Int64,
        frameId: Int64,
        detail: String
    ) {
        this.ok = ok
        this.operation = operation
        this.code = code
        this.generation = generation
        this.frameId = frameId
        this.detail = detail
    }
}

/** Engine-neutral provider boundary. Implementations own all native resources. */
public interface Scene3DProvider {
    func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DReceipt
    func resize(surface: Scene3DHostSurface): Scene3DReceipt
    func loadScene(resource: Scene3DResource): Scene3DReceipt
    func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DReceipt
    func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult
    func present(clock: Scene3DFrameClock): Scene3DReceipt
    func detach(surfaceId: String, generation: Int64): Scene3DReceipt
}

/**
 * Deterministic F0 implementation. It validates the lifecycle and ordering
 * rules without opening a window or linking a renderer.
 */
public class FakeScene3DProvider <: Scene3DProvider {
    private var attached = false
    private var surfaceId = ""
    private var generation: Int64 = 0
    private var lastFrameId: Int64 = -1
    private var loadedResourceId = ""
    private var lastSceneId = ""

    public func attach(surface: Scene3DHostSurface, clock: Scene3DFrameClock): Scene3DReceipt {
        if (attached && (surface.id != surfaceId || surface.generation <= generation)) {
            return reject("attach", "stale-generation", surface.generation, clock.frameId)
        }
        attached = true
        surfaceId = surface.id
        generation = surface.generation
        lastFrameId = clock.frameId
        loadedResourceId = ""
        lastSceneId = ""
        Scene3DReceipt(true, "attach", "accepted", generation, clock.frameId, "fake surface attached")
    }

    public func resize(surface: Scene3DHostSurface): Scene3DReceipt {
        if (!matches(surface.id, surface.generation)) {
            return reject("resize", "stale-generation", surface.generation, lastFrameId)
        }
        Scene3DReceipt(true, "resize", "accepted", generation, lastFrameId, "fake surface resized")
    }

    public func loadScene(resource: Scene3DResource): Scene3DReceipt {
        if (!attached) { return reject("load-scene", "not-attached", generation, lastFrameId) }
        loadedResourceId = resource.id
        Scene3DReceipt(true, "load-scene", "accepted", generation, lastFrameId, "resource validated")
    }

    public func submit(snapshot: Scene3DFrameSnapshot, clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("submit", "not-attached", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("submit", "frame-regressed", generation, clock.frameId)
        }
        if (loadedResourceId.isEmpty()) {
            return reject("submit", "scene-not-loaded", generation, clock.frameId)
        }
        snapshot.seal()
        lastFrameId = clock.frameId
        lastSceneId = snapshot.sceneId
        Scene3DReceipt(true, "submit", "accepted", generation, clock.frameId, "snapshot accepted")
    }

    public func hitTest(request: Scene3DHitTestRequest): Scene3DHitTestResult {
        if (!matches(surfaceId, request.generation) || request.frameId != lastFrameId) {
            return Scene3DHitTestResult.none(request.generation, request.frameId)
        }
        Scene3DHitTestResult.none(request.generation, request.frameId)
    }

    public func present(clock: Scene3DFrameClock): Scene3DReceipt {
        if (!attached) { return reject("present", "not-attached", generation, clock.frameId) }
        if (clock.frameId < lastFrameId) {
            return reject("present", "frame-regressed", generation, clock.frameId)
        }
        lastFrameId = clock.frameId
        Scene3DReceipt(true, "present", "accepted", generation, clock.frameId, "fake frame presented")
    }

    public func detach(surfaceId: String, generation: Int64): Scene3DReceipt {
        if (!matches(surfaceId, generation)) {
            return reject("detach", "stale-generation", generation, lastFrameId)
        }
        attached = false
        this.surfaceId = ""
        this.generation = 0
        loadedResourceId = ""
        lastSceneId = ""
        Scene3DReceipt(true, "detach", "accepted", generation, lastFrameId, "fake surface detached")
    }

    public func isAttached(): Bool { attached }
    public func currentGeneration(): Int64 { generation }
    public func currentSceneId(): String { lastSceneId }

    private func matches(id: String, value: Int64): Bool {
        attached && id == surfaceId && value == generation
    }

    private func reject(operation: String, code: String, value: Int64, frameId: Int64): Scene3DReceipt {
        Scene3DReceipt(false, operation, code, value, frameId, "fake provider rejected request")
    }
}
