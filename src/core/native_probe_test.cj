package chui.core

import sdl.Renderer

@Test
func suppliedRecordingRendererIsBorrowedAndTruthfullyLabeled(): Unit {
    let renderer = Renderer.recordingHeadless()
    let snapshot = ComponentProbe("borrowed", renderer: Some(renderer)).run("@cui-design-snapshot-v2-computed") {
        Label("Borrowed renderer")
    }
    @Expect(snapshot.contains("provided-renderer"))
    @Expect(renderer.drawIrEnabled())
    @Expect(!renderer.drawIr().isEmpty())
    var rejected = false
    try { ComponentProbe("not-recording", renderer: Some(Renderer.headless())).run("") { Label("Must reject") } }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}
