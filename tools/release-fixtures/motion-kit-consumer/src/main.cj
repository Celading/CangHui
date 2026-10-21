package motion_kit_consumer

import chui.*
import canghui_kit.*

main(): Int64 {
    let renderer = Renderer.headless()
    let ctx = UiContext(renderer, Theme.light(reduceMotion: true))
    let track = MotionValue(0.0)
    if (track.animate(ctx, target: 1.0) != 1.0 || !track.settled()) { return 1 }
    let canvas = CanvasWidget(onDrawContext: {context, rect =>
        context.renderer.fillCircle(rect.centerX(), rect.centerY(), 4.0, Color.rgb(20, 90, 120))
    }, transparent: true)
    canvas.layout(ctx, Rect(30.0, 20.0, 100.0, 80.0))
    canvas.draw(ctx)
    renderer.pushClip(Rect(0.0, 0.0, 100.0, 100.0))
    let legacy = CanvasWidget({_, _ => throw IllegalStateException("paint stopped")})
    legacy.layout(ctx, Rect(10.0, 10.0, 60.0, 60.0))
    try { legacy.draw(ctx) } catch (_: IllegalStateException) { () }
    if (renderer.currentClip().getOrThrow().w != 100.0) { return 2 }
    renderer.popClip()
    let report = ComponentProbe("public-motion", width: 390.0, height: 900.0,
        theme: Theme.dark(reduceMotion: true)).run("advance 1000") {
        let palette = kitMotionPalette(KitMotionFamily.Digital, dark: true)
        VStack {
            kitBounce("bounce", 1, palette).height(90.px)
            kitTerminal("terminal", 1, palette).height(120.px)
            kitRollingNumber("number", Int64.Min, palette).height(80.px)
            kitFocusLight("light", palette, focusKey: "owner").height(110.px)
            kitChoreography("sequence", true, palette).height(110.px)
            kitArchive("archive", 1, palette).height(140.px)
            kitCascade("cascade", 1, true) { Button("Replay", {=> ()}).key("owner") }
            kitMotionStudy("combined", KitMotionFamily.Bounce, palette).height(90.px)
        }
    }
    if (!report.contains("\"ok\":true") || !report.contains(Int64.Min.toString())) { return 3 }
    println("Public motion consumer passed: transparent context, clip recovery, five families, exact Int64")
    0
}
