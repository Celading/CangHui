package sdl.text

import std.collection.HashMap

@When[os == "macOS"]
@C
internal struct MacTextDestination {
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var w: Float32 = 0.0
    var h: Float32 = 0.0
}

@When[os == "macOS"]
foreign {
    func SDL_CreateTexture(renderer: CPointer<Unit>, format: UInt32, access: Int32,
        width: Int32, height: Int32): CPointer<Unit>
    func SDL_UpdateTexture(texture: CPointer<Unit>, rect: CPointer<Unit>,
        pixels: CPointer<UInt8>, pitch: Int32): Bool
    func SDL_DestroyTexture(texture: CPointer<Unit>): Unit
    func SDL_SetTextureBlendMode(texture: CPointer<Unit>, mode: UInt32): Bool
    func SDL_SetTextureScaleMode(texture: CPointer<Unit>, mode: Int32): Bool
    func SDL_RenderTexture(renderer: CPointer<Unit>, texture: CPointer<Unit>, source: CPointer<Unit>,
        destination: CPointer<MacTextDestination>): Bool
    func SDL_CreateSurfaceFrom(width: Int32, height: Int32, format: UInt32,
        pixels: CPointer<UInt8>, pitch: Int32): CPointer<Unit>
    func SDL_DuplicateSurface(surface: CPointer<Unit>): CPointer<Unit>
    func SDL_DestroySurface(surface: CPointer<Unit>): Unit
}

@When[os == "macOS"]
internal class MacTextTexture {
    let pointer: CPointer<Unit>
    let width: Int32
    let height: Int32
    let x: Float32
    let y: Float32
    init(pointer: CPointer<Unit>, raster: NativeTextRaster) {
        this.pointer = pointer; this.width = raster.width; this.height = raster.height
        this.x = raster.offsetX; this.y = raster.offsetY
    }
    func close(): Unit { unsafe { SDL_DestroyTexture(pointer) } }
}

@When[os == "macOS"]
internal class MacPlatformTextEngine <: PlatformTextEngine {
    private let api = MacTextApi()
    private let renderer: CPointer<Unit>
    private let defaultPath: String
    private let lines = GenerationCache<MacTextLine>(64, {line => line.close()})
    private let textures = HashMap<String, MacTextTexture>()
    private var textureBytes: Int64 = 0
    private var shaped: UInt64 = 0
    private var closed = false

    init(renderer: CPointer<Unit>, defaultPath: String) {
        this.renderer = renderer; this.defaultPath = defaultPath
    }

    private func key(text: String, size: Float32, flags: Int32, paths: Array<String>,
        paint!: ?NativeTextLineSpec = None): String {
        let base = "${size}|${flags}|" + fontPathChainKey(paths) + "|${text.size}:${text}"
        match (paint) {
            case Some(spec) =>
                if (spec.text != text) { throw NativeTextException("Native line paint belongs to different text") }
                base + "|paint" + spec.colorKey
            case None => base
        }
    }

    private func line(text: String, size: Float32, flags: Int32, paths: Array<String>,
        paint!: ?NativeTextLineSpec = None): MacTextLine {
        if (closed) { throw NativeTextException("Platform text engine is closed") }
        let cacheKey = key(text, size, flags, paths, paint: paint)
        if (let Some(cached) <- lines.get(cacheKey)) { return cached }
        let created = MacTextLine(api, text, paths, defaultPath, size, (flags & 1) != 0, paint: paint)
        lines.put(cacheKey, created)
        shaped++
        created
    }

    public func measure(text: String, size: Float32, flags: Int32, paths: Array<String>,
        paint!: ?NativeTextLineSpec): NativeTextMetrics {
        line(text, size, flags, paths, paint: paint).metrics
    }

    public func resolvedPath(text: String, size: Float32, flags: Int32, paths: Array<String>): String {
        line(text, size, flags, paths).sourcePath
    }

    public func caret(text: String, index: Int64, size: Float32, flags: Int32,
        paths: Array<String>, paint!: ?NativeTextLineSpec): (Float32, Float32) {
        line(text, size, flags, paths, paint: paint).caretUtf16(index)
    }

    public func hit(text: String, x: Float32, size: Float32, flags: Int32, paths: Array<String>,
        paint!: ?NativeTextLineSpec): Int64 {
        line(text, size, flags, paths, paint: paint).hitUtf16(x)
    }

