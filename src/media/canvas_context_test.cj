package chui.media

import chui.core.{Theme, UiContext}
import sdl.{FrameInfo, Rect, Renderer, UiEvent}

@Test
func canvasCallbackExceptionRestoresTheEnclosingClip(): Unit {
    let r = Renderer.headless()
    let ctx = UiContext(r, Theme.light())
    r.pushClip(Rect(0.0, 0.0, 100.0, 100.0))
    let canvas = CanvasWidget({_, _ => throw IllegalStateException("paint failed")})
    canvas.layout(ctx, Rect(10.0, 10.0, 60.0, 60.0))
    var caught = false
    try { canvas.draw(ctx) } catch (_: IllegalStateException) { caught = true }
    @Expect(caught)
    @Expect(r.currentClip().getOrThrow().w, Float32(100.0))
    r.popClip()
    @Expect(r.currentClip().isNone())
}

@Test
func contextualTransparentCanvasReceivesClockAndRemainsPassive(): Unit {
    let r = Renderer.recordingHeadless()
    let ctx = UiContext(r, Theme.dark())
    ctx.frame = FrameInfo(42, 16)
    let seen = [false]
    let canvas = CanvasWidget(onDrawContext: {context, rect =>
        seen[0] = context.frame.elapsedMs == 42 && rect.x == 20.0
    }, transparent: true)
    canvas.layout(ctx, Rect(20.0, 30.0, 100.0, 100.0))
    canvas.draw(ctx)
    @Expect(seen[0])
    for (command in r.drawIr()) { @Expect(!command.kind.startsWith("paint.")) }
    @Expect(!canvas.handle(ctx, UiEvent.MouseMove(30.0, 40.0)))
    @Expect(canvas.focusableId().isNone())
}
