package chui_window_scale_native

import chui.{Color, Point, Rect, SdlWindow, UiEvent, WindowSpec, WindowScaleSettings}

@When[debug]
func verifyWindowScale(supersample: Int32): String {
    // Synthetic pointer routing is restricted to this debug-only verification entry.
    let window = SdlWindow(WindowSpec("CangHui scale contract", 640, 480,
        scaling: Some(WindowScaleSettings()), supersample: supersample))
    var report = ""
    try {
        let original = window.currentMetrics()
        for (zoom in [Float32(1.0), Float32(1.25), Float32(1.5), Float32(2.0), Float32(1.0)]) {
            let metrics = window.setScaling(WindowScaleSettings(zoom: zoom))
            let transform = window.coordinateTransform()
            let anchor = transform.logicalToWindow(Rect(100.0, 80.0, 8.0, 20.0))
            let logical = transform.windowToLogical(Point(anchor.x, anchor.y))
            if (logical.x != 100.0 || logical.y != 80.0 ||
                metrics.pixelWidth != original.pixelWidth || metrics.pixelHeight != original.pixelHeight) {
                throw Exception("scale changed native size or broke inverse mapping")
            }
            match (window.normalizeWindowEvent(UiEvent.MouseMove(anchor.x, anchor.y))) {
                case UiEvent.MouseMove(x, y) =>
                    if (x != logical.x || y != logical.y) { throw Exception("native input mapping diverged") }
                case _ => throw Exception("unexpected normalized event")
            }
            window.renderer.beginScene(Float32(metrics.logicalWidth), Float32(metrics.logicalHeight), Color.rgb(24, 28, 36))
            window.renderer.fillRoundedRect(Rect(100.0, 80.0, 120.0, 40.0), 0.0, Color.rgb(80, 180, 230))
            window.renderer.text("Scale ${zoom}", 110.0, 88.0, Color.rgb(255, 255, 255))
            window.setTextInputArea(Rect(100.0, 80.0, 8.0, 20.0))
            window.renderer.endScene()
            window.renderer.present()
            report += "supersample=${supersample} zoom=${zoom} density=${metrics.pixelDensity} render=${metrics.displayScale} " +
                "windowScale=${transform.windowScale} logical=${metrics.logicalWidth}x${metrics.logicalHeight} " +
                "pixels=${metrics.pixelWidth}x${metrics.pixelHeight} revision=${metrics.transformRevision}\n"
        }
        window.close()
    } catch (error: Exception) {
        window.close()
        throw error
    }
    report
}

@When[debug]
main(): Int64 {
    let direct = verifyWindowScale(Int32(1))
    let supersampled = verifyWindowScale(Int32(2))
    println(direct + supersampled + "CHUI_NATIVE_SCALE_PASS=1")
    0
}

@When[!debug]
main(): Int64 {
    println("Native input verification requires a debug build; no simulation ran.")
    0
}