    public func carets(text: String, indices: Array<Int64>, size: Float32, flags: Int32,
        paths: Array<String>, paint!: ?NativeTextLineSpec): Array<(Float32, Float32)> {
        let layout = line(text, size, flags, paths, paint: paint)
        Array<(Float32, Float32)>(indices.size, {i => layout.caretUtf16(indices[i])})
    }

    public func selection(text: String, start: Int64, end: Int64, size: Float32, flags: Int32,
        paths: Array<String>, paint!: ?NativeTextLineSpec): Array<(Float32, Float32)> {
        line(text, size, flags, paths, paint: paint).selectionUtf16(start, end)
    }

    private func upload(raster: NativeTextRaster): MacTextTexture {
        // RGBA32 is ABGR8888 on the supported little-endian macOS targets.
        let texture = unsafe { SDL_CreateTexture(renderer, 0x16762004, 0, raster.width, raster.height) }
        if (texture.isNull()) { throw NativeTextException("Platform text texture allocation failed") }
        let pixels = unsafe { LibC.malloc<UInt8>(count: raster.pixels.size) }
        try {
            if (pixels.isNull()) { throw NativeTextException("Platform text upload allocation failed") }
            for (i in 0..raster.pixels.size) { unsafe { pixels.write(i, raster.pixels[i]) } }
            ensureNative(unsafe { SDL_UpdateTexture(texture, CPointer<Unit>(), pixels, raster.width * 4) },
                "platform text upload")
            ensureNative(unsafe { SDL_SetTextureBlendMode(texture, 1) }, "platform text blend")
            ensureNative(unsafe { SDL_SetTextureScaleMode(texture, 1) }, "platform text scale")
            MacTextTexture(texture, raster)
        } catch (e: Exception) { unsafe { SDL_DestroyTexture(texture) }; throw e }
        finally { unsafe { LibC.free(pixels) } }
    }

    public func draw(text: String, x: Float32, y: Float32, size: Float32, flags: Int32,
        paths: Array<String>, color: NativeTextColor, paint!: ?NativeTextLineSpec): Unit {
        if (text.isEmpty()) { return }
        let cacheKey = key(text, size, flags, paths, paint: paint) +
            "|${color.red},${color.green},${color.blue},${color.alpha}"
        let texture = match (textures.get(cacheKey)) {
            case Some(value) => value
            case None =>
                let raster = line(text, size, flags, paths, paint: paint).raster(color)
                if (textures.size >= 128 || textureBytes + raster.pixels.size > 16777216) { clearTextures() }
                let created = upload(raster)
                textures[cacheKey] = created
                textureBytes += raster.pixels.size
                created
        }
        var target = MacTextDestination()
        target.x = x + texture.x; target.y = y + texture.y
        target.w = Float32(texture.width); target.h = Float32(texture.height)
        ensureNative(unsafe { SDL_RenderTexture(renderer, texture.pointer, CPointer<Unit>(), inout target) },
            "platform text draw")
    }

    public func surface(text: String, size: Float32, flags: Int32, paths: Array<String>): CPointer<Unit> {
        if (text.isEmpty()) { return CPointer<Unit>() }
        let raster = line(text, size, flags, paths).raster(NativeTextColor(255, 255, 255, 255))
        let pixels = unsafe { LibC.malloc<UInt8>(count: raster.pixels.size) }
        var borrowed = CPointer<Unit>()
        try {
            if (pixels.isNull()) { throw NativeTextException("Platform text surface allocation failed") }
            for (i in 0..raster.pixels.size) { unsafe { pixels.write(i, raster.pixels[i]) } }
            borrowed = unsafe { SDL_CreateSurfaceFrom(raster.width, raster.height, 0x16762004,
                pixels, raster.width * 4) }
            if (borrowed.isNull()) { throw NativeTextException("Platform text surface creation failed") }
            let owned = unsafe { SDL_DuplicateSurface(borrowed) }
            if (owned.isNull()) { throw NativeTextException("Platform text surface copy failed") }
            owned
        } finally {
            if (borrowed.isNotNull()) { unsafe { SDL_DestroySurface(borrowed) } }
            unsafe { LibC.free(pixels) }
        }
    }

    public func shapeCount(): UInt64 { shaped }
    public func resetShapeCount(): Unit { shaped = 0 }
    private func clearTextures(): Unit {
        for ((_, value) in textures) { value.close() }
        textures.clear(); textureBytes = 0
    }
    public func close(): Unit {
        if (closed) { return }
        closed = true
        clearTextures(); lines.clear(); api.close()
    }
}
