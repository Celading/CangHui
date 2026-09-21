package chui.media

import std.fs.removeIfExists
import sdl.{SdlWindow, WindowSpec, Surface, Color, Rect, imageMemoryStats}
import chui.core.{UiContext, Theme}

@Test
func framePoolSnapshotSeparatesManagedHeapFromTextureEstimates(): Unit {
    let snapshot = FramePoolMemorySnapshot()
    @Expect(snapshot.managedHeapLimitBytes > 0)
    @Expect(snapshot.managedAllocatedBytes >= 0)
    @Expect(snapshot.images.textureBytes >= 0)
    clearImageCache()
    @Expect(FramePoolMemorySnapshot().images.textureBytes, Int64(0))
}

@When[os == "macOS"]
@Test
func imageViewNativeCacheSurvivesWindowSwitchAndClosesWithOwner(): Unit {
    let path = "target/image-view-cache-owner.png"
    let first = SdlWindow(WindowSpec("ImageView owner", 32, 32, supersample: 1))
    let second = SdlWindow(WindowSpec("ImageView peer", 32, 32, supersample: 1))
    try {
        try (surface = Surface.create(16, 16)) {
            surface.clear(Color.rgb(12, 34, 56)); surface.savePng(path)
        }
        let view = ImageView(path)
        let ctx = UiContext(first.renderer, Theme.light())
        let peer = UiContext(second.renderer, Theme.light())
        view.layout(ctx, Rect(0.0, 0.0, 16.0, 16.0))
        view.draw(ctx); view.draw(peer); view.draw(ctx)
        @Expect(imageMemoryStats().textureBytes, Int64(2048))
        @Expect(imageMemoryStats().misses, Int64(2))
        @Expect(imageMemoryStats().hits, Int64(1))
        first.close()
        @Expect(imageMemoryStats().textureBytes, Int64(1024))
        view.draw(peer)
        @Expect(imageMemoryStats().hits, Int64(1))
        second.close()
        @Expect(imageMemoryStats().textureBytes, Int64(0))
        clearImageCache() // legal after native owners retired; no freed handle is touched.
    } finally {
        first.close(); second.close(); let _ = removeIfExists(path)
    }
}
