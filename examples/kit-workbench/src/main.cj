package canghui_kit_workbench

import std.env.getCommandLine
import std.convert.*
import chui.*
import canghui_kit.*

public class WorkbenchState {
    public let profile = State<Int64>(0)
    public let selected = State<Int64>(0)
    public let expanded = State<Bool>(false)
    public let reduced = State<Bool>(false)
    public let holds = State<Int64>(0)
    public let starts = State<Int64>(0)
    public let width = State<Float32>(1060.0)
    public let height = State<Float32>(900.0)
    public let dark = State<Bool>(false)
}

func argument(name: String, fallback: String): String {
    let args = getCommandLine()
    for (i in 0..max(0, args.size - 1)) { if (args[i] == name) { return args[i + 1] } }
    fallback
}

func workbenchTheme(state: WorkbenchState): Theme {
    let base = if (state.dark.value) {Theme.dark()} else {Theme.light()}
    base.withReduceMotion(state.reduced.value)
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let state = WorkbenchState()
    state.width.value = Float32.parse(argument("--width", "1060"))
    state.height.value = Float32.parse(argument("--height", "900"))
    state.profile.value = Int64.parse(argument("--profile", "0"))
    state.dark.value = argument("--theme", "light") == "dark"
    let app = DesktopApp(WindowSpec("CangHuiKit · Design Workbench", Int32(state.width.value), Int32(state.height.value)),
        theme: workbenchTheme(state))
    let appliedTheme = [state.dark.value, state.reduced.value]
    let autoReshape = argument("--auto-reshape", "false") == "true"
    let captureTicks = [0]
    app.setMinimumSize(320, 520)
    app.run {
        EventHandler(onEvent: {event =>
            match (event) {
                case UiEvent.WindowResized(w, h) =>
                    state.width.value = Float32(w)
                    state.height.value = Float32(h)
                case UiEvent.Frame(_) =>
                    if (appliedTheme[0] != state.dark.value || appliedTheme[1] != state.reduced.value) {
                        app.setTheme(workbenchTheme(state))
                        appliedTheme[0] = state.dark.value
                        appliedTheme[1] = state.reduced.value
                    }
                case _ => ()
            }
            false
        }) {
            FrameHandler(onFrame: {_ =>
                if (autoReshape && captureTicks[0] < 4) {
                    captureTicks[0] += 1
                    if (captureTicks[0] == 4) { state.expanded.value = true }
                }
            }, keepsAlive: {=> autoReshape && captureTicks[0] < 4}) {
                workbenchView(state)
            }
        }
    }
    emitWorkbenchResult(state, appliedTheme[0], appliedTheme[1])
    0
}

