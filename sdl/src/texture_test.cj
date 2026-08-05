package sdl

@Test
func textureRenderOptionsUseSafeDefaults(): Unit {
    let options = TextureRenderOptions()

    @Expect(isNoSource(options.source))
    @Expect(isNoCenter(options.center))
    @Expect(isNoFlip(options.flip))
}

@Test
func textureRenderOptionsKeepExplicitFlip(): Unit {
    let options = TextureRenderOptions(flip: TextureFlip.Horizontal)

    @Expect(isHorizontalFlip(options.flip))
}

@Test
func streamingTextureValidationRejectsInvalidDimensions(): Unit {
    try {
        validateStreamingSize(0, 720)
        @Expect(false)
    } catch (e: CuiException) {
        @Expect(e.message.contains("dimensions"))
    }
}

@Test
func streamingTextureValidationRejectsShortPitch(): Unit {
    let pixel = unsafe { LibC.malloc<UInt8>() }
    try (resource = pixel.asResource()) {
        try {
            validateStreamingPixels(resource.value, 16, 63)
            @Expect(false)
        } catch (e: CuiException) {
            @Expect(e.message.contains("pitch"))
        }
        validateStreamingPixels(resource.value, 16, 64)
    }
}

private func isNoSource(source: ?Rect): Bool {
    match (source) {
        case None => true
        case Some(_) => false
    }
}

private func isNoCenter(center: ?Point): Bool {
    match (center) {
        case None => true
        case Some(_) => false
    }
}

private func isNoFlip(flip: TextureFlip): Bool {
    match (flip) {
        case TextureFlip.None => true
        case _ => false
    }
}

private func isHorizontalFlip(flip: TextureFlip): Bool {
    match (flip) {
        case TextureFlip.Horizontal => true
        case _ => false
    }
}
