package chui_overlay_motion

import chui.*
import chui.kmode.macros.*

class OverlayModel {
    let open = State<Bool>(true)
    let toaster = Toaster()
    init() {
        toaster.show("保存完成\n中文消息与 Latin words 自动换行。\n第三行提供结果摘要。\n第四行必须留出省略号。\n这一行不应溢出。", durationMs: 10000)
    }
}

func overlayView(model: OverlayModel): Unit {
    ZStack {
        VStack(spacing: 12.vp) {
            Label("Overlay motion regression").fontSize(24.fp)
            Button("Open confirmation", {=> model.open.value = true}).key("open")
        }.padding(24.0)
        Modal(model.open) {
            VStack(spacing: 12.vp) {
                Label("确认保存更改？").fontSize(22.fp)
                Label("展开完成后才可操作；Escape 随时关闭。").wrap()
                Button("Confirm", {=> model.open.value = false}).key("confirm")
            }
        }
        ToastLayer(model.toaster)
    }
}

@CuiProbe["overlay.motion"]
func overlayProbe(script: String): String {
    let model = OverlayModel()
    ComponentProbe("overlay.motion", width: 760.0, height: 600.0, theme: Theme.dark()).run(script) {
        overlayView(model)
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = OverlayModel()
    DesktopApp(WindowSpec("Overlay motion", 760, 600), theme: Theme.dark()).run {
        overlayView(model)
    }
    0
}
