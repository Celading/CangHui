package sdl

@Test
func imageFormatFromPathSelectsPngCaseInsensitively(): Unit {
    @Expect(isPng(imageFormatFromPath("badge.png")))
    @Expect(isPng(imageFormatFromPath("BADGE.PNG")))
}

@Test
func imageFormatFromPathDefaultsToBmp(): Unit {
    @Expect(isBmp(imageFormatFromPath("badge.bmp")))
    @Expect(isBmp(imageFormatFromPath("badge")))
}

@Test
func imageFormatForLoadRejectsKnownUnsupportedFormatsWithActionableMessage(): Unit {
    expectUnsupportedImage("photo.jpg")
    expectUnsupportedImage("photo.JPEG")
    expectUnsupportedImage("icon.svg")
    expectUnsupportedImage("texture.tiff")
}

private func expectUnsupportedImage(path: String): Unit {
    var rejected = false
    try { let _ = imageFormatForLoad(path) }
    catch (error: CuiException) {
        rejected = error.message.contains("unsupported image format") &&
            error.message.contains(".png") && error.message.contains(".bmp")
    }
    @Expect(rejected)
}

private func isPng(format: ImageFileFormat): Bool {
    match (format) {
        case ImageFileFormat.Png => true
        case ImageFileFormat.Bmp => false
    }
}

private func isBmp(format: ImageFileFormat): Bool {
    match (format) {
        case ImageFileFormat.Bmp => true
        case ImageFileFormat.Png => false
    }
}
