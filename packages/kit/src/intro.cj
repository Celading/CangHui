package canghui_kit

import chui.*

/** Composition profiles, not color aliases. All three consume the same application-owned slots. */
public enum KitIntroProfile {
    | Editorial
    | Focused
    | Guided
}

/** Inspectable layout decision. Supply the available region's logical width, not framebuffer pixels. */
public func kitIntroLayout(profile: KitIntroProfile, availableWidth: Float32): String {
    match (profile) {
        case KitIntroProfile.Editorial => if (availableWidth >= 760.0) {"editorial-split"} else {"editorial-stack"}
        case KitIntroProfile.Focused => "focused-stack"
        case KitIntroProfile.Guided => if (availableWidth >= 840.0) {"guided-split"} else {"guided-stack"}
    }
}

/**
 * Responsive intro recipe. The host updates ComponentContext on resize/DPI changes. The viewport
 * describes this recipe's available region (including its own inset), not the entire monitor.
 * Slots are built once per composition; state and primary action policy stay with the application.
 * Tall/large-font content is intended to live inside a ScrollView, never silently shrink to fit.
 */
public func kitIntro(key: String, context: ComponentContext, profile: KitIntroProfile,
    eyebrow: String, title: String, summary: String,
    design!: KitDesign = KitDesign(), visual!: () -> Unit,
    actions!: () -> Unit, steps!: () -> Unit = {=> ()}): Widget {
    let inset: Float32 = if (context.viewport.width < 600.0) {20.0} else {32.0}
    let innerWidth = max(0.0, context.viewport.width - inset * 2.0)
    let layout = kitIntroLayout(profile, context.viewport.width)
    Keyed(key) {
        if (layout == "editorial-split") {
            HStack(spacing: 32.vp) {
                VStack(spacing: 22.vp) {
                    introHeading(eyebrow, title, summary, 42.0, false, design)
                    actions()
                    steps()
                }.hug().width(innerWidth * 0.44)
                VStack(spacing: 0.vp, body: visual).hug().layoutWeight(1.0)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            ()
        } else if (layout == "focused-stack") {
            VStack(spacing: 24.vp) {
                VStack(spacing: 0.vp, body: visual).hug().maxWidth(560.vp)
                introHeading(eyebrow, title, summary, 34.0, true, design)
                actions()
                steps()
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            ()
        } else if (layout == "guided-split") {
            HStack(spacing: 40.vp) {
                VStack(spacing: 28.vp) {
                    introHeading(eyebrow, title, summary, 32.0, false, design)
                    steps()
                }.hug().width(innerWidth * 0.40)
                VStack(spacing: 24.vp) {
                    visual()
                    actions()
                }.hug().layoutWeight(1.0)
            }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
            ()
        } else {
            VStack(spacing: 22.vp) {
                introHeading(eyebrow, title, summary, 30.0, false, design)
                visual()
                steps()
                actions()
            }.hug()
            ()
        }
    }.padding(inset).probe("${key}:composition", "KitIntro", [ProbeProperty("layout", layout)])
}

private func introHeading(eyebrow: String, title: String, summary: String, size: Float32,
    centered: Bool, design: KitDesign): Unit {
    let alignment = if (centered) {TextAlign.Center} else {TextAlign.Leading}
    VStack(spacing: 12.vp) {
        Label(eyebrow, align: alignment, color: Some(design.theme.accent), fontSize: 12.fp).bold().wrap().fillWidth()
        Label(title, align: alignment, color: Some(design.theme.text)).fontSize(size).bold().wrap().fillWidth()
        Label(summary, align: alignment, color: Some(design.theme.mutedText), fontSize: 15.fp).wrap().fillWidth()
    }.hug().fillWidth()
}
