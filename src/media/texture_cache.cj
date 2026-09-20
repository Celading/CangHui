package chui.media

import sdl.{Renderer, Texture, clearCachedImages, invalidateCachedImage}

// The renderer owns the cache and closes its textures before SDL_DestroyRenderer.
protected func sharedTexture(renderer: Renderer, path: String): ?Texture {
    renderer.cachedImage(path)
}

/** Drops this path on every active renderer; the next draw retries decoding. UI thread only. */
public func invalidateImage(path: String): Unit { invalidateCachedImage(path) }

/** Releases cached image textures on every active renderer. UI thread, between frames only. */
public func clearImageCache(): Unit { clearCachedImages() }
