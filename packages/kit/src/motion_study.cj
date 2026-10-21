package canghui_kit

import chui.*

/** A ready-to-place study; individual recipes remain independently usable. */
public func kitMotionStudy(key: String, family: KitMotionFamily, palette: KitMotionPalette,
    replay!: UInt64 = 0, value!: Int64 = 128, shown!: Bool = true): Widget {
    match (family) {
        case KitMotionFamily.Bounce => kitBounce(key, replay, palette)
        case KitMotionFamily.Digital =>
            VStack(spacing: 8.vp) {
                kitRollingNumber("${key}:number", value, palette).height(80.vp)
                kitTerminal("${key}:terminal", replay, palette).layoutWeight(1.0)
            }.fillWidth().fillHeight()
        case KitMotionFamily.FocusLight => kitFocusLight(key, palette, focusKey: "replay")
        case KitMotionFamily.Choreography => kitChoreography(key, shown, palette)
        case KitMotionFamily.Archive => kitArchive(key, replay, palette)
    }
}
