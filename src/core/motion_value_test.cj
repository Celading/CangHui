package chui.core

import sdl.{FrameInfo, Renderer}

@Test
func motionValueDeduplicatesAndRetargetsFromThePresentedValue(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let track = MotionValue(0.0)
    let spec = AnimationSpec(duration: 100, easing: Easing.Linear)
    @Expect(track.animate(ctx, target: 1.0, spec: spec), Float32(0.0))
    ctx.frame = FrameInfo(16, 16)
    let first = track.animate(ctx, target: 1.0, spec: spec)
    @Expect(first > 0.0 && first < 1.0)
    for (_ in 0..20) { @Expect(track.animate(ctx, target: 1.0, spec: spec), first) }
    @Expect(track.animate(ctx, target: -1.0, spec: spec), first)
    ctx.frame = FrameInfo(32, 16)
    @Expect(track.animate(ctx, target: -1.0, spec: spec) < first)
}

@Test
func motionValueDoesNotEatNewSegmentsAfterIdleOrOnFirstUse(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let track = MotionValue(0.0)
    let spec = AnimationSpec(duration: 100, easing: Easing.Linear)
    track.animate(ctx, target: 0.0, spec: spec)
    ctx.frame = FrameInfo(1000000, 1000000)
    @Expect(track.animate(ctx, target: 1.0, spec: spec), Float32(0.0))
    let fresh = MotionValue(0.0)
    @Expect(fresh.animate(ctx, target: 1.0, spec: spec), Float32(0.0))
    ctx.frame = FrameInfo(1000016, 16)
    @Expect(track.animate(ctx, target: 1.0, spec: spec) > 0.0)
}

@Test
func motionValueKeepsProgressWhileTargetsChangeEveryFrame(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let track = MotionValue(0.0)
    let spec = AnimationSpec(duration: 100, easing: Easing.Linear)
    track.animate(ctx, target: 1.0, spec: spec)
    for (i in 1..20) {
        ctx.frame = FrameInfo(UInt64(i * 16), 16)
        track.animate(ctx, target: Float32(i + 1), spec: spec)
    }
    @Expect(track.value > 5.0)
}

@Test
func motionValueReducedMotionSnapsExplicitDurationAndDelayWithoutFrameRequests(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light(reduceMotion: true))
    let track = MotionValue(0.0)
    @Expect(track.animate(ctx, target: 10.0,
        spec: AnimationSpec(duration: 1000, delay: 900)), Float32(10.0))
    @Expect(track.settled())
    @Expect(!ctx.takeFrameRequest())
}

@Test
func motionValueClampsLongStallsAndIdlesAfterSettling(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let track = MotionValue(0.0)
    track.animate(ctx, target: 1.0)
    @Expect(ctx.takeFrameRequest())
    ctx.frame = FrameInfo(UInt64.Max, UInt64.Max)
    @Expect(track.animate(ctx, target: 1.0), Float32(1.0))
    @Expect(track.settled())
    @Expect(!ctx.takeFrameRequest())
    track.reset(8.0)
    @Expect(track.value, Float32(8.0))
    @Expect(track.settled())
}

@Test
func bounceCurveHasRealReboundsAndExactEndpoints(): Unit {
    @Expect(Easing.EaseOutBounce.ease(0.0), Float32(0.0))
    @Expect(Easing.EaseOutBounce.ease(1.0), Float32(1.0))
    @Expect(Easing.EaseOutBounce.ease(0.36) > Easing.EaseOutBounce.ease(0.55))
    for (i in 0..101) {
        let value = Easing.EaseOutBounce.ease(Float32(i) / 100.0)
        @Expect(value >= 0.0 && value <= 1.001)
    }
}

@Test
func motionValueHandlesExtremeFiniteEndpointsAndRejectsInfinity(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let motion = MotionValue(Float32.Max)
    let spec = AnimationSpec(duration: 100, easing: Easing.Linear)
    motion.animate(ctx, target: -Float32.Max, spec: spec)
    ctx.frame = FrameInfo(50, 50)
    let middle = motion.animate(ctx, target: -Float32.Max, spec: spec)
    @Expect(middle >= -Float32.Max && middle <= Float32.Max)
    let overflow = Float32.Max * Float32(2.0)
    var rejected = false
    try { let _ = MotionValue(overflow) } catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}

@Test
func motionValueKeepsOldSegmentTimingUntilAnActualNewTarget(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let motion = MotionValue(0.0)
    let old = AnimationSpec(duration: 100, easing: Easing.Linear)
    let next = AnimationSpec(duration: 1000, easing: Easing.Linear)
    motion.animate(ctx, target: 1.0, spec: old)
    ctx.frame = FrameInfo(50, 50)
    @Expect(motion.animate(ctx, target: 2.0, spec: next), Float32(0.5))
    ctx.frame = FrameInfo(150, 100)
    let value = motion.animate(ctx, target: 2.0, spec: old)
    @Expect(value > 0.64 && value < 0.66)
}
