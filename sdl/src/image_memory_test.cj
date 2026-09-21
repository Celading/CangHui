package sdl

import std.fs.{Directory, File, removeIfExists}

foreign { func SDL_GetTicksNS(): UInt64 }
private class PerformanceClock {
    static func ticksNanoseconds(): UInt64 { unsafe { SDL_GetTicksNS() } }
}

private func expectImageFailure(action: () -> Unit, fragment: String): Unit {
    var rejected = false
    try { action() } catch (error: CuiException) { rejected = error.message.contains(fragment) }
    @Expect(rejected)
}

private func pngBudgetHeader(width: UInt32, height: UInt32): Array<UInt8> {
    let bytes = Array<UInt8>(33, {_ => UInt8(0)})
    let start: Array<UInt8> = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82]
    for (i in 0..start.size) { bytes[i] = start[i] }
    for (i in 0..4) {
        bytes[16 + i] = UInt8((width >> UInt32((3 - i) * 8)) & 255)
        bytes[20 + i] = UInt8((height >> UInt32((3 - i) * 8)) & 255)
    }
    bytes
}

@Test
func imageBudgetAccepts4KAndRejects8KBeforeAllocation(): Unit {
    @Expect(imageTextureBytes(3840, 2160, 6 * 1024 * 1024), Int64(33177600))
    expectImageFailure({=> let _ = imageTextureBytes(7680, 4320, 100)}, "pixel limit")
    let expanded = ImageMemoryOptions(maxPixels: 40000000, maxWorkingBytes: 600000000)
    @Expect(imageTextureBytes(7680, 4320, 100, options: expanded), Int64(132710400))
}

@Test
func imageBudgetRejectsOverflowNegativeAndEncodedBoundaries(): Unit {
    expectImageFailure({=> let _ = imageTextureBytes(Int64.Max, 2, 10)}, "dimensions")
    expectImageFailure({=> let _ = imageTextureBytes(1, 0, 10)}, "dimensions")
    expectImageFailure({=> let _ = imageTextureBytes(-1, 1, 10)}, "dimensions")
    expectImageFailure({=> let _ = imageTextureBytes(1, 1, 0)}, "encoded")
    expectImageFailure({=> let _ = imageTextureBytes(1, 1, 67108865)}, "encoded")
    let wide = ImageMemoryOptions(maxPixels: Int64.Max, maxWorkingBytes: Int64.Max)
    expectImageFailure({=> let _ = imageTextureBytes(2147483647, 2147483647, 1, options: wide)}, "pixel limit")
}

@Test
func imageBudgetWorkingBytesUseCheckedExactBoundary(): Unit {
    let exact = ImageMemoryOptions(maxEncodedBytes: 100, maxWorkingBytes: 116)
    @Expect(imageTextureBytes(1, 1, 100, options: exact), Int64(4))
    expectImageFailure({=> let _ = imageTextureBytes(1, 2, 100, options: exact)}, "working")
    let tiny = ImageMemoryOptions(maxWorkingBytes: 10)
    expectImageFailure({=> let _ = imageTextureBytes(1, 1, 11, options: tiny)}, "working")
}

@Test
func imageBudgetOptionsRejectUnboundedMetadataAndInvalidLimits(): Unit {
    expectImageFailure({=> let _ = ImageMemoryOptions(cacheEntries: 0)}, "options")
    expectImageFailure({=> let _ = ImageMemoryOptions(cacheEntries: 4097)}, "options")
    expectImageFailure({=> let _ = ImageMemoryOptions(cacheBytes: 0)}, "options")
    expectImageFailure({=> let _ = ImageMemoryOptions(maxWorkingBytes: -1)}, "options")
    expectImageFailure({=> trimImageMemory(-1)}, "negative")
}

