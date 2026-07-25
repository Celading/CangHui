package cangjiegui_component_gallery

import std.env.getCommandLine
import std.convert.*
import cui.*
import cui.kmode.macros.*
import cangjiegui_gallery_components.*

@KModeLink["gallery.api.version"]
func galleryApiVersion(_: String): String {
    componentApiVersion()
}

@KModeLink["gallery.viewport.class"]
func galleryViewportClass(value: String): String {
    match (classifyViewport(Float32.parse(value))) {
        case ViewportClass.Compact => "compact"
        case ViewportClass.Medium => "medium"
        case ViewportClass.Expanded => "expanded"
    }
}

private func previewLabels(): Array<String> {
    ["Android", "Harmony", "Tablet", "Desktop", "iOS layout"]
}

private func previewHeight(viewport: ViewportSpec): Float32 {
    if (viewport.height > 790.0) {
        790.0
    } else {
        viewport.height
    }
}

private func initialPreviewIndex(): Int64 {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--preview") {
            return previewIndex(args[i + 1])
        }
        i += 1
    }
    1
}

private func previewIndex(value: String): Int64 {
    match (value) {
        case "android" => 0
        case "harmony" => 1
        case "tablet" => 2
        case "desktop" => 3
        case "ios" => 4
        case _ => 1
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) {
        return 0
    }
    let previews = commonPreviewMatrix()
    let selectedPreview = State<Int64>(initialPreviewIndex())
    let galleryState = GallerySurfaceState()
    let app = DesktopApp(
        WindowSpec("CangjieGUI Component Gallery", 1500, 980, scale: 1.0),
        theme: Theme.dark()
    )
    app.setMinimumSize(1000, 760)
    app.run {
        let active = previews[selectedPreview.value]
        VStack {
            HStack {
                VStack {
                    Label("Component Gallery", fontSize: 24.fp)
                    Label("${active.label} / common-layout preview", muted: true)
                }.spacing(2.vp).hug()
                Spacer()
                Label("CUI API ${componentApiVersion()}", muted: true)
            }.hug()
            SegmentedControl(previewLabels(), selectedPreview, id: "preview-target")
            Divider()
            HStack {
                Spacer()
                Panel(flexible: false) {
                    galleryCommonSurface(active.componentContext(), galleryState)
                }.width(active.viewport.width).height(previewHeight(active.viewport))
                Spacer()
            }
        }.spacing(16.vp).padding(20.vp)
    }
    return 0
}
