package chui.core

import sdl.{Color, Insets}

/* One retained track per scalar property, not per measure/layout invocation. Initial placement and
 * reduced motion snap. A new target starts at the last presented value, so an idle frame's potentially
 * large delta cannot consume a newly requested transition before its first visible frame. */
private class PropertyMotionTrack {
    private let animator = Animator(0.0)
    private var initialized = false
    private var sampledAt: UInt64 = 0

    func sample(ctx: UiContext, target: Float32, spec: AnimationSpec): Float32 {
        if (!initialized || ctx.theme.reduceMotion) {
            initialized = true
            animator.reset(target)
            sampledAt = ctx.frame.elapsedMs
            return target
        }
        if (animator.goal != target) {
            animator.target(target)
            sampledAt = ctx.frame.elapsedMs
        } else if (sampledAt != ctx.frame.elapsedMs) {
            sampledAt = ctx.frame.elapsedMs
            animator.animate(ctx, target: target, spec: spec)
        }
        if (!animator.settled()) { ctx.requestFrame() }
        animator.value
    }
}

/* The modifier chain owns the property channels. No global ticker, worker or animation State writes. */
class ModifierPropertyMotion {
    private let tracks = Array<PropertyMotionTrack>(6, {_ => PropertyMotionTrack()})

    func scalar(ctx: UiContext, slot: Int64, target: Float32, spec: AnimationSpec): Float32 {
        tracks[slot].sample(ctx, target, spec)
    }

    func color(ctx: UiContext, value: Color, spec: AnimationSpec): Color {
        Color(channel(ctx, 0, value.r, spec), channel(ctx, 1, value.g, spec),
            channel(ctx, 2, value.b, spec), channel(ctx, 3, value.a, spec))
    }

    func insets(ctx: UiContext, value: Insets, spec: AnimationSpec): Insets {
        Insets(scalar(ctx, 0, value.top, spec), scalar(ctx, 1, value.right, spec),
            scalar(ctx, 2, value.bottom, spec), scalar(ctx, 3, value.left, spec))
    }

    private func channel(ctx: UiContext, slot: Int64, value: UInt8, spec: AnimationSpec): UInt8 {
        UInt8(Int64(max(0.0, min(255.0, scalar(ctx, slot, Float32(Int64(value)), spec))) + 0.5))
    }
}

protected func applyPropertyAnimation(widget: Widget, key: String, spec: AnimationSpec,
    index!: Int64 = 0): Widget {
    requireControlId(key, "animateProperties")
    match (widget as ModifiedWidget) {
        case Some(modified) => modified.configurePropertyAnimation(key, spec, index)
        case None => ()
    }
    widget
}
