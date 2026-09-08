package cuic

import std.fs.{Directory, File, removeIfExists}

func linuxTestPngHeader(width: Int64, height: Int64): Array<UInt8> {
    let result: Array<UInt8> = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,0,0,0,0,0]
    var w = width
    var h = height
    for (i in 0..4) {
        result[19 - i] = UInt8(w % 256)
        result[23 - i] = UInt8(h % 256)
        w /= 256
        h /= 256
    }
    result
}

@Test
func linuxIconDimensionsSelectRealHicolorDirectories(): Unit {
    let project = joinPath(currentDirectory(), "target/linux-icons-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(project, recursive: true)
    let png = joinPath(project, "app.PNG")
    for (size in [16,22,24,32,36,48,64,72,96,128,192,256,512]) {
        File.writeTo(png, linuxTestPngHeader(size, size))
        @Expect(linuxApplicationIconDestination(png, "dev.demo"),
            "share/icons/hicolor/${size}x${size}/apps/dev.demo.png")
    }
    let svg = joinPath(project, "app.SVG")
    File.writeTo(svg, "<svg xmlns=\"http://www.w3.org/2000/svg\"/>".toArray())
    @Expect(linuxApplicationIconDestination(svg, "dev.demo"), "share/icons/hicolor/scalable/apps/dev.demo.svg")
    _ = removeIfExists(project, recursive: true)
}

@Test
func linuxIconsRejectMisleadingFormatsAndSizeMetadata(): Unit {
    let project = joinPath(currentDirectory(), "target/linux-icons-reject-fixture")
    _ = removeIfExists(project, recursive: true)
    Directory.create(project, recursive: true)
    for (extension in ["ico", "icns", "jpg", "xpm", "png"]) {
        let path = joinPath(project, "app.${extension}")
        File.writeTo(path, [UInt8(0)])
        var rejected = false
        try { let _ = linuxApplicationIconDestination(path, "dev.demo") }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
    for (header in [linuxTestPngHeader(0,0), linuxTestPngHeader(48,32), linuxTestPngHeader(47,47),
            Array<UInt8>(24, repeat: UInt8(0))]) {
        var rejected = false
        try { let _ = linuxPngIconSize(header) }
        catch (_: CuicError) { rejected = true }
        @Expect(rejected)
    }
    var rejected = false
    try { let _ = linuxApplicationIconDestination(project, "dev.demo") }
    catch (_: CuicError) { rejected = true }
    @Expect(rejected)
    _ = removeIfExists(project, recursive: true)
}
