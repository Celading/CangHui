package cuic

import std.fs.{File, OpenMode, exists}

func desktopCaptureUsesNativePng(framework: String): Bool {
    let source = joinPath(framework, "src/desktop/desktop_capture_png.cj")
    exists(source) && String.fromUtf8(File.readFrom(source)).contains("canghui.desktop-capture-png.v1")
}

func desktopCaptureSnapshotPath(output: String, nativePng: Bool): String {
    if (endsWithText(output, ".png") || endsWithText(output, ".PNG")) {
        if (nativePng) { output + ".capture.png" } else { output + ".bmp" }
    } else { output }
}

// Keep the previous output during build/capture and until format validation.
// The existing file transfer is not a crash-atomic replacement guarantee.
func publishDesktopPng(snapshot: String, output: String): Unit {
    verifyDesktopPng(snapshot)
    if (moveFile(snapshot, output) != 0) {
        throw CuicError("could not publish PNG capture: ${output}")
    }
}

// Check format identity without reading the entire image. Decoding/pixel correctness
// belongs to renderer tests; this rejects old/custom hosts writing BMP under .png.
func verifyDesktopPng(path: String): Unit {
    let signature: Array<UInt8> = [137, 80, 78, 71, 13, 10, 26, 10]
    let input = File(path, OpenMode.Read)
    try {
        let byte = Array<UInt8>(1, repeat: 0)
        for (expected in signature) {
            if (input.read(byte) != 1 || byte[0] != expected) {
                throw CuicError("capture did not produce PNG data: ${path}")
            }
        }
    } finally { input.close() }
}
