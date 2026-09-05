package canghui_kit

import chui.*

/** Explicit input density, independent of palette or desktop/mobile platform labels. */
public enum KitDensity {
    | Compact
    | Comfortable
    | Touch

    public func controlHeight(): Float32 {
        match (this) { case Compact => 32.0 case Comfortable => 38.0 case Touch => 44.0 }
    }

    public func contentInset(): Float32 {
        match (this) { case Compact => 12.0 case Comfortable => 16.0 case Touch => 20.0 }
    }
}

/** A design input, not another theme runtime. Pass the same Theme used by the application host. */
public struct KitDesign {
    public let theme: Theme
    public let density: KitDensity
    public init(theme!: Theme = Theme.light(), density!: KitDensity = KitDensity.Comfortable) {
        this.theme = theme
        this.density = density
    }
}

public class CangHuiKitPackage <: ComponentPackage {
    public func descriptor(): ComponentPackageDescriptor {
        ComponentPackageDescriptor("canghui.kit", "CangHuiKit", "0.1.0", minimumCuiVersion: "0.17.0")
    }
}

/** Bounded-height action; width hugs its label unless the caller explicitly opts into fill. */
public func kitAction(key: String, title: String, action: () -> Unit,
    design!: KitDesign = KitDesign(), primary!: Bool = true): Button {
    Button(title, action, role: if (primary) { ButtonRole.Primary } else { ButtonRole.Normal })
        .key(key)
        .minControlSize(width: 80.0, height: design.density.controlHeight())
        .contentPadding(LengthInsets(16.vp, 0.vp))
}

/** One selectable action owner, with leading content grouped beside its text rather than spread apart. */
public func kitChoiceCard(key: String, title: String, detail: String, selected: Bool, action: () -> Unit,
    icon!: IconName = IconName.OpenFolder, design!: KitDesign = KitDesign(),
    gestures!: GestureHandlers = GestureHandlers()): Widget {
    let palette = design.theme
    InteractionSurface(action: action, key: Some(key), role: ControlRole.Checkbox,
        accessibilityLabel: title, selected: Some(selected)) {
        Row(space: 12.vp) {
            Icon(icon, size: 24.vp, color: Some(if (selected) { palette.accent } else { palette.mutedText }))
            VStack(spacing: 4.vp) {
                Label(title, color: Some(palette.text)).bold().wrap()
                Label(detail, color: Some(palette.mutedText), fontSize: 13.fp).wrap()
            }.hug().layoutWeight(1.0)
            KitChoiceMark(selected, palette.accent)
        }.hug().padding(design.density.contentInset())
    }.surface(Shape.rounded(16.0), KitChoiceFeedback())
        .gestures(gestures)
        .background(if (selected) { palette.accentSoft } else { palette.panel }, 16.vp)
        .border(if (selected) { palette.accent } else { palette.panelEdge }, width: 1.0, radius: 16.vp)
        .animateProperties("kit-choice:${key}")
}

/** Text and one separately focusable Switch: the row itself is deliberately not another button. */
public func kitSettingsToggle(key: String, title: String, detail: String, checked: Bindable<Bool>,
    design!: KitDesign = KitDesign()): Widget {
    Row(space: 16.vp) {
        VStack(spacing: 4.vp) {
            Label(title, color: Some(design.theme.text)).bold().wrap()
            Label(detail, color: Some(design.theme.mutedText), fontSize: 13.fp).wrap()
        }.hug().layoutWeight(1.0)
        Switch("", checked).key(key).accessibilityLabel(title)
            .width(52.vp).height(design.density.controlHeight())
    }.hug().padding(design.density.contentInset()).background(design.theme.panel, 16.vp)
}

/** A decorative step; navigation belongs in the application's actions, not a hidden row handler. */
public func kitStep(number: Int64, title: String, detail: String, active!: Bool = false,
    design!: KitDesign = KitDesign()): Widget {
    Row(space: 12.vp) {
        ZStack {
            Label(number.toString(), align: TextAlign.Center,
                color: Some(if (active) { design.theme.accentText } else { design.theme.mutedText }))
        }.width(30.vp).height(30.vp)
            .background(if (active) { design.theme.accent } else { design.theme.field }, 15.vp)
        VStack(spacing: 3.vp) {
            Label(title, color: Some(design.theme.text)).bold().wrap()
            Label(detail, color: Some(design.theme.mutedText), fontSize: 13.fp).wrap()
        }.hug().layoutWeight(1.0)
    }.hug()
}

private class KitChoiceFeedback <: MaterialProvider {
    public func resolve(theme: Theme, state: SurfaceState): SurfaceMaterial {
        let alpha: Int64 = if (!state.enabled) {0} else if (state.pressed) {28} else if (state.hovered) {14} else {0}
        SurfaceMaterial(SurfaceStyle(theme.accent.withAlpha(alpha), radius: 16.0), theme.text,
            supportingForeground: Some(theme.mutedText), ink: Some(theme.inkColor()))
    }
}

private class KitChoiceMark <: Widget {
    private let selected: Bool
    private let color: Color
    private var frame = Rect.zero()
    init(selected: Bool, color: Color) { this.selected = selected; this.color = color; emit(this) }
    public func measure(_: UiContext, available: Size): Size { Size(min(22.0, available.w), min(22.0, available.h)) }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }
    public func draw(ctx: UiContext): Unit {
        let radius = min(frame.w, frame.h) * 0.4
        let pen = Pen(width: 1.5, color: color.withAlpha(if (selected) {255} else {100}))
        ctx.renderer.strokeCircle(frame.centerX(), frame.centerY(), radius, pen)
        if (selected) {
            ctx.renderer.strokeLine(frame.centerX() - radius * 0.5, frame.centerY(),
                frame.centerX() - radius * 0.1, frame.centerY() + radius * 0.4, pen)
            ctx.renderer.strokeLine(frame.centerX() - radius * 0.1, frame.centerY() + radius * 0.4,
                frame.centerX() + radius * 0.55, frame.centerY() - radius * 0.4, pen)
        }
    }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}