@Test
func imageBudgetPngHeaderChecksSignatureIhdrTruncationAndDimensions(): Unit {
    let options = ImageMemoryOptions()
    let good = pngBudgetHeader(3840, 2160)
    @Expect(imageHeaderTextureBytes(good, ImageFileFormat.Png, 100, options), Int64(33177600))
    expectImageFailure({=> let _ = imageHeaderTextureBytes([1, 2], ImageFileFormat.Png, 100, options)}, "truncated")
    good[0] = 0
    expectImageFailure({=> let _ = imageHeaderTextureBytes(good, ImageFileFormat.Png, 100, options)}, "signature")
    good[0] = 137; good[15] = 0
    expectImageFailure({=> let _ = imageHeaderTextureBytes(good, ImageFileFormat.Png, 100, options)}, "IHDR")
    expectImageFailure({=> let _ = imageHeaderTextureBytes(pngBudgetHeader(0, 1),
        ImageFileFormat.Png, 100, options)}, "dimensions")
    expectImageFailure({=> let _ = imageHeaderTextureBytes(pngBudgetHeader(UInt32.Max, UInt32.Max),
        ImageFileFormat.Png, 100, options)}, "dimensions")
}

@Test
func imageBudgetBmpSupportsCoreAndSignedTopDownHeight(): Unit {
    let options = ImageMemoryOptions()
    let header = Array<UInt8>(54, {_ => UInt8(0)})
    header[0] = 66; header[1] = 77; header[14] = 12
    header[18] = 2; header[20] = 3
    @Expect(imageHeaderTextureBytes(header, ImageFileFormat.Bmp, 100, options), Int64(24))
    header[14] = 40; header[20] = 0
    header[22] = 253; header[23] = 255; header[24] = 255; header[25] = 255
    @Expect(imageHeaderTextureBytes(header, ImageFileFormat.Bmp, 100, options), Int64(24))
    header[18] = 255; header[19] = 255; header[20] = 255; header[21] = 255
    expectImageFailure({=> let _ = imageHeaderTextureBytes(header, ImageFileFormat.Bmp, 100, options)}, "dimensions")
    header[14] = 99
    expectImageFailure({=> let _ = imageHeaderTextureBytes(header, ImageFileFormat.Bmp, 100, options)}, "unsupported")
}

@Test
func imageBudgetStreamingPitchDoesNotOverflowInt32(): Unit {
    let pixel = unsafe { LibC.malloc<UInt8>() }
    try (resource = pixel.asResource()) {
        expectImageFailure({=> validateStreamingPixels(resource.value, Int32.Max, Int32.Max)}, "pitch")
    }
}

@Test
func imageBudgetHeadlessDoesNotRegisterOrDecode(): Unit {
    let before = imageMemoryStats()
    let renderer = Renderer.headless()
    @Expect(renderer.cachedImage("not-an-image.png").isNone())
    @Expect(imageMemoryStats().renderers, before.renderers)
    renderer.releaseResources()
    @Expect(renderer.cachedImage("not-an-image.png").isNone())
}

