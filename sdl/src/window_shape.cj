package sdl

/**
 * Applies a binary alpha mask to the native window. SDL copies the surface, so the
 * temporary can be closed immediately. This must run on the window-owning thread.
 */
internal func applyRoundedWindowShape(
    window: CPointer<Unit>,
    pixelWidth: Int32,
    pixelHeight: Int32,
    requestedRadius: Float32
): Unit {
    let radius = fittedCornerRadius(pixelWidth, pixelHeight, requestedRadius)
    if (window.isNull() || radius <= 0.0 || pixelWidth <= 0 || pixelHeight <= 0) {
        return
    }

    let mask = Surface.create(pixelWidth, pixelHeight)
    try (resource = mask) {
        resource.clear(Color.rgba(255, 255, 255, 255))
        let edge = Int32(radius) + 1
        for (y in 0..edge) {
            for (x in 0..edge) {
                let alpha = roundedCornerAlpha(x, y, radius)
                if (alpha == UInt8(255)) {
                    continue
                }
                let color = Color(255, 255, 255, alpha)
                resource.writePixel(x, y, color)
                resource.writePixel(pixelWidth - 1 - x, y, color)
                resource.writePixel(x, pixelHeight - 1 - y, color)
                resource.writePixel(pixelWidth - 1 - x, pixelHeight - 1 - y, color)
            }
        }
        ensureSdl(unsafe { SDL_SetWindowShape(window, resource.ptr) }, "SDL_SetWindowShape")
    }
}

internal func fittedCornerRadius(width: Int32, height: Int32, requested: Float32): Float32 {
    if (requested <= 0.0 || width <= 0 || height <= 0) {
        return 0.0
    }
    let shortest = if (width < height) { width } else { height }
    let maximum = Float32(shortest) / 2.0
    if (requested < maximum) { requested } else { maximum }
}

internal func roundedCornerAlpha(x: Int32, y: Int32, radius: Float32): UInt8 {
    if (radius <= 0.0) {
        return UInt8(255)
    }
    let dx = radius - (Float32(x) + 0.5)
    let dy = radius - (Float32(y) + 0.5)
    if (dx <= 0.0 || dy <= 0.0 || dx * dx + dy * dy <= radius * radius) {
        UInt8(255)
    } else {
        UInt8(0)
    }
}
