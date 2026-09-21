package sdl

import std.collection.ArrayList

/** Live cache accounting. Bytes are RGBA8 estimates; counters cover active renderers only. */
public struct ImageMemoryStats {
    public let renderers: Int64
    public let entries: Int64
    public let textureBytes: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let failures: Int64
    public let budgetRejections: Int64

    internal init(renderers: Int64, entries: Int64, bytes: Int64, hits: Int64, misses: Int64,
        evictions: Int64, failures: Int64, rejected: Int64) {
        this.renderers = renderers; this.entries = entries; this.textureBytes = bytes
        this.hits = hits; this.misses = misses; this.evictions = evictions
        this.failures = failures; this.budgetRejections = rejected
    }
}

private class ImageCacheEntry {
    let path: String
    let texture: ?Texture
    let bytes: Int64
    init(path: String, texture: ?Texture, bytes: Int64) {
        this.path = path; this.texture = texture; this.bytes = bytes
    }
    func close(): Unit {
        match (texture) { case Some(value) => value.close(); case None => () }
    }
}

// UI/renderer-owner thread only. Entries are removed synchronously at renderer close.
private let activeImageCaches = ArrayList<RendererImageCache>()

private class ImageAdmission { var bytes: Int64 = 0 }

internal class RendererImageCache {
    private let entries = ArrayList<ImageCacheEntry>() // oldest -> most recently used
    private var registered = false
    private var closed = false
    var bytes: Int64 = 0
    var hits: Int64 = 0
    var misses: Int64 = 0
    var evictions: Int64 = 0
    var failures: Int64 = 0
    var rejected: Int64 = 0
    func size(): Int64 { entries.size }

    func load(renderer: Renderer, path: String): ?Texture {
        if (closed || renderer.ptr.isNull()) { return None }
        if (!registered) { activeImageCaches.add(this); registered = true }
        for (i in 0..entries.size) {
            let entry = entries[i]
            if (entry.path == path) {
                let stale = match (entry.texture) { case Some(t) => t.isClosed(); case None => false }
                if (stale) { remove(i); break }
                let _ = entries.remove(at: i)
                entries.add(entry)
                hits += 1
                return entry.texture
            }
        }
        misses += 1
        let options = imageMemoryOptions
        let reservation = ImageAdmission()
        var texture: ?Texture = None
        try {
            try (surface = loadBudgetedImage(path, imageFormatFromPath(path), options, {estimate =>
                if (estimate > options.cacheBytes) {
                    throw CuiException("image-budget: single image exceeds renderer cache")
                }
                trim(options.cacheBytes - estimate, options.cacheEntries - 1)
                reservation.bytes = estimate
            })) {
                let loaded = renderer.textureFromSurface(surface)
                try {
                    let actualBytes = Int64(loaded.width) * Int64(loaded.height) * 4
                    if (actualBytes <= 0 || actualBytes > reservation.bytes) {
                        throw CuiException("image-budget: decoded texture exceeds header estimate")
                    }
                    loaded.setBlendMode(TextureBlendMode.Blend)
                }
                catch (error: Exception) { loaded.close(); throw error }
                texture = Some(loaded)
            }
        } catch (error: Exception) {
            reservation.bytes = 0
            failures += 1
            if (error.message.startsWith("image-budget:")) { rejected += 1 }
        }
        // Failed files also occupy a bounded slot. Explicit invalidation retries them.
        trim(options.cacheBytes - reservation.bytes, options.cacheEntries - 1)
        entries.add(ImageCacheEntry(path, texture, reservation.bytes))
        bytes += reservation.bytes
        texture
    }

    func invalidate(path: String): Unit {
        for (i in 0..entries.size) {
            if (entries[i].path == path) { remove(i); return }
        }
    }
    func trim(targetBytes: Int64, targetEntries: Int64): Unit {
        while (!entries.isEmpty() && (bytes > targetBytes || entries.size > targetEntries)) {
            remove(0); evictions += 1
        }
    }
    private func remove(index: Int64): Unit {
        let entry = entries.remove(at: index)
        bytes -= entry.bytes
        entry.close()
    }
    func clear(): Unit {
        while (!entries.isEmpty()) { remove(entries.size - 1) }
    }
    func close(): Unit {
        if (closed) { return }
        clear()
        closed = true
        if (registered) {
            for (i in 0..activeImageCaches.size) {
                if (refEq(activeImageCaches[i], this)) {
                    let _ = activeImageCaches.remove(at: i); break
                }
            }
            registered = false
        }
    }
}

extend Renderer {
    /** Borrowed texture valid until cache mutation/eviction or renderer close. UI thread only. */
    public func cachedImage(path: String): ?Texture { rendererImageCache.load(this, path) }
}

/** Set on the UI owner thread between frames. Clears existing entries, including failures. */
public func configureImageMemory(options: ImageMemoryOptions): Unit {
    clearCachedImages()
    imageMemoryOptions = options
}

public func currentImageMemoryOptions(): ImageMemoryOptions { imageMemoryOptions }

/** Release all image textures before the next frame, e.g. on memory-pressure/background events. */
public func clearCachedImages(): Unit {
    for (cache in activeImageCaches) { cache.clear() }
}

public func invalidateCachedImage(path: String): Unit {
    for (cache in activeImageCaches) { cache.invalidate(path) }
}

/** Explicit pressure trim; retain the most recently used entries within the given per-renderer budget. */
public func trimImageMemory(bytesPerRenderer: Int64): Unit {
    if (bytesPerRenderer < 0) { throw CuiException("Image trim budget must not be negative") }
    for (cache in activeImageCaches) { cache.trim(bytesPerRenderer, imageMemoryOptions.cacheEntries) }
}

public func imageMemoryStats(): ImageMemoryStats {
    var entries: Int64 = 0; var bytes: Int64 = 0; var hits: Int64 = 0; var misses: Int64 = 0
    var evictions: Int64 = 0; var failures: Int64 = 0; var rejected: Int64 = 0
    for (cache in activeImageCaches) {
        entries += cache.size(); bytes += cache.bytes; hits += cache.hits; misses += cache.misses
        evictions += cache.evictions; failures += cache.failures; rejected += cache.rejected
    }
    ImageMemoryStats(activeImageCaches.size, entries, bytes, hits, misses, evictions, failures, rejected)
}