public func workbenchView(state: WorkbenchState): Unit {
    let design = KitDesign(theme: workbenchTheme(state),
        density: if (state.width.value < 600.0) {KitDensity.Touch} else {KitDensity.Comfortable})
    let profile = match (state.profile.value) {
        case 1 => KitIntroProfile.Focused
        case 2 => KitIntroProfile.Guided
        case _ => KitIntroProfile.Editorial
    }
    let context = ComponentContext(HostProfile(HostPlatform.Desktop),
        ViewportSpec("window", "Window", state.width.value, state.height.value))
    VStack(spacing: 0.vp) {
        Row(space: 12.vp) {
            Label("CangHuiKit", fontSize: 18.fp).bold().layoutWeight(1.0)
            IconButton(if (state.dark.value) {IconName.Sun} else {IconName.Moon}, onClick: {=>
                state.dark.value = !state.dark.value
            }).key("theme").accessibilityLabel("Change theme").buttonStyle(ButtonStyle.quiet())
        }.hug().padding(16.vp)
        SegmentedControl(["Editorial", "Focused", "Guided"], state.profile, key: "profiles").padding(16.vp, 0.vp)
            .probe("profiles", "SegmentedControl", [ProbeProperty("role", "tablist"),
                ProbeProperty("label", "Intro composition"), ProbeProperty("shortcut", "Left|Right")],
                {=> [ProbeProperty("selected-index", state.profile.value.toString())]})
        ScrollView(key: "workbench-scroll") {
            VStack(spacing: 12.vp) {
                kitIntro("welcome", context, profile, "DESIGNED TO RESPOND", "Your next idea, in motion.",
                    "Change a value. Let the interface follow. Three compositions, one shared model.", design: design,
                    visual: {=> artwork(state, design)},
                    actions: {=> FlowRow {
                        kitAction("start", "Get started", probedAction("start", {=> state.starts.value += 1}), design: design)
                        kitAction("reshape", "Reshape", probedAction("reshape", {=> state.expanded.value = !state.expanded.value}),
                            design: design, primary: false)
                            .gestures(GestureHandlers(onLongPress: Some({=> state.holds.value += 1})))
                    }.spacing(10.vp)},
                    steps: {=> VStack(spacing: 14.vp) {
                        kitStep(1, "Choose your space", "Keep the source under your control", active: true, design: design)
                        kitStep(2, "Make it yours", "Change density, composition and motion", design: design)
                    }.hug()})
                VStack(spacing: 12.vp) {
                    Label("A place to begin", fontSize: 19.fp).bold()
                    AdaptiveGrid(280.vp, maxColumns: 2) {
                        kitChoiceCard("local", "Local workspace", "Private files, available offline", state.selected.value == 0,
                            {=> state.selected.value = 0}, design: design)
                        kitChoiceCard("shared", "Shared workspace", "A space to create together", state.selected.value == 1,
                            {=> state.selected.value = 1}, icon: IconName.Copy, design: design)
                    }.spacing(12.vp)
                    kitSettingsToggle("reduce-motion", "Reduce motion", "Snap property changes without a transition", state.reduced,
                        design: design)
                    Label("Started ${state.starts.value} · Long presses ${state.holds.value}", muted: true, fontSize: 12.fp)
                }.hug().padding(20.vp)
            }.hug()
        }
    }
}

private func artwork(state: WorkbenchState, design: KitDesign): Unit {
    ZStack {
        SignalArtwork(design.theme.accent)
            .padding(if (state.expanded.value) {28.vp} else {16.vp})
            .width(if (state.expanded.value) {320.vp} else {240.vp})
            .height(if (state.expanded.value) {220.vp} else {180.vp})
            .background(if (state.expanded.value) {design.theme.accentSoft} else {design.theme.panelRaised},
                if (state.expanded.value) {44.vp} else {20.vp})
            .border(design.theme.accent.withAlpha(if (state.expanded.value) {180} else {40}),
                width: if (state.expanded.value) {2.0} else {1.0}, radius: if (state.expanded.value) {44.vp} else {20.vp})
            .animateProperties("workbench-art", AnimationSpec(duration: UInt64(460), easing: Easing.EaseInOutQuad))
            .probe("motion-card", "PropertyMotion")
    }.height(280.vp).background(design.theme.field, 26.vp)
}

private class SignalArtwork <: Widget {
    private let color: Color
    private var frame = Rect.zero()
    init(color: Color) { this.color = color; emit(this) }
    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, rect: Rect): Unit { frame = rect }
    public func draw(ctx: UiContext): Unit {
        let pen = Pen(width: 2.0, color: color.withAlpha(40))
        let radius = min(frame.w, frame.h) * 0.42
        ctx.renderer.strokeCircle(frame.centerX(), frame.centerY(), radius, pen)
        ctx.renderer.strokeCircle(frame.centerX(), frame.centerY(), radius * 0.74, pen)
        let bars: Array<Float32> = [0.2, 0.35, 0.55, 0.8, 1.0, 0.68, 0.45, 0.8, 0.52, 0.32, 0.18]
        let gap = min(13.0, frame.w / 15.0)
        for (i in 0..bars.size) {
            let h = bars[i] * frame.h * 0.48
            let x = frame.centerX() + (Float32(i) - 5.0) * gap
            ctx.renderer.strokeLine(x, frame.centerY() - h / 2.0, x, frame.centerY() + h / 2.0,
                Pen(width: gap * 0.45, color: color))
        }
    }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
}
