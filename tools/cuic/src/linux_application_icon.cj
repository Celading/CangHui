package cuic

import std.fs.{File, FileInfo, OpenMode}

// hicolor owns index.theme. Do not install a private replacement that hides
// other applications' directories. No raster resampling happens in CUIC.
func linuxApplicationIconDestination(source: String, identifier: String): String {
    let info = FileInfo(source)
    if (info.isSymbolicLink() || !info.isRegular()) {
        throw CuicError("Linux application icon must be a regular file")
    }
    let extension = packagingExtension(source)
    var directory = "scalable"
    if (extension == "png") {
        let header = Array<UInt8>(24, repeat: UInt8(0))
        let input = File(source, OpenMode.Read)
        try {
            var filled: Int64 = 0
            while (filled < header.size) {
                let remaining = Array<UInt8>(header.size - filled, repeat: UInt8(0))
                let count = input.read(remaining)
                if (count <= 0) { throw CuicError("Linux PNG icon has a truncated header") }
                for (i in 0..count) { header[filled + i] = remaining[i] }
                filled += count
            }
        } finally { input.close() }
        let size = linuxPngIconSize(header)
        directory = "${size}x${size}"
    } else if (extension != "svg") {
        throw CuicError("Linux application icons require PNG or SVG; convert ICO/ICNS/JPEG explicitly")
    }
    "share/icons/hicolor/${directory}/apps/${identifier}.${extension}"
}

// Validate just the PNG signature/IHDR dimensions for directory selection.
// Full decoding, CRC validation and artwork review remain separate acceptance.
func linuxPngIconSize(header: Array<UInt8>): Int64 {
    let prefix: Array<UInt8> = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82]
    if (header.size < 24) { throw CuicError("Linux PNG icon has a truncated header") }
    for (i in 0..prefix.size) {
        if (header[i] != prefix[i]) { throw CuicError("Linux PNG icon requires a PNG signature and IHDR") }
    }
    var width: Int64 = 0
    var height: Int64 = 0
    for (i in 0..4) {
        width = width * 256 + Int64(header[16 + i])
        height = height * 256 + Int64(header[20 + i])
    }
    if (width != height) { throw CuicError("Linux PNG application icon must be square; use SVG or export a square icon") }
    for (size in [16, 22, 24, 32, 36, 48, 64, 72, 96, 128, 192, 256, 512]) {
        if (width == size) { return width }
    }
    throw CuicError("Linux PNG icon size is not a standard hicolor size; use SVG or export 16/22/24/32/36/48/64/72/96/128/192/256/512px")
}
