package chui.scene3d

import chui.core.{Theme, UiContext}
import chui.host.{NativeSurfaceBackend, NativeSurfaceDescriptor, NativeSurfaceEvent, NativeSurfaceFrame}
import sdl.{GamepadButton, MouseButton, Rect, Renderer, Size, UiEvent}

private class TestFrameSource <: Scene3DViewFrameSource {
    var calls: Int64 = 0

    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        calls += 1
        let snapshot = Scene3DFrameSnapshot("frame-${clock.frameId}")
        snapshot.add(Scene3DEntitySnapshot("entity-${clock.frameId}", 0.0, 0.0, 0.0))
        snapshot
    }
}

private class TestInputRecorder {
    var calls: Int64 = 0
    var localX: Float32 = -1.0
    var localY: Float32 = -1.0
    var lastKind = ""

    func accept(event: Scene3DViewInputEvent): Bool {
        calls += 1
        match (event) {
            case Scene3DViewInputEvent.PointerDown(x, y, _) =>
                localX = x
                localY = y
                lastKind = "pointer-down"
            case Scene3DViewInputEvent.GamepadButtonDown(_, button) =>
                lastKind = match (button) {
                    case GamepadButton.South => "gamepad-south"
                    case _ => "gamepad-other"
                }
            case Scene3DViewInputEvent.GamepadAxisMotion(_, _, _) => lastKind = "gamepad-axis"
            case _ => lastKind = "other"
        }
        true
    }
}

@Test
func scene3DViewControllerBridgesHostLifecycleAndFrames(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let frames = TestFrameSource()
    let controller = Scene3DViewController("metro", host, provider, testResource(), frames)

    @Expect(!controller.isAttached())
    host.publish(NativeSurfaceEvent.Available(testSurface(1, 640.0, 480.0)))
    @Expect(controller.isAttached())
    @Expect(controller.currentGeneration(), Int64(1))
    @Expect(controller.lifecycleReceipt().operation, "load-scene")
    @Expect(controller.lifecycleReceipt().ok)

    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(7, 100, 116)))
    @Expect(frames.calls, Int64(1))
    @Expect(controller.currentFrameId(), Int64(7))
    @Expect(provider.currentSceneId(), "frame-7")
    @Expect(controller.lifecycleReceipt().operation, "present")

    host.publish(NativeSurfaceEvent.Changed(testSurface(1, 800.0, 600.0)))
    @Expect(controller.lifecycleReceipt().operation, "resize")
    @Expect(controller.lifecycleReceipt().ok)

    host.publish(NativeSurfaceEvent.Unavailable("surface", 1))
    @Expect(!controller.isAttached())
    @Expect(controller.lifecycleReceipt().operation, "detach")
}

@Test
func scene3DViewControllerRejectsStaleGenerationAndDeduplicatesPlacement(): Unit {
    let host = FakeScene3DViewHost()
    let provider = FakeScene3DProvider()
    let controller = Scene3DViewController("scene", host, provider, testResource(), TestFrameSource())
    let rect = Rect(20.0, 30.0, 320.0, 180.0)

    @Expect(controller.place(rect, 2.0).code, "accepted")
    @Expect(controller.place(rect, 2.0).code, "unchanged")
    @Expect(host.placementCount(), Int64(1))

    host.publish(NativeSurfaceEvent.Available(testSurface(2, 320.0, 180.0)))
    controller.resize(testSurface(1, 640.0, 360.0))
    @Expect(controller.lifecycleReceipt().code, "stale-generation")
    @Expect(controller.isAttached())
    controller.detach("surface", 1)
    @Expect(controller.lifecycleReceipt().code, "stale-generation")
    @Expect(controller.isAttached())

    @Expect(controller.remove().ok)
    @Expect(controller.remove().code, "already-removed")
}

@Test
func scene3DViewLocalizesPointerAndRoutesGamepadOnlyWhileFocused(): Unit {
    let host = FakeScene3DViewHost()
    let recorder = TestInputRecorder()
    let controller = Scene3DViewController("interactive-scene", host, FakeScene3DProvider(), testResource(),
        TestFrameSource(), onInput: { event => recorder.accept(event) })
    let view = Scene3DView(controller, width: 300.0, height: 200.0)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.displayScale = 2.0

    @Expect(view.measure(ctx, Size(500.0, 400.0)).w, Float32(300.0))
    view.layout(ctx, Rect(40.0, 60.0, 300.0, 200.0))
    @Expect(host.currentPlacement().getOrThrow().scale, Float32(2.0))

    @Expect(!view.handle(ctx, UiEvent.GamepadButtonDown(UInt32(4), GamepadButton.South)))
    @Expect(recorder.calls, Int64(0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 75.0, 92.0)))
    @Expect(ctx.hasFocus("interactive-scene"))
    @Expect(recorder.localX, Float32(35.0))
    @Expect(recorder.localY, Float32(32.0))
    @Expect(recorder.lastKind, "pointer-down")

    @Expect(view.handle(ctx, UiEvent.GamepadButtonDown(UInt32(4), GamepadButton.South)))
    @Expect(recorder.lastKind, "gamepad-south")
    @Expect(recorder.calls, Int64(2))
}

private func testResource(): Scene3DResource {
    Scene3DResource("metro-scene", "memory://metro", "sha256:test", 0)
}

private func testSurface(generation: Int64, width: Float32, height: Float32): NativeSurfaceDescriptor {
    NativeSurfaceDescriptor("surface", NativeSurfaceBackend.Metal, UInt64(99), width, height,
        Int64(width * 2.0), Int64(height * 2.0), 2.0, generation)
}
