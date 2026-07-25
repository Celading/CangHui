package cui.core

import std.math.sqrt
import sdl.{Pen, Renderer}

/** Pointer-origin theme transition with an expanding InkWell-like wash. */
public class ThemeTransition {
    private let fromTheme: Theme
    private let toTheme: Theme
    private let originX: Float32
    private let originY: Float32
    private let durationMs: UInt64
    private var elapsedMs: UInt64 = UInt64(0)

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

    /** Draws a fading radial wash over the already interpolated widget tree. */
    public func draw(renderer: Renderer, width: Float32, height: Float32): Unit {
        let p = easedProgress()
        let radius = farthestCornerRadius(width, height) * p
        let fade = max(0.0, 1.0 - progress())
        let washAlpha = Int64(58.0 * fade)
        let ringAlpha = Int64(150.0 * fade)
        if (radius > 0.0 && washAlpha > 0) {
            renderer.fillCircle(originX, originY, radius, toTheme.accentSoft.withAlpha(washAlpha))
        }
        if (radius > 1.0 && ringAlpha > 0) {
            renderer.strokeCircle(originX, originY, radius,
                Pen(width: 2.0, color: toTheme.accent.withAlpha(ringAlpha)), segments: 96)
        }
    }

    private func farthestCornerRadius(width: Float32, height: Float32): Float32 {
        let left = max(0.0, originX)
        let right = max(0.0, width - originX)
        let top = max(0.0, originY)
        let bottom = max(0.0, height - originY)
        let dx = max(left, right)
        let dy = max(top, bottom)
        Float32(sqrt(Float64(dx * dx + dy * dy)))
    }
}
