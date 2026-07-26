package cui.core

/**
 * The spacing scale — a consistent set of gaps and paddings on a 4-pixel grid, expressed as `Length`
 * values in virtual pixels. Referring to spacing by these named steps (rather than ad-hoc numbers)
 * keeps a UI's rhythm consistent, the design-token approach shared by Material, Fluent, and the iOS
 * HIG. Each step composes with the unit system, e.g. `.padding(Spacing.md)` or `VStack{}.spacing(Spacing.sm)`.
 */
public class Spacing {
    private init() {}

    public static let none: Length = Length(0.0, LengthUnit.Vp)
    public static let xs: Length = Length(4.0, LengthUnit.Vp)
    public static let sm: Length = Length(8.0, LengthUnit.Vp)
    public static let md: Length = Length(12.0, LengthUnit.Vp)
    public static let lg: Length = Length(16.0, LengthUnit.Vp)
    public static let xl: Length = Length(24.0, LengthUnit.Vp)
    public static let xxl: Length = Length(32.0, LengthUnit.Vp)
}

/**
 * The corner-radius scale, in virtual pixels — small for chips and inputs, medium for cards, large for
 * prominent surfaces, and `pill` for fully rounded ends (the renderer clamps a radius to half the
 * shorter side, so a very large value rounds a pill/circle). Pass these to `background(color, radius)`,
 * `border(...)`, `shadow(...)`, or `gradientBackground(...)` so rounding stays consistent.
 */
public class Radii {
    private init() {}

    public static let none: Float32 = 0.0
    public static let sm: Float32 = 6.0
    public static let md: Float32 = 10.0
    public static let lg: Float32 = 16.0
    public static let xl: Float32 = 24.0
    public static let pill: Float32 = 9999.0
}

/**
 * Motion tokens — standard animation durations (milliseconds) and easing curves for a consistent feel,
 * pairing with `Animator` and `Spring`. `fast` suits small toggles, `normal` most transitions, and
 * `slow` large or emphasis moves; the easings follow the common standard/decelerate/accelerate roles,
 * with `emphasized` adding a slight overshoot. Use e.g. `Animator(0.0, duration: Motion.normal, easing: Motion.standard)`.
 */
public class Motion {
    private init() {}

    public static let fast: UInt64 = 120
    public static let normal: UInt64 = 220
    public static let slow: UInt64 = 360

    // Symmetric ease for standard transitions; decelerate for entering, accelerate for exiting.
    public static let standard: Easing = Easing.EaseInOutCubic
    public static let decelerate: Easing = Easing.EaseOutCubic
    public static let accelerate: Easing = Easing.EaseInCubic
    // A lively entrance with a gentle overshoot.
    public static let emphasized: Easing = Easing.EaseOutBack
}
