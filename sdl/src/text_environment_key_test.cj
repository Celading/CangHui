package sdl

@Test
func textEnvironmentKeyDistinguishesHeuristicAndLiveGlyphMetrics(): Unit {
    let window = SdlWindow(WindowSpec("Text environment identity", 240, 100, supersample: 1))
    try {
        let live = window.renderer
        let headless = Renderer.headless()
        live.setScale(1.0)
        @Expect(!live.platformTextLayoutEnabled())
        @Expect(!headless.platformTextLayoutEnabled())
        let before = live.textLayoutEnvironmentKey()
        @Expect(before != headless.textLayoutEnvironmentKey())
        @Expect(before, live.textLayoutEnvironmentKey())
        @Expect(live.textWidth("iiii 中文") != headless.textWidth("iiii 中文"))
        live.setScale(1.5)
        @Expect(before != live.textLayoutEnvironmentKey())
    } finally { window.close() }
}
