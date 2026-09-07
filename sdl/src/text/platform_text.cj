package sdl.text

internal interface PlatformTextEngine {
    func measure(text: String, size: Float32, flags: Int32, paths: Array<String>): NativeTextMetrics
    func draw(text: String, x: Float32, y: Float32, size: Float32, flags: Int32,
        paths: Array<String>, color: NativeTextColor): Unit
    func surface(text: String, size: Float32, flags: Int32, paths: Array<String>): CPointer<Unit>
    func resolvedPath(text: String, size: Float32, flags: Int32, paths: Array<String>): String
    func caret(text: String, index: Int64, size: Float32, flags: Int32, paths: Array<String>): (Float32, Float32)
    func carets(text: String, indices: Array<Int64>, size: Float32, flags: Int32,
        paths: Array<String>): Array<(Float32, Float32)>
    func hit(text: String, x: Float32, size: Float32, flags: Int32, paths: Array<String>): Int64
    func selection(text: String, start: Int64, end: Int64, size: Float32, flags: Int32,
        paths: Array<String>): Array<(Float32, Float32)>
    func shapeCount(): UInt64
    func resetShapeCount(): Unit
    func close(): Unit
}

@When[os == "macOS"]
internal func createPlatformTextEngine(renderer: CPointer<Unit>, defaultPath: String): ?PlatformTextEngine {
    try { Some(MacPlatformTextEngine(renderer, defaultPath)) } catch (_: NativeTextException) { None }
}

@When[os != "macOS"]
internal func createPlatformTextEngine(_renderer: CPointer<Unit>, _defaultPath: String): ?PlatformTextEngine {
    None
}