@When[os == "macOS"]
@Test
func imageBudgetNativeCacheLruFailureBoundsAndTwoWindowRelease(): Unit {
    let base = "target/image-budget-cache-test"
    Directory.create(base, recursive: true)
    let paths = [base + "/a.png", base + "/b.bmp", base + "/c.png"]
    let oldOptions = currentImageMemoryOptions()
    let before = imageMemoryStats().renderers
    let first = SdlWindow(WindowSpec("Image memory test", 32, 32, supersample: 1))
    let second = SdlWindow(WindowSpec("Image memory second", 32, 32, supersample: 1))
    try {
        try (surface = Surface.create(16, 16)) {
            surface.clear(Color.rgb(12, 34, 56))
            surface.savePng(paths[0]); surface.saveBmp(paths[1]); surface.savePng(paths[2])
        }
        configureImageMemory(ImageMemoryOptions(cacheBytes: 2048, cacheEntries: 3))
        let a = first.renderer.cachedImage(paths[0]).getOrThrow()
        let b = first.renderer.cachedImage(paths[1]).getOrThrow()
        @Expect(refEq(a, first.renderer.cachedImage(paths[0]).getOrThrow()))
        let c = first.renderer.cachedImage(paths[2]).getOrThrow()
        @Expect(b.isClosed())
        @Expect(!a.isClosed() && !c.isClosed())
        @Expect(imageMemoryStats().textureBytes, Int64(2048))
        @Expect(imageMemoryStats().evictions >= 1)
        let other = second.renderer.cachedImage(paths[0]).getOrThrow()
        @Expect(!refEq(a, other))
        @Expect(imageMemoryStats().renderers, before + 2)
        @Expect(refEq(a, first.renderer.cachedImage(paths[0]).getOrThrow()))
        invalidateCachedImage(paths[0])
        @Expect(a.isClosed() && other.isClosed())
        for (i in 0..100) { let _ = first.renderer.cachedImage(base + "/missing-${i}.png") }
        @Expect(imageMemoryStats().entries <= 3)
        let misses = imageMemoryStats().misses
        @Expect(first.renderer.cachedImage(base + "/missing-99.png").isNone())
        @Expect(imageMemoryStats().misses, misses)
        configureImageMemory(ImageMemoryOptions(cacheBytes: 16))
        @Expect(first.renderer.cachedImage(paths[0]).isNone())
        @Expect(imageMemoryStats().budgetRejections >= 1)
        @Expect(imageMemoryStats().textureBytes, Int64(0))
        configureImageMemory(ImageMemoryOptions(cacheBytes: 2048))
        let reload = first.renderer.cachedImage(paths[0]).getOrThrow()
        trimImageMemory(0)
        @Expect(reload.isClosed())
        let survivor = second.renderer.cachedImage(paths[1]).getOrThrow()
        let retiring = first.renderer.cachedImage(paths[0]).getOrThrow()
        first.close(); first.close()
        @Expect(retiring.isClosed())
        @Expect(!survivor.isClosed())
        @Expect(first.renderer.cachedImage(paths[0]).isNone())
        @Expect(imageMemoryStats().renderers, before + 1)
        @Expect(refEq(survivor, second.renderer.cachedImage(paths[1]).getOrThrow()))
        second.close()
        @Expect(survivor.isClosed())
        @Expect(imageMemoryStats().renderers, before)
        @Expect(imageMemoryStats().textureBytes, Int64(0))
    } finally {
        first.close(); second.close(); configureImageMemory(oldOptions)
        for (path in paths) { let _ = removeIfExists(path) }
        let _ = removeIfExists(base)
    }
}

@When[os == "macOS"]
@Test
func imageBudgetNativeRejectsBeforeDecoderAndBorrowedUploadKeepsPixels(): Unit {
    let base = "target/image-budget-upload-test"
    Directory.create(base, recursive: true)
    let bomb = base + "/header.png"
    let oldOptions = currentImageMemoryOptions()
    let window = SdlWindow(WindowSpec("Image upload test", 8, 8, supersample: 1))
    try {
        File.writeTo(bomb, pngBudgetHeader(7680, 4320))
        // This is not a valid decodable PNG: budget must reject it before decoder errors.
        expectImageFailure({=> let _ = Surface.load(bomb)}, "image-budget:")
        expectImageFailure({=> let _ = window.renderer.loadTexture(bomb)}, "image-budget:")
        @Expect(window.renderer.cachedImage(bomb).isNone())
        let pixels = Array<UInt8>(40, {_ => UInt8(0)})
        for (y in 0..2) { for (x in 0..4) {
            let offset = y * 20 + x * 4
            pixels[offset] = 12; pixels[offset + 1] = 34; pixels[offset + 2] = 56; pixels[offset + 3] = 255
        } }
        let texture = window.renderer.createStreamingRgbaTexture(4, 2)
        let target = window.renderer.createTargetTexture(4.0, 2.0)
        try {
            expectImageFailure({=> target.updateRgba(pixels, 20)}, "streaming")
            for (_ in 0..128) { texture.updateRgba(pixels, 20) }
            pixels[0] = 99 // SDL upload must not retain an Array pointer.
            window.renderer.renderToTexture(target, 4.0, 2.0, Color.rgb(0, 0, 0)) {
                window.renderer.texture(texture, Rect(0.0, 0.0, 4.0, 2.0))
                try (surface = window.renderer.captureSurface()) {
                    var red: UInt8 = 0; var green: UInt8 = 0; var blue: UInt8 = 0; var alpha: UInt8 = 0
                    @Expect(unsafe { SDL_ReadSurfacePixel(surface.ptr, 0, 0,
                        inout red, inout green, inout blue, inout alpha) })
                    @Expect(red, UInt8(12)); @Expect(green, UInt8(34)); @Expect(blue, UInt8(56))
                    @Expect(alpha, UInt8(255))
                }
            }
            expectImageFailure({=> texture.updateRgba([1, 2, 3], 20)}, "every row")
            texture.close()
            expectImageFailure({=> texture.updateRgba(pixels, 20)}, "closed")
        } finally { texture.close(); target.close() }
    } finally {
        window.close(); configureImageMemory(oldOptions)
        let _ = removeIfExists(bomb); let _ = removeIfExists(base)
    }
}

