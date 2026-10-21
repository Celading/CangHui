package canghui_kit

import chui.*

/** Independent visual recipes; the host still owns navigation and state. */
public enum KitMotionFamily {
    | Bounce
    | Digital
    | FocusLight
    | Choreography
    | Archive

    public func title(): String {
        match (this) {
            case Bounce => "Soft landing"
            case Digital => "Signal terminal"
            case FocusLight => "Light follows attention"
            case Choreography => "Everything, in sequence"
            case Archive => "The observation archive"
        }
    }

    public func name(): String {
        match (this) {
            case Bounce => "bounce"
            case Digital => "digital"
            case FocusLight => "focus-light"
            case Choreography => "choreography"
            case Archive => "archive"
        }
    }
}

public struct KitMotionPalette {
    public let background: Color
    public let surface: Color
    public let ink: Color
    public let signal: Color
    public let muted: Color

    public init(background: Color, surface: Color, ink: Color, signal: Color, muted: Color) {
        this.background = background; this.surface = surface; this.ink = ink
        this.signal = signal; this.muted = muted
    }
}

/** Original palettes. No platform-private materials or branded artwork. */
public func kitMotionPalette(family: KitMotionFamily, dark!: Bool = false): KitMotionPalette {
    match (family) {
        case KitMotionFamily.Bounce => if (dark) {
            KitMotionPalette(Color(31, 24, 41), Color(47, 35, 57), Color(255, 235, 220),
                Color(255, 174, 122), Color(183, 159, 187))
        } else {
            KitMotionPalette(Color(248, 239, 233), Color(255, 247, 240), Color(57, 40, 61),
                Color(215, 115, 77), Color(126, 103, 119))
        }
        case KitMotionFamily.Digital => if (dark) {
            KitMotionPalette(Color(8, 22, 23), Color(12, 31, 31), Color(182, 241, 207),
                Color(85, 225, 160), Color(104, 155, 136))
        } else {
            KitMotionPalette(Color(230, 241, 231), Color(241, 250, 240), Color(26, 63, 47),
                Color(26, 132, 81), Color(86, 124, 102))
        }
        case KitMotionFamily.FocusLight => if (dark) {
            KitMotionPalette(Color(15, 24, 40), Color(24, 39, 59), Color(225, 241, 255),
                Color(133, 191, 255), Color(141, 166, 193))
        } else {
            KitMotionPalette(Color(227, 237, 247), Color(245, 250, 255), Color(30, 53, 79),
                Color(83, 137, 211), Color(108, 130, 157))
        }
        case KitMotionFamily.Choreography => if (dark) {
            KitMotionPalette(Color(27, 21, 42), Color(39, 30, 57), Color(240, 228, 255),
                Color(184, 151, 255), Color(158, 137, 183))
        } else {
            KitMotionPalette(Color(240, 234, 250), Color(252, 248, 255), Color(58, 35, 87),
                Color(132, 84, 210), Color(133, 113, 156))
        }
        case KitMotionFamily.Archive => if (dark) {
            KitMotionPalette(Color(31, 32, 30), Color(42, 43, 39), Color(238, 235, 221),
                Color(221, 177, 103), Color(167, 164, 146))
        } else {
            KitMotionPalette(Color(239, 237, 226), Color(248, 246, 236), Color(43, 47, 42),
                Color(173, 127, 58), Color(127, 129, 111))
        }
    }
}

internal class KitReplayMotion {
    private var revision: ?UInt64 = None
    private let motion = MotionValue(0.0)

    func sample(ctx: UiContext, replay: UInt64, spec: AnimationSpec): Float32 {
        let changed = match (revision) { case Some(value) => value != replay case None => true }
        if (changed) { motion.reset(0.0); revision = Some(replay) }
        motion.animate(ctx, target: 1.0, spec: spec)
    }
}

internal func kitPlate(ctx: UiContext, rect: Rect, palette: KitMotionPalette, radius!: Float32 = 20.0): Unit {
    ctx.renderer.fillRoundedRect(rect, radius, palette.surface)
    ctx.renderer.strokeRoundedRect(rect.inset(0.5), radius,
        Pen(width: 1.0, color: palette.muted.withAlpha(48)))
}

/** Slot composition: actual controls keep their existing input/focus owner. */
public func kitCascade(key: String, index: Int64, expanded: Bool, content: () -> Unit): Widget {
    let delay = UInt64(min(max(index, Int64(0)), Int64(64)) * 45)
    VStack(spacing: 0.vp, body: content).hug()
        .padding(0.0, if (expanded) {0.0} else {12.0}, 0.0, 0.0)
        .animateProperties(key, AnimationSpec.automatic(duration: 360,
            easing: Easing.CubicBezier(0.2, 0.0, 0.0, 1.0), delay: delay))
}
