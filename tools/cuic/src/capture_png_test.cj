package cuic

import std.fs.{File, exists, removeIfExists}

@Test
func desktopPngRequiresMatchingSourceAndPreservesLegacyBmpPlan(): Unit {
    @Expect(!desktopCaptureUsesNativePng("missing-source"))
    @Expect(desktopCaptureUsesNativePng(integratedFrameworkRoot()))
    @Expect(desktopCaptureSnapshotPath("image.png", true), "image.png.capture.png")
    @Expect(desktopCaptureSnapshotPath("image.PNG", true), "image.PNG.capture.png")
    @Expect(desktopCaptureSnapshotPath("image.png", false), "image.png.bmp")
    @Expect(desktopCaptureSnapshotPath("image.BMP", false), "image.BMP")
    @Expect(desktopCaptureSnapshotPath("image.bmp", true), "image.bmp")
}

@Test
func desktopPngRejectsMissingTruncatedAndMislabeledOutput(): Unit {
    let path = joinPath(currentDirectory(), "target/png-capture-header.png")
    if (exists(path)) { throw CuicError("PNG test output already exists") }
    try {
        var missing = false
        try { verifyDesktopPng(path) } catch (_: Exception) { missing = true }
        @Expect(missing)
        let truncated: Array<UInt8> = [137,80,78]
        for (bytes in [Array<UInt8>(), truncated, "BMnot-a-png".toArray()]) {
            File.writeTo(path, bytes)
            var rejected = false
            try { verifyDesktopPng(path) } catch (_: CuicError) { rejected = true }
            @Expect(rejected)
        }
        let signature: Array<UInt8> = [137,80,78,71,13,10,26,10]
        File.writeTo(path, signature)
        // Signature validation is deliberately not a full PNG decoder.
        verifyDesktopPng(path)
    } finally { removeIfExists(path) }
}

@Test
func desktopPngPublishesOnlyAfterValidation(): Unit {
    let output = joinPath(currentDirectory(), "target/png-capture-preserved.png")
    let snapshot = desktopCaptureSnapshotPath(output, true)
    if (exists(output) || exists(snapshot)) { throw CuicError("PNG test output already exists") }
    try {
        File.writeTo(output, "previous output".toArray())
        for (missing in [true, false]) {
            if (!missing) { File.writeTo(snapshot, "BMnot-a-png".toArray()) }
            var rejected = false
            try { publishDesktopPng(snapshot, output) } catch (_: Exception) { rejected = true }
            @Expect(rejected)
            @Expect(String.fromUtf8(File.readFrom(output)), "previous output")
        }
        let signature: Array<UInt8> = [137,80,78,71,13,10,26,10]
        File.writeTo(snapshot, signature)
        publishDesktopPng(snapshot, output)
        verifyDesktopPng(output)
        @Expect(!exists(snapshot))
    } finally { removeIfExists(snapshot); removeIfExists(output) }
}
