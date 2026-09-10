package chui.desktop

import sdl.{Renderer, ImageFileFormat, imageFormatFromPath}

// Paired CUIC checks this source capability before requesting PNG directly.
internal let DESKTOP_PNG_PROTOCOL = "canghui.desktop-capture-png.v1"

internal func writeDesktopCapture(renderer: Renderer, path: String): Unit {
    match (imageFormatFromPath(path)) {
        case ImageFileFormat.Png => renderer.capturePng(path)
        case ImageFileFormat.Bmp => renderer.captureBmp(path)
    }
}
