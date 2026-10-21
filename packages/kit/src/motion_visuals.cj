package canghui_kit

import chui.*

/** A finite bounce study. Increment replay to restart; it sleeps after landing. */
public func kitBounce(key: String, replay: UInt64, palette: KitMotionPalette): Widget {
    let motion = rememberState<KitReplayMotion>("KitBounce:${key}") {KitReplayMotion()}.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        kitPlate(ctx, rect, palette, radius: 28.0)
        let p = motion.sample(ctx, replay, AnimationSpec.automatic(duration: 960, easing: Easing.EaseOutBounce))
        let floor = rect.bottom() - 50.0
        let drop = max(0.0, rect.h - 120.0)
        let radius = min(26.0, max(8.0, rect.w * 0.075))
        let x = rect.centerX()
        let y = floor - drop * (1.0 - p)
        ctx.renderer.fillRoundedRect(Rect(x - 46.0, floor + radius - 3.0, 92.0, 8.0), 4.0,
            palette.signal.withAlpha(Int64(28.0 + p * 50.0)))
        ctx.renderer.fillCircle(x, y, radius, palette.signal)
        ctx.renderer.fillCircle(x - radius * 0.25, y - radius * 0.3, radius * 0.28,
            palette.ink.withAlpha(32))
        ctx.renderer.strokeLine(rect.x + 30.0, floor + radius + 10.0, rect.right() - 30.0,
            floor + radius + 10.0, Pen(width: 1.0, color: palette.muted.withAlpha(95)))
        ctx.renderer.text("01 / SOFT LANDING", rect.x + 24.0, rect.y + 24.0,
            palette.muted, pointSize: 11.0)
    }, transparent: true).probe(key, "KitBounce")
}

/** One-shot scan and terminal grid. It does not create a perpetual timer. */
public func kitTerminal(key: String, replay: UInt64, palette: KitMotionPalette): Widget {
    let motion = rememberState<KitReplayMotion>("KitTerminal:${key}") {KitReplayMotion()}.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        kitPlate(ctx, rect, palette, radius: 6.0)
        let p = motion.sample(ctx, replay, AnimationSpec.automatic(duration: 1200, easing: Easing.Linear))
        let inner = rect.inset(24.0)
        for (i in 0..12) {
            let x = inner.x + inner.w * Float32(i) / 11.0
            ctx.renderer.strokeLine(x, inner.y, x, inner.bottom(), Pen(width: 1.0,
                color: palette.signal.withAlpha(12)))
        }
        ctx.renderer.text("LIVE / SIGNAL MONITOR", inner.x, inner.y, palette.signal, pointSize: 11.0)
        let lines = ["CHANNEL 01  /  RECEIVING", "SYNC ............ READY", "PACKET WINDOW / STABLE"]
        for (i in 0..lines.size) {
            let visible = min(1.0, max(0.0, p * 3.6 - Float32(i) * 0.7))
            let row = Rect(inner.x, inner.y + 42.0 + Float32(i) * 30.0, inner.w * visible, 24.0)
            if (row.w > 0.0) {
                ctx.renderer.pushClip(row)
                try { ctx.renderer.text(lines[i], row.x, row.y, palette.ink, pointSize: 13.0) }
                finally { ctx.renderer.popClip() }
            }
        }
        if (p < 1.0 && !ctx.theme.reduceMotion) {
            let y = inner.y + p * inner.h
            ctx.renderer.fill(Rect(inner.x, y, inner.w, 2.0), palette.signal.withAlpha(160))
            ctx.renderer.fill(Rect(inner.x, y - 8.0, inner.w, 8.0), palette.signal.withAlpha(18))
        }
    }, transparent: true).probe(key, "KitTerminal")
}

internal class KitFocusMotion {
    let x = MotionValue(0.5)
    let y = MotionValue(0.5)
    let strength = MotionValue(0.0)
    var windowActive = true

    func observe(event: UiEvent): Bool {
        match (event) { case UiEvent.WindowFocusChanged(value) => windowActive = value case _ => () }
        false
    }

    func update(ctx: UiContext, rect: Rect, focused: Bool): Unit {
        let pointed = rect.contains(ctx.mouseX, ctx.mouseY)
        let active = windowActive && ctx.interactionsEnabled() && (pointed || focused)
        let spec = AnimationSpec.automatic(duration: 180, easing: Easing.EaseOutCubic)
        let px: Float32 = if (pointed) {max(0.0, min(1.0, (ctx.mouseX - rect.x) / max(1.0, rect.w)))} else {0.5}
        let py: Float32 = if (pointed) {max(0.0, min(1.0, (ctx.mouseY - rect.y) / max(1.0, rect.h)))} else {0.5}
        x.animate(ctx, target: if (active) {px} else {x.value}, spec: spec)
        y.animate(ctx, target: if (active) {py} else {y.value}, spec: spec)
        strength.animate(ctx, target: if (active) {1.0} else {0.0}, spec: spec)
        ()
    }
}

/** Passive local lighting. A focusKey can follow an existing keyboard owner;
 * this painter never acquires focus or consumes the pointer's events.
 */
