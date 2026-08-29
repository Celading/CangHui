package chui.core

import sdl.Rect

/** Internal, handle-free scheduling fact emitted by a native child-surface widget during layout. */
protected struct NativeChildFrameSurface {
    public let identity: String
    public let generation: Int64
    public let bounds: Rect

    public init(identity: String, generation: Int64, bounds: Rect) {
        this.identity = identity
        this.generation = generation
        this.bounds = bounds
    }
}
