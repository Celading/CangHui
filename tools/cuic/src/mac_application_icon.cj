package cuic

import std.fs.{Directory, File, FileInfo, OpenMode, removeIfExists}

func macPngIconSize(header: Array<UInt8>): Int64 {
    let prefix: Array<UInt8> = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]
    if (header.size < 24) { throw CuicError("macOS PNG icon header is truncated") }
    for (i in 0..prefix.size) {
        if (header[i] != prefix[i]) { throw CuicError("macOS icon requires PNG signature and IHDR") }
    }
    var width: Int64 = 0
    var height: Int64 = 0
    for (i in 0..4) {
        width = width * 256 + Int64(header[16+i])
        height = height * 256 + Int64(header[20+i])
    }
    if (width != height || width < 16 || width > 4096) {
        throw CuicError("macOS PNG icon must be square, 16..4096 pixels; 1024 is recommended")
    }
    width
}

func convertMacApplicationIcon(source: String, destination: String, resources: String): Unit {
    if (hostPlatform() != "macos") { throw CuicError("PNG to ICNS requires a macOS host; supply ICNS for cross-host planning") }
    let info = FileInfo(source)
    if (info.isSymbolicLink() || !info.isRegular() || info.size > 33554432) {
        throw CuicError("macOS PNG icon must be a regular file of at most 32 MiB")
    }
    let header = Array<UInt8>(24, repeat: 0)
    try (input = File(source, OpenMode.Read)) {
        for (i in 0..header.size) {
            let byte = Array<UInt8>(1, repeat: 0)
            if (input.read(byte) != 1) { throw CuicError("macOS PNG icon is truncated") }
            header[i] = byte[0]
        }
    }
    let _ = macPngIconSize(header)
    let work = Directory.createTemp(resources).toString()
    let iconset = joinPath(work, "application.iconset")
    Directory.create(iconset)
    try {
        for (size in [16,32,128,256,512]) {
            for (density in [1,2]) {
                let suffix = if (density == 2) { "@2x" } else { "" }
                let output = joinPath(iconset, "icon_${size}x${size}${suffix}.png")
                let dimension = (size*density).toString()
                if (executeCommandQuiet("/usr/bin/sips", ["-z", dimension, dimension, source, "--out", output], work) != 0) {
                    throw CuicError("macOS PNG icon decoding/resampling failed")
                }
            }
        }
        if (executeCommandQuiet("/usr/bin/iconutil", ["-c", "icns", iconset, "-o", destination], work) != 0) {
            throw CuicError("macOS ICNS generation failed")
        }
    } finally {
        // Only this fresh owned staging tree is removed, never application input files.
        let _ = removeIfExists(work, recursive: true)
    }
}
