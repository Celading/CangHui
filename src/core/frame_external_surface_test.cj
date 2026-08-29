package chui.core

import sdl.{Rect, Renderer}

@Test
func nativeChildFrameSurfaceRegistrationIsHandleFreeAndFrameScoped(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.beginFrameSurfaceRegistration()
    ctx.registerNativeChildFrameSurface("scene", 2, Rect(10.0, 20.0, 80.0, 60.0))
    @Expect(ctx.nativeChildFrameSurfaceCount(), 1)
    let value = ctx.nativeChildFrameSurfaceAt(0)
    @Expect(value.identity, "scene")
    @Expect(value.generation, 2)
    @Expect(value.bounds.x, 10.0)
    @Expect(value.bounds.y, 20.0)
    @Expect(value.bounds.w, 80.0)
    @Expect(value.bounds.h, 60.0)
    ctx.beginFrameSurfaceRegistration()
    @Expect(ctx.nativeChildFrameSurfaceCount(), 0)
}
