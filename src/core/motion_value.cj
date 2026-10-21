package chui.core

/** A retained, interruptible scalar sampled at most once per presented frame.
 * Keep it in rememberState or an application model. First use and retargeting start
 * from the current value; an idle frame never consumes a new segment. Reduced
 * motion snaps even when an explicit timing was supplied. Timings cap at one
 * day per delay/segment and intermediate arithmetic uses Float64.
 */
public class MotionValue {
    private var current: Float32
    private var start: Float32
    private var goal: Float32
    private var elapsed: UInt64 = 0
    private var moving = false
    private var timing = AnimationSpec.automatic()
    private var sampledAt: ?UInt64 = None

    public init(value: Float32) {
        requireFiniteMotion(value)
        current = value
        start = value
        goal = value
    }

    public prop value: Float32 { get() { current } }
    public func settled(): Bool { !moving }

    /** Cancels any pending segment. It does not request another frame. */
    public func reset(value: Float32): Unit {
        requireFiniteMotion(value)
        current = value; start = value; goal = value
        elapsed = 0; moving = false; sampledAt = None
    }

    public func animate(ctx: UiContext, target!: Float32,
        spec!: AnimationSpec = AnimationSpec.automatic()): Float32 {
        requireFiniteMotion(target)
        if (ctx.theme.reduceMotion) {
            reset(target)
            sampledAt = Some(ctx.frame.elapsedMs)
            return current
        }
        let fresh = match (sampledAt) {
            case Some(stamp) => stamp != ctx.frame.elapsedMs
            case None => false
        }
        if (fresh && moving) {
            let duration = min(timing.resolvedDuration(ctx.theme.motionLevel), UInt64(86400000))
            let delay = min(timing.delay, UInt64(86400000))
            let total = duration + delay
            elapsed = min(total, elapsed + min(ctx.frame.deltaMs, UInt64(172800000)))
            if (elapsed >= total) {
                current = goal; moving = false
            } else {
                let t = (Float64(Int64(elapsed)) - Float64(Int64(delay))) / Float64(Int64(duration))
                let eased = timing.easing.ease(Float32(t))
                if (!(eased >= -Float32.Max && eased <= Float32.Max)) {
                    reset(goal)
                    throw IllegalArgumentException("Motion easing must produce a finite value")
                }
                let result = Float64(start) + (Float64(goal) - Float64(start)) * Float64(eased)
                current = Float32(max(-Float64(Float32.Max), min(Float64(Float32.Max), result)))
            }
        }
        sampledAt = Some(ctx.frame.elapsedMs)
        if (target != goal) {
            start = current; goal = target; elapsed = 0; moving = current != goal
            timing = spec
        }
        if (moving) { ctx.requestFrame() }
        recordProbeAnimation(ctx, "motion-value", timing.duration, easingName(timing.easing), current, goal)
        current
    }
}

private func requireFiniteMotion(value: Float32): Unit {
    if (!(value >= -Float32.Max && value <= Float32.Max)) {
        throw IllegalArgumentException("Motion value must be finite")
    }
}
