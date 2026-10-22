package sdl

@Test
func recordedOutlinePreservesGeometrySeparatelyFromStrokeThickness(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.strokeRoundedRect(Rect(10.0, 20.0, 120.0, 80.0), 12.0, Pen(width: 3.0, color: Color.rgb(20, 30, 40)))
    let command = renderer.drawIr()[0]
    @Expect(command.data.contains("\"width\":120"))
    @Expect(command.data.contains("\"strokeWidth\":3"))
}

@Test
func recordedTextDeclaresMeasurementBackendAndOrigin(): Unit {
    let renderer = Renderer.recordingHeadless()
    renderer.text("Measured", 12.0, 14.0, Color.rgb(20, 30, 40), pointSize: 18.0)
    let command = renderer.drawIr()[0]
    @Expect(command.data.contains("\"textOrigin\":\"top-left\""))
    @Expect(command.data.contains("\"metricsBackend\":\"heuristic\""))
    @Expect(command.data.contains("\"measuredWidth\":"))
    @Expect(command.data.contains("\"measuredHeight\":"))
}

@Test
func recordingSwitchResetsOwnedLogAndDoesNotReplaceTheRenderer(): Unit {
    let renderer = Renderer.headless()
    renderer.setDrawIrRecording(true)
    renderer.text("Recorded", 1.0, 2.0, Color.rgb(10, 20, 30))
    @Expect(!renderer.drawIr().isEmpty())
    renderer.setDrawIrRecording(false)
    renderer.text("Not recorded", 1.0, 2.0, Color.rgb(10, 20, 30))
    @Expect(renderer.drawIr().isEmpty())
    @Expect(!renderer.drawIrEnabled())
}
