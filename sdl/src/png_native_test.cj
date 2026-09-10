package sdl

import std.fs.{File, canonicalize, exists, removeIfExists}

@Test
func nativePngRoundtripPreservesRgbaAndFailedSaveDoesNotCloseSurface(): Unit {
    let path = canonicalize(".").toString() + "/target/native-surface-roundtrip.png"
    if (exists(path)) { throw CuiException("PNG test output already exists") }
    try {
        try (surface = Surface.create(2, 2)) {
            surface.clear(Color.rgb(12, 34, 56))
            surface.writePixel(1, 0, Color.rgba(90, 80, 70, 64))
            var rejected = false
            try { surface.savePng("") } catch (_: CuiException) { rejected = true }
            @Expect(rejected)
            @Expect(!surface.isClosed())
            surface.savePng(path)
        }
        let bytes = File.readFrom(path)
        @Expect(bytes[0], UInt8(137))
        @Expect(bytes[1], UInt8(80))
        try (loaded = Surface.loadPng(path)) {
            var red: UInt8 = 0
            var green: UInt8 = 0
            var blue: UInt8 = 0
            var alpha: UInt8 = 0
            @Expect(unsafe { SDL_ReadSurfacePixel(loaded.ptr, 1, 0,
                inout red, inout green, inout blue, inout alpha) })
            @Expect(red, UInt8(90))
            @Expect(green, UInt8(80))
            @Expect(blue, UInt8(70))
            @Expect(alpha, UInt8(64))
        }
    } finally { removeIfExists(path) }
}

@Test
func closedSurfaceRejectsPngAndHeadlessCaptureDoesNotWrite(): Unit {
    let surface = Surface.create(1, 1)
    surface.close()
    var rejected = false
    try { surface.savePng("") } catch (_: CuiException) { rejected = true }
    @Expect(rejected)
    Renderer.headless().capturePng("")
}
