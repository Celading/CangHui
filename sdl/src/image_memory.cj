package sdl

/** Bounds for synchronous PNG/BMP decoding and each renderer's ImageView cache.
 * Byte values are conservative logical estimates, not a process/GPU memory limit.
 */
public struct ImageMemoryOptions {
    public let maxPixels: Int64
    public let maxEncodedBytes: Int64
    public let maxWorkingBytes: Int64
    public let cacheBytes: Int64
    public let cacheEntries: Int64

    public init(maxPixels!: Int64 = 16777216, maxEncodedBytes!: Int64 = 67108864,
        maxWorkingBytes!: Int64 = 335544320, cacheBytes!: Int64 = 134217728,
        cacheEntries!: Int64 = 256) {
        if (maxPixels <= 0 || maxEncodedBytes <= 0 || maxWorkingBytes <= 0 ||
            cacheBytes <= 0 || cacheEntries < 1 || cacheEntries > 4096) {
            throw CuiException("Invalid image memory options: positive budgets and 1..4096 entries required.")
        }
        this.maxPixels = maxPixels
        this.maxEncodedBytes = maxEncodedBytes
        this.maxWorkingBytes = maxWorkingBytes
        this.cacheBytes = cacheBytes
        this.cacheEntries = cacheEntries
    }
}

internal var imageMemoryOptions = ImageMemoryOptions()

/** Validates dimensions without allocating a pixel array; returns RGBA8 texture bytes. */
public func imageTextureBytes(width: Int64, height: Int64, encodedBytes: Int64,
    options!: ImageMemoryOptions = ImageMemoryOptions()): Int64 {
    if (width <= 0 || height <= 0 || width > 2147483647 || height > 2147483647 ||
        width > Int64.Max / height) {
        throw CuiException("image-budget: invalid dimensions")
    }
    let pixels = width * height
    if (encodedBytes <= 0 || encodedBytes > options.maxEncodedBytes ||
        pixels > options.maxPixels || pixels > Int64.Max / 16) {
        throw CuiException("image-budget: encoded bytes or pixel limit exceeded")
    }
    // Decoder surfaces, conversion, scratch and texture allowance. Not an allocator cap.
    let working = pixels * 16
    if (encodedBytes > options.maxWorkingBytes || working > options.maxWorkingBytes - encodedBytes) {
        throw CuiException("image-budget: working byte estimate exceeded")
    }
    pixels * 4
}

internal func imageHeaderTextureBytes(header: Array<UInt8>, format: ImageFileFormat,
    encodedBytes: Int64, options: ImageMemoryOptions): Int64 {
    var width: Int64 = 0
    var height: Int64 = 0
    match (format) {
        case ImageFileFormat.Png =>
            let signature: Array<UInt8> = [137, 80, 78, 71, 13, 10, 26, 10]
            if (header.size < 33) { throw CuiException("image-header: truncated PNG") }
            for (i in 0..8) {
                if (header[i] != signature[i]) { throw CuiException("image-header: invalid PNG signature") }
            }
            if (imageU32(header, 8, false) != 13 || imageU32(header, 12, false) != 1229472850) {
                throw CuiException("image-header: PNG must start with IHDR")
            }
            width = imageU32(header, 16, false)
            height = imageU32(header, 20, false)
        case ImageFileFormat.Bmp =>
            if (header.size < 26 || header[0] != 66 || header[1] != 77) {
                throw CuiException("image-header: invalid BMP header")
            }
            let dib = imageU32(header, 14, true)
            if (dib == 12) {
                width = Int64(header[18]) + Int64(header[19]) * 256
                height = Int64(header[20]) + Int64(header[21]) * 256
            } else if (dib == 40 || dib == 52 || dib == 56 || dib == 108 || dib == 124) {
                if (header.size < 54) { throw CuiException("image-header: truncated BMP info") }
                width = imageU32(header, 18, true)
                height = imageU32(header, 22, true)
                // Top-down DIB uses a signed negative height; width remains positive.
                if (height > 2147483647) { height = 4294967296 - height }
            } else { throw CuiException("image-header: unsupported BMP DIB") }
    }
    imageTextureBytes(width, height, encodedBytes, options: options)
}

private func imageU32(bytes: Array<UInt8>, offset: Int64, little: Bool): Int64 {
    var value: Int64 = 0
    for (i in 0..4) {
        let index = if (little) { offset + 3 - i } else { offset + i }
        value = value * 256 + Int64(bytes[index])
    }
    value
}

/** Uses one open stream for header inspection and native decode, never a whole-file Array. */
internal func loadBudgetedImage(path: String, format: ImageFileFormat, options: ImageMemoryOptions,
    beforeDecode: (Int64) -> Unit): Surface {
    let cPath = unsafe { LibC.mallocCString(path) }
    var stream = CPointer<Unit>()
    try (pathResource = cPath.asResource()) {
        let mode = unsafe { LibC.mallocCString("rb") }
        try (modeResource = mode.asResource()) {
            stream = unsafe { SDL_IOFromFile(pathResource.value, modeResource.value) }
        }
    }
    if (stream.isNull()) { throw CuiException("Image stream open failed: ${lastSdlError()}") }
    try {
        let size = unsafe { SDL_GetIOSize(stream) }
        if (size <= 0 || size > options.maxEncodedBytes) {
            throw CuiException("image-budget: encoded byte limit exceeded or size unknown")
        }
        let buffer = unsafe { LibC.malloc<UInt8>(count: 54) }
        if (buffer.isNull()) { throw CuiException("Image header allocation failed") }
        var bytes: Int64 = 0
        try (resource = buffer.asResource()) {
            let count = unsafe { SDL_ReadIO(stream, resource.value, UIntNative(54)) }
            let header = Array<UInt8>(Int64(count), {i => unsafe { resource.value.read(i) }})
            bytes = imageHeaderTextureBytes(header, format, size, options)
        }
        beforeDecode(bytes)
        if (unsafe { SDL_SeekIO(stream, 0, 0) } != 0) { throw CuiException("Image stream rewind failed") }
        let raw = match (format) {
            case ImageFileFormat.Png => unsafe { SDL_LoadPNG_IO(stream, false) }
            case ImageFileFormat.Bmp => unsafe { SDL_LoadBMP_IO(stream, false) }
        }
        if (raw.isNull()) { throw CuiException("Image decode failed: ${lastSdlError()}") }
        Surface(raw)
    } finally { let _ = unsafe { SDL_CloseIO(stream) } }
}
