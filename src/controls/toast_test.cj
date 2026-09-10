package chui.controls

import sdl.{FontSizes, FrameInfo, Renderer, Size, UiEvent}
import chui.core.{Theme, TypographyEnvironment, UiContext}

private func toastTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func toasterShowAddsAndTickExpires(): Unit {
    let toaster = Toaster()
    toaster.show("hello", durationMs: 1000)
    @Expect(toaster.count(), 1)
    toaster.tick(500)
    @Expect(toaster.count(), 1) // still within its lifetime
    toaster.tick(600) // 1100 total ≥ 1000 → removed
    @Expect(toaster.count(), 0)
}

@Test
func toasterExpiresIndependentlyByDuration(): Unit {
    let toaster = Toaster()
    toaster.show("short", durationMs: 300)
    toaster.show("long", durationMs: 2000)
    @Expect(toaster.count(), 2)
    toaster.tick(400) // short is gone, long remains
    @Expect(toaster.count(), 1)
    @Expect(toaster.snapshot()[0].message, "long")
    toaster.tick(2000)
    @Expect(toaster.count(), 0)
}

@Test
func toasterSnapshotKeepsPostOrder(): Unit {
    let toaster = Toaster()
    toaster.show("a")
    toaster.show("b")
    toaster.show("c")
    let snap = toaster.snapshot()
    @Expect(snap.size, 3)
    @Expect(snap[0].message, "a") // oldest first
    @Expect(snap[2].message, "c") // newest last
}

@Test
func toastLayerTicksToasterAndRequestsFramesWhileActive(): Unit {
    let ctx = toastTestContext()
    let toaster = Toaster()
    toaster.show("x", durationMs: 1000)
    let layer = ToastLayer(toaster)

    // A frame ages the toast and, because one is alive, asks the loop for another frame.
    @Expect(!layer.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(100)))))
    @Expect(toaster.count(), 1)
    @Expect(ctx.takeFrameRequest()) // requestFrame was called (and is now cleared)

    // Drain the toast; with none alive, no further frame is requested.
    toaster.tick(2000)
    @Expect(toaster.count(), 0)
    let _ = layer.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(100))))
    @Expect(!ctx.takeFrameRequest())
}

@Test
func toastLayerTakesNoLayoutSpace(): Unit {
    let ctx = toastTestContext()
    let layer = ToastLayer(Toaster())
    @Expect(!layer.participatesInLayout())
    @Expect(layer.measure(ctx, Size(300.0, 200.0)).h, Float32(0.0))
}

@Test
func toastMultilineFitsEllipsisAndPreservesExplicitBreaks(): Unit {
    let ctx = toastTestContext()
    @Expect(wrapToastText(ctx, "甲\r\n乙\r丙\n丁\n戊", 200.0), ["甲", "乙", "丙", "丁…"])
    let lines = wrapToastText(ctx, "一二三四五六七八九十一二三四五六七八九十ABCDEFGHIJKLMNOPQRSTUVWXYZ", 40.0)
    @Expect(lines.size, 4)
    @Expect(lines[3].endsWith("…"))
    for (line in lines) {
        @Expect(ctx.renderer.textWidth(line, pointSize: FontSizes.CONTROL) <= 40.0)
    }
    for (line in wrapToastText(ctx, "太窄🙂", 1.0)) { @Expect(line, "") }
    @Expect(wrapToastText(ctx, "", 0.0), [""])
}

@Test
func toastCacheTracksFontScaleFamilyAndStyleAtSameWidth(): Unit {
    let ctx = toastTestContext()
    let toast = ActiveToast(1, "A long toast message for measuring typography changes", ToastKind.Info, 1000)
    let initial = toastFittedLines(ctx, toast, 200.0)
    let initialKey = toast.fittedTypography
    @Expect(toastFittedLines(ctx, toast, 200.0), initial)
    ctx.fontScale = 2.0
    let _ = toastFittedLines(ctx, toast, 200.0)
    @Expect(toast.fittedTypography != initialKey)
    let scaledKey = toast.fittedTypography
    ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Test face", bold: true), {=>
        let _ = toastFittedLines(ctx, toast, 200.0)
        @Expect(toast.fittedTypography != scaledKey)
    })
}