public func kitFocusLight(key: String, palette: KitMotionPalette, focusKey!: ?String = None): Widget {
    let motion = rememberState<KitFocusMotion>("KitFocusLight:${key}") {KitFocusMotion()}.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        kitPlate(ctx, rect, palette, radius: 28.0)
        let focused = match (focusKey) { case Some(owner) => ctx.hasFocus(owner) case None => false }
        motion.update(ctx, rect, focused)
        let x = motion.x.value
        let y = motion.y.value
        let strength = motion.strength.value
        let radius = min(rect.w, rect.h) * 0.7
        for (i in 0..24) {
            let f = 1.0 - Float32(i) / 24.0
            ctx.renderer.fillCircle(rect.x + rect.w * x, rect.y + rect.h * y,
                max(0.0, radius * f), palette.signal.withAlpha(Int64(strength * (1.0 - f) * 5.0)))
        }
        let card = Rect(rect.x + 28.0, rect.centerY() - 45.0, max(0.0, rect.w - 56.0), 90.0)
        ctx.renderer.fillRoundedRect(card, 20.0, palette.background.withAlpha(130))
        ctx.renderer.strokeRoundedRect(card, 20.0, Pen(width: 1.0, color: palette.ink.withAlpha(28)))
        ctx.renderer.text(if (rect.w < 380.0) {"Room to focus."} else {"A little more depth."}, card.x + 20.0, card.y + 20.0, palette.ink, pointSize: 18.0)
        ctx.renderer.text(if (rect.w < 380.0) {"Follow the light"} else {"Move your pointer across the surface"}, card.x + 20.0, card.y + 54.0,
            palette.muted, pointSize: 11.0)
    }, transparent: true, onEvent: {event, _ =>
        motion.observe(event)
    }).probe(key, "KitFocusLight")
}

/** Shared-axis entry study with staggered, interruptible tracks. */
public func kitChoreography(key: String, shown: Bool, palette: KitMotionPalette): Widget {
    let motions = rememberState<Array<MotionValue>>("KitChoreography:${key}") {
        Array<MotionValue>(4, {_ => MotionValue(0.0)})
    }.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        kitPlate(ctx, rect, palette)
        ctx.renderer.text("01  /  ARRIVE TOGETHER", rect.x + 24.0, rect.y + 24.0,
            palette.muted, pointSize: 11.0)
        let gap = Float32(12.0)
        let width = max(0.0, (rect.w - 48.0 - 3.0 * gap) / 4.0)
        for (i in 0..4) {
            let p = motions[i].animate(ctx, target: if (shown) {1.0} else {0.0},
                spec: AnimationSpec.automatic(duration: 460, delay: UInt64(i * 70),
                    easing: Easing.CubicBezier(0.2, 0.0, 0.0, 1.0)))
            let h = max(0.0, rect.h - 112.0) * (0.52 + Float32(i) * 0.16)
            let card = Rect(rect.x + 24.0 + Float32(i) * (width + gap),
                rect.bottom() - 28.0 - h + (1.0 - p) * 32.0, width, h)
            ctx.renderer.fillRoundedRect(card, 12.0, palette.signal.withAlpha(Int64(p * (100.0 + Float32(i) * 40.0))))
            if (p > 0.0) {
                ctx.renderer.text("0${i + 1}", card.x + 10.0, card.y + 14.0,
                    palette.ink.withAlpha(Int64(p * 255.0)), pointSize: 14.0)
            }
        }
    }, transparent: true).probe(key, "KitChoreography")
}

/** Fine rules, warm signal and staged document reveal. Original 2D artwork. */
public func kitArchive(key: String, replay: UInt64, palette: KitMotionPalette): Widget {
    let motion = rememberState<KitReplayMotion>("KitArchive:${key}") {KitReplayMotion()}.value
    CanvasWidget(onDrawContext: {ctx, rect =>
        kitPlate(ctx, rect, palette, radius: 2.0)
        let p = motion.sample(ctx, replay, AnimationSpec.automatic(duration: 1100, easing: Easing.EaseInOutCubic))
        let inner = rect.inset(24.0)
        let pen = Pen(width: 1.0, color: palette.muted.withAlpha(100))
        ctx.renderer.text("OBSERVATION / 042", inner.x, inner.y, palette.ink, pointSize: 12.0)
        ctx.renderer.fill(Rect(inner.right() - 8.0, inner.y, 8.0, 8.0), palette.signal)
        ctx.renderer.strokeLine(inner.x, inner.y + 30.0, inner.right(), inner.y + 30.0, pen)
        let cx = inner.x + min(72.0, inner.w * 0.22)
        let cy = inner.centerY() + 12.0
        let radius = max(0.0, min(inner.w * 0.18, inner.h * 0.31))
        ctx.renderer.strokeCircle(cx, cy, radius, pen)
        ctx.renderer.strokeCircle(cx, cy, radius * 0.64, Pen(width: 1.5, color: palette.signal))
        ctx.renderer.strokeLine(cx - radius * 1.15, cy, cx + radius * 1.15, cy, pen)
        ctx.renderer.strokeLine(cx, cy - radius * 1.15, cx, cy + radius * 1.15, pen)
        let textX = inner.x + inner.w * 0.43
        let reveal = Rect(textX, inner.y + 52.0, max(0.0, inner.right() - textX) * p,
            max(0.0, inner.h - 52.0))
        if (reveal.w > 0.0) {
            ctx.renderer.pushClip(reveal)
            try {
                ctx.renderer.text(if (rect.w < 380.0) {"NOTES"} else {"FIELD NOTES"}, textX, reveal.y, palette.ink, pointSize: 20.0)
                ctx.renderer.text("Material study", textX, reveal.y + 37.0, palette.muted, pointSize: 12.0)
                ctx.renderer.strokeLine(textX, reveal.y + 65.0, inner.right(), reveal.y + 65.0, pen)
                ctx.renderer.text("CLASS / 02", textX, reveal.y + 83.0, palette.signal, pointSize: 11.0)
            } finally { ctx.renderer.popClip() }
        }
        if (p > 0.0 && p < 1.0) {
            ctx.renderer.fill(Rect(reveal.right(), reveal.y, 2.0, reveal.h), palette.signal.withAlpha(170))
        }
    }, transparent: true).probe(key, "KitArchive")
}
