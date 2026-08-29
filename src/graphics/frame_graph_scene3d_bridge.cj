package chui.graphics

/** Explicit Scene3D ingress truth; a native child surface is a barrier, not unified pixels. */
protected class Scene3DFrameGraphBridge {
    public let ok: Bool
    public let code: String
    public let unifiedPixels: Bool
    public let clipOcclusionUnified: Bool
    private let resourceValue: ?FrameResourceDescriptor
    private let passValue: ?FramePassDescriptor

    init(
        ok: Bool,
        code: String,
        unifiedPixels: Bool,
        clipOcclusionUnified: Bool,
        resource: ?FrameResourceDescriptor,
        pass: ?FramePassDescriptor
    ) {
        this.ok = ok
        this.code = code
        this.unifiedPixels = unifiedPixels
        this.clipOcclusionUnified = clipOcclusionUnified
        this.resourceValue = resource
        this.passValue = pass
    }

    public func resource(): ?FrameResourceDescriptor { resourceValue }
    public func pass(): ?FramePassDescriptor { passValue }
}

/**
 * Creates only scheduling metadata. Scene3D provider lifecycle, focus, pointer, keyboard and
 * gamepad routing remain owned by Scene3D; no native surface token enters this graph.
 */
protected func bridgeScene3DExternalSurface(
    viewIdentity: String,
    generation: Int64,
    declarationOrder: Int64,
    mode: FrameExternalMode,
    providerProvedSharedTexture!: Bool = false,
    bounds!: ?FrameDamageRect = None,
    damage!: DamageRegion = DamageRegion.full()
): Scene3DFrameGraphBridge {
    if (viewIdentity.isEmpty() || generation <= 0 || declarationOrder < 0) {
        return Scene3DFrameGraphBridge(
            false, "invalid-scene3d-identity", false, false, None, None)
    }
    if (mode == FrameExternalMode.NoExternalSurface) {
        return Scene3DFrameGraphBridge(
            false, "scene3d-external-mode-required", false, false, None, None)
    }
    if (mode == FrameExternalMode.SharedTexture && !providerProvedSharedTexture) {
        return Scene3DFrameGraphBridge(
            false, "shared-texture-unproven", false, false, None, None)
    }

    let token = scene3DFrameStableToken(viewIdentity)
    let resourceId = FrameResourceId("scene3d.resource.${token}", generation)
    let resourceKind = if (mode == FrameExternalMode.SharedTexture) {
        FrameResourceKind.Texture
    } else {
        FrameResourceKind.ExternalSurface
    }
    let resource = FrameResourceDescriptor(
        resourceId, resourceKind, FrameResourceLifetime.Imported)
    let pass = FramePassDescriptor(
        FramePassId("scene3d.barrier.${token}"),
        declarationOrder,
        FramePassKind.ExternalScene3D,
        reads: [resourceId],
        bounds: bounds,
        declaredDamage: damage,
        stableInputCode: generation,
        canCull: false,
        externalMode: mode
    )
    let unified = mode == FrameExternalMode.SharedTexture
    Scene3DFrameGraphBridge(
        true,
        if (unified) { "shared-texture-proved" } else { "native-child-surface-barrier" },
        unified,
        unified,
        Some(resource),
        Some(pass)
    )
}

private func scene3DFrameStableToken(value: String): String {
    var code: Int64 = 23
    for (byte in value.toArray()) {
        code = (code * 137 + Int64(byte)) % 2147483647
    }
    code.toString()
}
