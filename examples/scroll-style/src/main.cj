package canghui_scroll_style

import chui.*
import std.collection.ArrayList
import std.convert.*
import std.env.getCommandLine
import std.fs.File

private func argument(name: String, fallback: String): String {
    let args = getCommandLine()
    for (i in 0..max(0, args.size - 1)) { if (args[i] == name) { return args[i + 1] } }
    fallback
}

private func appearance(mode: String): ScrollBarStyle {
    ScrollBarStyle(
        visibility: if (mode == "hidden") {ScrollBarVisibility.Hidden} else {ScrollBarVisibility.Automatic},
        layout: if (mode == "overlay") {ScrollBarLayout.Overlay} else {ScrollBarLayout.Reserved},
        opacity: if (mode == "transparent") {Float32(0.0)} else {Float32(1.0)},
        width: 12.0, margin: 3.0, minThumbLength: 24.0, radius: 6.0, trackRadius: 6.0,
        trackOpacity: 0.2, thumbOpacity: 0.85, hoverOpacity: 1.0, activeOpacity: 1.0,
        trackColor: Some(Color.rgb(95, 130, 160)), thumbColor: Some(Color.rgb(46, 126, 180)),
        hoverColor: Some(Color.rgb(32, 154, 201)), activeColor: Some(Color.rgb(18, 100, 155)),
        interactionAnimation: Some(AnimationSpec.automatic(duration: 160, easing: Easing.EaseOutCubic)))
}

private func view(mode: String, views: ArrayList<ScrollView>): Unit {
    views.clear()
    VStack(spacing: 12.vp) {
        Label("Scroll appearance").fontSize(24.0)
        Label("${mode} / wheel or drag the content")
        let viewport = VStack(spacing: 6.vp) {
            for (i in 0..24) { Label("Row ${i + 1}").height(32.0) }
        }.hug().scrollable(key: "scroll.example", options: ScrollOptions.web(bar: appearance(mode)))
            .dragToScroll()
        views.add(viewport)
        viewport.height(340.0).border(Color.rgb(130, 150, 170), width: 1.0, radius: 8.0)
        Button("Keep keyboard focus", {=> ()})
    }.padding(18.0)
}

private func exportNative(directory: String): Unit {
    for (width in [Int32(390), Int32(1024), Int32(1440)]) {
        let window = SdlWindow(WindowSpec("Scroll style capture", width, 600, supersample: 1))
        try {
            window.renderer.setDrawIrRecording(true)
            for (mode in ["reserved", "overlay", "hidden", "transparent"]) {
                let views = ArrayList<ScrollView>()
                let snapshot = ComponentProbe("scroll.${mode}", width: Float32(width), height: 600.0,
                    renderer: Some(window.renderer)).run("@cui-design-snapshot-v2-computed\npress 80 240\nmove 80 160\nrelease 80 160\nadvance 500") {
                    view(mode, views)
                }
                let key = "${mode}-${width}"
                File.writeTo(directory + "/" + key + ".json", snapshot.toArray())
                window.renderer.captureBmp(directory + "/" + key + ".bmp")
                let m = views[0].metrics()
                File.writeTo(directory + "/" + key + "-metrics.json", ("{\"mode\":\"${mode}\"," +
                    "\"windowWidth\":${width},\"viewportWidth\":${m.viewport.w},\"viewportHeight\":${m.viewport.h}," +
                    "\"reservedRight\":${m.reservedRight},\"offsetY\":${m.offsetY},\"contentHeight\":${m.contentHeight}}").toArray())
            }
        } finally { window.close() }
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let directory = argument("--export-native", "")
    if (!directory.isEmpty()) { exportNative(directory); return 0 }
    let mode = argument("--mode", "reserved")
    let width = Int32.parse(argument("--width", "390"))
    let views = ArrayList<ScrollView>()
    let app = DesktopApp(WindowSpec("CangHui Scroll Appearance", width, 600))
    app.run { view(mode, views) }
    0
}
