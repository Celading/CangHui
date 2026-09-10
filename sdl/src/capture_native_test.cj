package sdl

@Test
func headlessCaptureKeepsPublicNoOpAndRejectsNativeSurfaceRequest(): Unit {
    let renderer = Renderer.headless()
    renderer.captureBmp("")
    var rejected = false
    try { renderer.captureSurface() }
    catch (_: CuiException) { rejected = true }
    @Expect(rejected)
}

@When[os == "macOS"]
@Test
func captureSurfaceOwnsPixelsAndClosesAfterSaveFailure(): Unit {
    let window = SdlWindow(WindowSpec("Capture ownership", 64, 40, supersample: 1))
    try {
        let renderer = window.renderer
        renderer.setScale(1.0)
        let target = renderer.createTargetTexture(32.0, 20.0)
        try {
            renderer.renderToTexture(target, 32.0, 20.0, Color.rgb(12, 34, 56)) {
                let owned = renderer.captureSurface()
                var failed = false
                try {
                    try (surface = owned) {
                        var red: UInt8 = 0
                        var green: UInt8 = 0
                        var blue: UInt8 = 0
                        var alpha: UInt8 = 0
                        @Expect(unsafe { SDL_ReadSurfacePixel(surface.ptr, 10, 10,
                            inout red, inout green, inout blue, inout alpha) })
                        @Expect(red, UInt8(12))
                        @Expect(green, UInt8(34))
                        @Expect(blue, UInt8(56))
                        @Expect(alpha, UInt8(255))
                        surface.saveBmp("")
                    }
                } catch (_: CuiException) { failed = true }
                @Expect(failed)
                @Expect(owned.isClosed())
                owned.close()
                var publicFailed = false
                try { renderer.captureBmp("") }
                catch (_: CuiException) { publicFailed = true }
                @Expect(publicFailed)
                try (next = renderer.captureSurface()) { @Expect(!next.isClosed()) }
            }
        } finally { target.close() }
    } finally { window.close() }
}
