package sdl.text

// Native layout owns geometry and pixels; the renderer owns its common caches
// and SDL textures. Backends must not implement a second upload/cache pipeline.
internal interface PlatformTextLine {
    func nativeMetrics(): NativeTextMetrics
    func primarySourcePath(): String
    func caretUtf16(index: Int64): (Float32, Float32)
    func rightToLeftUtf16(indices: Array<Int64>): Array<Bool>
    func hitUtf16(x: Float32): Int64
    func selectionUtf16(start: Int64, end: Int64): Array<(Float32, Float32)>
    func raster(color: NativeTextColor): NativeTextRaster
    func close(): Unit
}

internal interface PlatformTextLineFactory {
    func createLine(text: String, paths: Array<String>, defaultPath: String,
        size: Float32, bold: Bool, paint!: ?NativeTextLineSpec): PlatformTextLine
    func close(): Unit
}
