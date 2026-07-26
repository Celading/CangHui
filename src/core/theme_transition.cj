package cui.core

import std.math.sqrt
import sdl.{Rect, Renderer, Texture}

/** Pointer-origin theme transition composed from frozen old/new interface frames. */
public class ThemeTransition {
    private let fromTheme: Theme
    private let toTheme: Theme
    private let originX: Float32
    private let originY: Float32
    private let durationMs: UInt64
    private var elapsedMs: UInt64 = UInt64(0)
    private var oldFrame: ?Texture = None
    private var newFrame: ?Texture = None
    private var snapshotWidth: Float32 = 0.0
    private var snapshotHeight: Float32 = 0.0

    public init(fromTheme: Theme, toTheme: Theme, originX: Float32, originY: Float32,
        durationMs!: UInt64 = UInt64(560)) {
        if (durationMs == UInt64(0)) {
            throw IllegalArgumentException("theme transition duration must be positive")
        }
        this.fromTheme = fromTheme
        this.toTheme = toTheme
        this.originX = originX
        this.originY = originY
        this.durationMs = durationMs
    }

    public func progress(): Float32 {
        Float32(elapsedMs) / Float32(durationMs)
    }

    public func easedProgress(): Float32 {
        let p = progress()
        let remaining = 1.0 - p
        1.0 - remaining * remaining * remaining
    }

    public func currentTheme(): Theme {
        fromTheme.lerp(toTheme, easedProgress())
    }

    public func advance(deltaMs: UInt64): Theme {
        elapsedMs = min(durationMs, elapsedMs + deltaMs)
        currentTheme()
    }

    public func isComplete(): Bool {
        elapsedMs >= durationMs
    }

    public func sourceTheme(): Theme {
        fromTheme
    }

    public func targetTheme(): Theme {
        toTheme
    }

    /**
     * Captures one side per frame: the click frame freezes the old tree, and the
     * following rebuilt frame freezes the new tree. This preserves stateful icon and
     * content changes instead of rendering both themes from one stale widget tree.
     */
    public func prepareNextSnapshot(
        renderer: Renderer,
        width: Float32,
        height: Float32,
        renderOld: () -> Unit,
        renderNew: () -> Unit
    ): Bool {
        if (!sameSnapshotSize(width, height)) {
            closeSnapshots()
        }
        if (oldFrame.isNone()) {
            let texture = renderer.createTargetTexture(width, height)
            try {
                renderer.renderToTexture(texture, width, height, fromTheme.bg, renderOld)
                oldFrame = Some(texture)
                snapshotWidth = width
                snapshotHeight = height
            } catch (error: Exception) {
                texture.close()
                throw error
            }
            return false
        }
        if (newFrame.isNone()) {
            let texture = renderer.createTargetTexture(width, height)
            try {
                renderer.renderToTexture(texture, width, height, toTheme.bg, renderNew)
                newFrame = Some(texture)
            } catch (error: Exception) {
                texture.close()
                throw error
            }
        }
        snapshotsReady()
    }

    /** Draws the frozen old frame, then reveals the new frame through a growing circle. */
    public func draw(renderer: Renderer, width: Float32, height: Float32): Unit {
        match ((oldFrame, newFrame)) {
            case (Some(oldTexture), Some(newTexture)) =>
                let frame = Rect(0.0, 0.0, width, height)
                renderer.texture(oldTexture, frame)
                let opacity = progress()
                renderer.texturedCircle(newTexture, originX, originY, revealRadius(width, height), width, height,
                    feather: 1.4, opacity: opacity)
            case (Some(oldTexture), None) =>
                renderer.texture(oldTexture, Rect(0.0, 0.0, width, height))
            case _ => ()
        }
    }

    public func revealRadius(width: Float32, height: Float32): Float32 {
        farthestCornerRadius(width, height) * easedProgress()
    }

    public func close(): Unit {
        closeSnapshots()
    }

    public func snapshotsReady(): Bool {
        oldFrame.isSome() && newFrame.isSome()
    }

    private func sameSnapshotSize(width: Float32, height: Float32): Bool {
        oldFrame.isNone() || (snapshotWidth == width && snapshotHeight == height)
    }

    private func closeSnapshots(): Unit {
        match (oldFrame) {
            case Some(texture) => texture.close()
            case None => ()
        }
        match (newFrame) {
            case Some(texture) => texture.close()
            case None => ()
        }
        oldFrame = None
        newFrame = None
        snapshotWidth = 0.0
        snapshotHeight = 0.0
    }

    private func farthestCornerRadius(width: Float32, height: Float32): Float32 {
        let left = max(0.0, originX)
        let right = max(0.0, width - originX)
        let top = max(0.0, originY)
        let bottom = max(0.0, height - originY)
        let dx = max(left, right)
        let dy = max(top, bottom)
        Float32(sqrt(Float64(dx * dx + dy * dy))) + 2.0
    }
}
