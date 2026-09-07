package sdl

import std.math.abs

foreign {
    func SDL_GetRenderScale(renderer: CPointer<Unit>, sx: CPointer<Float32>,
        sy: CPointer<Float32>): Bool
    func SDL_ReadSurfacePixel(surface: CPointer<Unit>, x: Int32, y: Int32,
        red: CPointer<UInt8>, green: CPointer<UInt8>, blue: CPointer<UInt8>,
        alpha: CPointer<UInt8>): Bool
}

private func textScaleInkBounds(renderer: Renderer): Rect {
    let surface = unsafe { SDL_RenderReadPixels(renderer.ptr, CPointer<SdlRect>()) }
    ensureSdl(surface.isNotNull(), "text scale readback")
    var left: Int32 = 720
    var top: Int32 = 240
    var right: Int32 = -1
    var bottom: Int32 = -1
    try {
        for (y in 0..240) {
            for (x in 0..720) {
                var red: UInt8 = 0
                var green: UInt8 = 0
                var blue: UInt8 = 0
                var alpha: UInt8 = 0
                ensureSdl(unsafe { SDL_ReadSurfacePixel(surface, Int32(x), Int32(y),
                    inout red, inout green, inout blue, inout alpha) }, "text scale pixel")
                if (red > 180 && green > 180 && blue > 180) {
                    left = min(left, Int32(x))
                    top = min(top, Int32(y))
                    right = max(right, Int32(x))
                    bottom = max(bottom, Int32(y))
                }
            }
        }
    } finally {
        unsafe { SDL_DestroySurface(surface) }
    }
    Rect(Float32(left), Float32(top), Float32(max(0, right - left + 1)),
        Float32(max(0, bottom - top + 1)))
}

private func drawScaledInk(renderer: Renderer, target: Texture, sx: Float32,
    sy: Float32, clipped: Bool): Rect {
    let bounds = [Rect(0.0, 0.0, 0.0, 0.0)]
    let logicalWidth = renderer.textWidth("MW仓绘", pointSize: 24.0)
    renderer.renderToTexture(target, 720.0 / sx, 240.0 / sy, Color.rgb(0, 0, 0)) {
        let measuredWidth = renderer.textWidth("MW仓绘", pointSize: 24.0)
        // Rendering into a non-uniform target must not halve/double layout advances.
        @Expect(abs(measuredWidth - logicalWidth) <= 3.0)
        if (clipped) { renderer.pushClip(Rect(10.0, 10.0, 25.0, 70.0)) }
        renderer.text("MW仓绘", 10.0, 10.0, Color.rgb(255, 255, 255), pointSize: 24.0)
        @Expect(renderer.currentScaleX(), sx)
        @Expect(renderer.currentScaleY(), sy)
        var actualX: Float32 = 0.0
        var actualY: Float32 = 0.0
        ensureSdl(unsafe { SDL_GetRenderScale(renderer.ptr, inout actualX, inout actualY) },
            "text scale restoration")
        @Expect(actualX, sx)
        @Expect(actualY, sy)
        if (clipped) {
            @Expect(renderer.clipRect().x, Float32(10.0))
            @Expect(renderer.clipRect().w, Float32(25.0))
        }
        bounds[0] = textScaleInkBounds(renderer)
        @Expect(bounds[0].x + bounds[0].w <= (10.0 + measuredWidth) * sx + 2.0)
        if (clipped) { renderer.popClip() }
    }
    bounds[0]
}

@Test
func nativeTextRespectsBothTargetScaleAxes(): Unit {
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("Text scale regression", 720, 240, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        let target = r.createTargetTexture(720.0, 240.0)
        try {
            let base = drawScaledInk(r, target, 1.0, 1.0, false)
            @Expect(base.w > 50.0 && base.h > 10.0)
            for ((sx, sy) in [(Float32(2.0), Float32(1.0)), (Float32(1.0), Float32(2.0)),
                    (Float32(0.75), Float32(1.5)), (Float32(1.5), Float32(0.75))]) {
                let scaled = drawScaledInk(r, target, sx, sy, false)
                println("text-ink scale=${sx},${sy} base=${base.w},${base.h} actual=${scaled.w},${scaled.h}")
                @Expect(abs(scaled.w - base.w * sx) <= 5.0)
                @Expect(abs(scaled.h - base.h * sy) <= 4.0)
            }
        } finally { target.close() }
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearBundledFallbackOverride()
    }
}

@Test
func nativeTextClipStaysInTargetCoordinatesWithUnequalScales(): Unit {
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("Text scale clip", 720, 240, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        let target = r.createTargetTexture(720.0, 240.0)
        try {
            for ((sx, sy) in [(Float32(2.0), Float32(1.0)), (Float32(0.75), Float32(1.5))]) {
                let ink = drawScaledInk(r, target, sx, sy, true)
                @Expect(ink.w > 5.0)
                @Expect(ink.x >= 10.0 * sx - 1.0)
                @Expect(ink.x + ink.w <= 35.0 * sx + 1.0)
                @Expect(ink.y >= 10.0 * sy - 1.0)
            }
        } finally { target.close() }
    } finally {
        window.close()
        Fonts.clear()
        Fonts.clearBundledFallbackOverride()
    }
}

@When[os == "macOS"]
@Test
func platformTextScaleAndClipUseTheSameNativeLineMetrics(): Unit {
    Fonts.clear()
    Fonts.registerBundledFallback(bundledFontFixture())
    let window = SdlWindow(WindowSpec("CoreText scale clip", 720, 240, supersample: 1))
    try {
        let r = window.renderer
        r.setScale(1.0)
        @Expect(r.usePlatformTextLayout(true))
        let target = r.createTargetTexture(720.0, 240.0)
        try {
            let base = drawScaledInk(r, target, 1.0, 1.0, false)
            @Expect(base.w > 50.0 && base.h > 10.0)
            for ((sx, sy) in [(Float32(2.0), Float32(1.0)), (Float32(1.0), Float32(2.0)),
                    (Float32(0.75), Float32(1.5)), (Float32(1.5), Float32(0.75))]) {
                let scaled = drawScaledInk(r, target, sx, sy, false)
                @Expect(abs(scaled.w - base.w * sx) <= 5.0)
                @Expect(abs(scaled.h - base.h * sy) <= 4.0)
                let clipped = drawScaledInk(r, target, sx, sy, true)
                @Expect(clipped.w > 5.0)
                @Expect(clipped.x >= 10.0 * sx - 1.0)
                @Expect(clipped.x + clipped.w <= 35.0 * sx + 1.0)
                @Expect(clipped.y >= 10.0 * sy - 1.0)
            }
        } finally { target.close() }
    } finally {
        window.close(); Fonts.clear(); Fonts.clearBundledFallbackOverride()
    }
}