@When[os == "macOS"]
@Test
func imageBudgetNative4KDecodeAndUploadMeasurement(): Unit {
    let path = "target/image-budget-4k.png"
    let oldOptions = currentImageMemoryOptions()
    let window = SdlWindow(WindowSpec("4K image budget", 32, 32, supersample: 1))
    try {
        configureImageMemory(ImageMemoryOptions())
        try (surface = Surface.create(3840, 2160)) {
            surface.clear(Color.rgb(12, 34, 56)); surface.savePng(path)
        }
        let image = window.renderer.cachedImage(path).getOrThrow()
        @Expect(image.width, Float32(3840.0)); @Expect(image.height, Float32(2160.0))
        @Expect(imageMemoryStats().textureBytes, Int64(33177600))
        clearCachedImages()
        @Expect(image.isClosed())
        let texture = window.renderer.createStreamingRgbaTexture(3840, 2160)
        let pixels = Array<UInt8>(33177600, {_ => UInt8(127)})
        try {
            // Same SDL texture/path: compare explicit old marshalling with scoped acquisition.
            // CPU submission timing only, not GPU completion. No timing-based pass criterion.
            texture.updateRgba(pixels, 15360)
            copyUploadReference(texture, pixels, 15360)
            let borrowed = Array<UInt64>(7, {_ => UInt64(0)})
            let copied = Array<UInt64>(7, {_ => UInt64(0)})
            for (i in 0..7) {
                if (i % 2 == 0) {
                    var start = PerformanceClock.ticksNanoseconds()
                    texture.updateRgba(pixels, 15360)
                    borrowed[i] = PerformanceClock.ticksNanoseconds() - start
                    start = PerformanceClock.ticksNanoseconds()
                    copyUploadReference(texture, pixels, 15360)
                    copied[i] = PerformanceClock.ticksNanoseconds() - start
                } else {
                    var start = PerformanceClock.ticksNanoseconds()
                    copyUploadReference(texture, pixels, 15360)
                    copied[i] = PerformanceClock.ticksNanoseconds() - start
                    start = PerformanceClock.ticksNanoseconds()
                    texture.updateRgba(pixels, 15360)
                    borrowed[i] = PerformanceClock.ticksNanoseconds() - start
                }
            }
            println("image-upload 3840x2160 RGBA8 samples=7 warmup=1 each cpu-affinity=uncontrolled")
            println("borrowed-submit-ns=${borrowed}")
            println("explicit-copy-submit-ns=${copied}")
            @Expect(pixels[0], UInt8(127)); @Expect(pixels[pixels.size - 1], UInt8(127))
        } finally { texture.close() }
    } finally {
        window.close(); configureImageMemory(oldOptions); let _ = removeIfExists(path)
    }
}

private func copyUploadReference(texture: Texture, pixels: Array<UInt8>, pitch: Int32): Unit {
    let native = unsafe { LibC.malloc<UInt8>(count: pixels.size) }
    if (native.isNull()) { throw CuiException("Reference upload allocation failed") }
    try {
        for (i in 0..pixels.size) { unsafe { native.write(i, pixels[i]) } }
        texture.updateRgba(native, pitch)
    } finally { unsafe { LibC.free(native) } }
}
