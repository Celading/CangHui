package canghui_scene3d_bgfx_metal_capture

import canghui_scene3d_bgfx.*
import cui.desktop.DesktopCaptureRequest
import cui.scene3d.*
import std.fs.{exists, removeIfExists}

main(): Int64 {
    let capture = match (DesktopCaptureRequest.fromEnvironment()) {
        case Some(request) => request
        case None => throw IllegalStateException("run this example through cuic prnt")
    }
    let tgaBase = capture.path + ".bgfx"
    let tgaPath = tgaBase + ".tga"
    removeIfExists(tgaPath)
    let host = MacOSSdlMetalHost("CangHui Scene3D Metal", 640, 420, identity: UInt64(20260819))
    let surface = host.surface("scene3d-bgfx-metal")
    let driver = Bgfx4cjDriver(host.nativeWindowPointer(), host.identity, clearColor: 0x3A8068FF)
    let provider: Scene3DProvider = DriverScene3DProvider(driver)
    try {
        let attach = provider.attach(surface, clock(0))
        println("attach=${attach.code}")
        if (!attach.ok) { return 10 }

        let load = provider.loadScene(Scene3DResource(
            "metal-clear", "memory://metal-clear", "sha256:metadata-only", 0
        ))
        println("load=${load.code}")
        if (!load.ok) { return 11 }

        let snapshot = Scene3DFrameSnapshot("metal-clear-scene")
        snapshot.add(Scene3DEntitySnapshot("clear-frame", 0.0, 0.0, 0.0))
        var captureRequested = false
        var captured = false
        let totalFrames = capture.settleFrames + UInt64(24)
        var frame: UInt64 = UInt64(1)
        while (frame <= totalFrames) {
            host.pump()
            let currentClock = clock(Int64(frame))
            let submit = provider.submit(snapshot, currentClock)
            let present = provider.present(currentClock)
            if (frame == UInt64(1)) {
                println("submit=${submit.code} present=${present.code}")
            }
            if (!submit.ok || !present.ok) { return 12 }
            if (!captureRequested && frame >= capture.settleFrames) {
                let request = driver.requestBackbufferCapture(tgaBase)
                println("capture=${request.code}")
                if (!request.ok) { return 13 }
                captureRequested = true
            }
            if (captureRequested && exists(tgaPath)) {
                convertBgfxTgaToBmp(tgaPath, capture.path)
                captured = true
                break
            }
            host.delay(UInt32(16))
            frame += UInt64(1)
        }
        if (!captured) {
            println("capture=missing")
            return 14
        }
        println("renderer=Metal frames=${frame} size=${surface.pixelWidth}x${surface.pixelHeight}")
        removeIfExists(tgaPath)
        0
    } finally {
        let detach = provider.detach(surface.id, surface.generation)
        println("detach=${detach.code}")
        host.close()
    }
}

private func clock(frame: Int64): Scene3DFrameClock {
    let timestamp = frame * 16666667
    Scene3DFrameClock(frame, timestamp, timestamp + 16666667)
}
