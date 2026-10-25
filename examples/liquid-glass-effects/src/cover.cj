package chui_liquid_glass_effects

import std.collection.ArrayList
import chui.*

/**
 * Cover art drawn as line-work silhouettes.
 *
 * The reference image is a photograph, which this repository deliberately does not ship. Line
 * silhouettes are the honest substitute: they give the glass real hard edges and a human subject to
 * bend, without pretending to be a photo or importing an external asset.
 *
 * Layout follows the reference: one dominant subject on the left of the cover, a second, smaller
 * subject to its right, lettering above them, and the whole mass sitting on a saturated gradient.
 */
class CoverArt <: Widget {
    private var frame = Rect.zero()

    init() {
        // Required: a custom Widget only joins the declarative tree when it emits itself.
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        // Fall back to the window box when the parent offers an unconstrained axis, otherwise the
        // cover would measure to zero and never paint.
        Size(
            if (available.w > 0.0) { available.w } else { 920.0 },
            if (available.h > 0.0) { available.h } else { 600.0 })
    }

    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }

    public func draw(ctx: UiContext): Unit {
        drawSaturatedBase(ctx)
        // Left subject is the dominant figure, matching the reference's larger portrait.
        drawHead(ctx, frame.x + frame.w * 0.15, frame.y + frame.h * 0.40,
            frame.h * 0.215, Color.rgba(20, 10, 26, 244), Color.rgba(242, 176, 158, 240))
        drawHead(ctx, frame.x + frame.w * 0.40, frame.y + frame.h * 0.44,
            frame.h * 0.185, Color.rgba(40, 18, 50, 238), Color.rgba(222, 142, 146, 232))
        drawWarmBounce(ctx)
        drawLettering(ctx)
    }

    public func handle(_: UiContext, _: UiEvent): Bool { false }

    /** Deep violet to warm lilac, the tonal base of the reference cover. */
    private func drawSaturatedBase(ctx: UiContext): Unit {
        // Use the renderer's real gradient instead of stacked bands: hand-banding left visible
        // horizontal seams, which are exactly the artifact a glass layer must not amplify.
        ctx.renderer.fillRoundedRectGradient(frame, 0.0,
            Color.rgb(48, 20, 58), Color.rgb(206, 150, 190), vertical: true)
        ctx.renderer.fillRoundedRectGradient(frame, 0.0,
            Color.rgba(112, 44, 120, 96), Color.rgba(250, 190, 186, 24), vertical: false)
    }

    /**
     * One subject as a hard-edged silhouette built only from straight segments: hair mass, angular
     * face, broad shoulders and a torso that leaves through the bottom edge. Shoulders are the
     * widest point of the torso, which is what makes a trapezoid read as a person instead of a cone.
     */
    private func drawHead(ctx: UiContext, cx: Float32, cy: Float32, size: Float32,
        hair: Color, skin: Color): Unit {
        let w = size
        let h = size * 1.30
        let crownY = cy - h * 0.50
        let templeY = cy - h * 0.18
        let cheekY = cy + h * 0.10
        let jawY = cy + h * 0.34
        let neckY = cy + h * 0.60
        let shoulderY = cy + h * 0.80
        let bottom = frame.y + frame.h

        // Torso: broad at the shoulders, nearly straight down, clipped by the frame bottom.
        ctx.renderer.fillPolygon([
            Point(frame.x + cx - w * 0.30, neckY),
            Point(frame.x + cx - w * 0.95, shoulderY),
            Point(frame.x + cx - w * 1.02, bottom),
            Point(frame.x + cx + w * 1.02, bottom),
            Point(frame.x + cx + w * 0.95, shoulderY),
            Point(frame.x + cx + w * 0.30, neckY)
        ], hair)

        // Neck: short and narrow, bridging jaw to shoulders.
        ctx.renderer.fillPolygon([
            Point(frame.x + cx - w * 0.17, jawY),
            Point(frame.x + cx + w * 0.17, jawY),
            Point(frame.x + cx + w * 0.20, neckY),
            Point(frame.x + cx - w * 0.20, neckY)
        ], skin)

        // Hair: a solid mass over the crown falling past the temples on both sides.
        ctx.renderer.fillPolygon([
            Point(frame.x + cx, crownY),
            Point(frame.x + cx + w * 0.30, crownY + h * 0.10),
            Point(frame.x + cx + w * 0.40, templeY + h * 0.16),
            Point(frame.x + cx + w * 0.34, shoulderY),
            Point(frame.x + cx + w * 0.20, shoulderY),
            Point(frame.x + cx + w * 0.22, cheekY),
            Point(frame.x + cx - w * 0.22, cheekY),
            Point(frame.x + cx - w * 0.20, shoulderY),
            Point(frame.x + cx - w * 0.34, shoulderY),
            Point(frame.x + cx - w * 0.40, templeY + h * 0.16),
            Point(frame.x + cx - w * 0.30, crownY + h * 0.10)
        ], hair)

        // Face: angular octagon, jaw narrow, cheekbones wide.
        rendererPolygon(ctx, skin, frame, [
            (cx - w * 0.09, jawY), (cx + w * 0.09, jawY),
            (cx + w * 0.24, cheekY), (cx + w * 0.27, templeY),
            (cx + w * 0.16, crownY + h * 0.06), (cx - w * 0.16, crownY + h * 0.06),
            (cx - w * 0.27, templeY), (cx - w * 0.24, cheekY)
        ])

        // Brows, eyes and mouth as short segments: enough to read as a face.
        let browY = cy - h * 0.06
        let eyeY = cy + h * 0.00
        ctx.renderer.line(cx - w * 0.21, browY, cx - w * 0.04, browY, hair)
        ctx.renderer.line(cx + w * 0.04, browY, cx + w * 0.21, browY, hair)
        ctx.renderer.fillPolygon([
            Point(frame.x + cx - w * 0.20, eyeY - h * 0.012),
            Point(frame.x + cx - w * 0.05, eyeY - h * 0.012),
            Point(frame.x + cx - w * 0.05, eyeY + h * 0.012),
            Point(frame.x + cx - w * 0.20, eyeY + h * 0.012)
        ], Color.rgba(18, 8, 22, 240))
        ctx.renderer.fillPolygon([
            Point(frame.x + cx + w * 0.05, eyeY - h * 0.012),
            Point(frame.x + cx + w * 0.20, eyeY - h * 0.012),
            Point(frame.x + cx + w * 0.20, eyeY + h * 0.012),
            Point(frame.x + cx + w * 0.05, eyeY + h * 0.012)
        ], Color.rgba(18, 8, 22, 240))
        ctx.renderer.line(cx - w * 0.03, cy + h * 0.14, cx + w * 0.03, cy + h * 0.14,
            Color.rgba(146, 48, 58, 230))
        ctx.renderer.line(cx, cy + h * 0.12, cx, cy + h * 0.18, skin)
    }

    private func rendererPolygon(ctx: UiContext, fill: Color, frame: Rect,
        points: Array<(Float32, Float32)>): Unit {
        let polygon = ArrayList<Point>()
        var i = 0
        while (i < points.size) {
            let p = points[i]
            polygon.add(Point(frame.x + p[0], frame.y + p[1]))
            i += 1
        }
        ctx.renderer.fillPolygon(polygon.toArray(), fill)
    }

    /** Warm bounce along the lower edge, matching the reference cover's lighting falloff. */
    private func drawWarmBounce(ctx: UiContext): Unit {
        let steps: Int64 = 26
        var index: Int64 = 0
        while (index < steps) {
            let t = Float32(index) / Float32(steps)
            let y = frame.y + frame.h * (0.58 + 0.42 * t)
            let h = frame.h * 0.42 / Float32(steps) + 1.0
            let alpha = Int64(58.0 * t)
            ctx.renderer.fill(Rect(frame.x, y, frame.w, h),
                Color.rgba(246, 186, 168, alpha))
            index += 1
        }
    }

    /** Script-style cover lettering, the reference's most recognisable non-photo element. */
    private func drawLettering(ctx: UiContext): Unit {
        let ink = Color.rgba(158, 54, 66, 226)
        ctx.renderer.text("until", frame.x + frame.w * 0.10, frame.y + frame.h * 0.10,
            ink, pointSize: 34.0)
        ctx.renderer.text("I found you", frame.x + frame.w * 0.065, frame.y + frame.h * 0.175,
            ink, pointSize: 28.0)
    }
}
