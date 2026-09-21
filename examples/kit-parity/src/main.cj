package canghui_kit_parity

import std.env.getCommandLine
import std.convert.*
import chui.*
import canghui_kit.*
import canghui_style_liquid_glass.*

// Application-owned state and actions: visual recipes never own the workflow.
class LibraryFlow {
    let chosen = State<Bool>(false)
    let error = State<Bool>(false)
    let review = State<Bool>(false)
    let style = State<Int64>(0)
    let width = State<Float32>(960.0)
    let choices = State<Int64>(0)
    let attempts = State<Int64>(0)
    let returns = State<Int64>(0)
    var dark = false
    var reduced = false
    func choose(): Unit { choices.value += 1; chosen.value = !chosen.value; error.value = false }
    func proceed(): Unit {
        attempts.value += 1
        error.value = !chosen.value
        if (chosen.value) { review.value = true }
    }
    func back(): Unit { returns.value += 1; review.value = false }
}

func flowTheme(model: LibraryFlow): Theme {
    if (model.style.value == 2) {
        let prefs = LiquidGlassPreferences(reduceMotion: model.reduced)
        return if (model.dark) { LiquidGlass.dark(preferences: prefs) }
            else { LiquidGlass.light(preferences: prefs) }
    }
    (if (model.dark) { Theme.dark() } else { Theme.light() }).withReduceMotion(model.reduced)
}

func controls(model: LibraryFlow): Unit {
    VStack(spacing: 12.vp) {
        if (model.review.value) {
            Label("Library ready", fontSize: 21.fp).bold()
            Label("Local files remain on this device.", muted: true)
            Button("Back to selection", probedAction("back", {=> model.back()})).key("back").probe("back", "Button")
        } else {
            Button(if (model.chosen.value) { "Local library selected" } else { "Choose local library" },
                probedAction("choose", {=> model.choose()})).key("choose").probe("choose", "Button")
            if (model.error.value) {
                Label("Choose a library before continuing.", color: Some(flowTheme(model).danger)).wrap()
                    .probe("validation", "ValidationMessage")
            }
            Button("Continue", probedAction("continue", {=> model.proceed()}), role: ButtonRole.Primary)
                .key("continue").probe("continue", "Button")
        }
    }.hug().probe("library-controls", "Workflow")
}

func preview(model: LibraryFlow): Unit {
    let theme = flowTheme(model)
    VStack(spacing: 16.vp) {
        Icon(IconName.OpenFolder, size: 48.vp, color: Some(theme.accent))
        Label("Your library", fontSize: 23.fp).bold()
        Label("Books, notes and ideas.\nA space that stays yours.", muted: true).wrap()
        Label(if (model.chosen.value) { "LOCAL / SELECTED" } else { "LOCAL / NOT SELECTED" }, fontSize: 12.fp)
    }.hug().padding(24.vp).background(theme.field, 20.vp)
        .probe("library-preview", "DecorativePreview")
}

func flowView(model: LibraryFlow): Unit {
    let theme = flowTheme(model)
    ScrollView(key: "flow-scroll") {
        VStack(spacing: 20.vp) {
            Label("CangHui / Library setup", muted: true, fontSize: 13.fp)
            if (model.style.value == 1) {
                let context = ComponentContext(HostProfile(HostPlatform.Desktop),
                    ViewportSpec("flow", "Library", model.width.value - 32.0, 720.0))
                kitIntro("library", context, KitIntroProfile.Editorial, "MAKE ROOM FOR IDEAS",
                    "A quieter place to read.", "One library. Your own pace.",
                    design: KitDesign(theme: theme), visual: {=> preview(model)},
                    actions: {=> controls(model)}, steps: {=>
                        kitStep(1, "Keep it local", "Choose, review and return without losing your selection.",
                            active: true, design: KitDesign(theme: theme))
                    })
            } else if (model.style.value == 2) {
                preview(model)
                Surface(shape: Shape.rounded(28.0),
                    material: LiquidGlass.material(spec: LiquidGlassSpec(radius: 28.0)),
                    painter: Some(LiquidGlass.surfacePainter(spec: LiquidGlassSpec(radius: 28.0)))) {
                    VStack(spacing: 16.vp) {
                        Label("Make yourself at home", fontSize: 24.fp).bold()
                        controls(model)
                    }.hug().padding(24.vp)
                }
            } else {
                Label("Set up your library", fontSize: 24.fp).bold()
                Label("Choose a source, then review your selection.", muted: true)
                controls(model)
                preview(model)
            }
        }.hug().padding(16.vp)
    }
}

func argument(name: String, fallback: String): String {
    let args = getCommandLine()
    for (i in 0..max(0, args.size - 1)) { if (args[i] == name) { return args[i + 1] } }
    fallback
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = LibraryFlow()
    model.style.value = Int64.parse(argument("--style", "0"))
    model.width.value = Float32.parse(argument("--width", "960"))
    model.dark = argument("--theme", "light") == "dark"
    model.reduced = argument("--reduced", "false") == "true"
    let app = DesktopApp(WindowSpec("CangHui / Kit parity", Int32(model.width.value), 760), theme: flowTheme(model))
    app.setMinimumSize(320, 600)
    app.run {
        EventHandler(onEvent: {event =>
            match (event) {
                case UiEvent.WindowResized(w, _) => model.width.value = Float32(w)
                case _ => ()
            }
            false
        }) { flowView(model) }
    }
    verifyFlowIfRequested(model)
    0
}

@When[debug]
func verifyFlowIfRequested(model: LibraryFlow): Unit {
    if (argument("--verify-flow", "false") != "true") { return }
    let passed = model.chosen.value && !model.error.value && !model.review.value &&
        model.choices.value == 1 && model.attempts.value == 2 && model.returns.value == 1
    println("KIT_FLOW_RESULT style=${model.style.value} choices=${model.choices.value} " +
        "attempts=${model.attempts.value} returns=${model.returns.value} passed=${passed}")
    if (!passed) { throw Exception("Kit workflow did not reach its expected final state") }
}

@When[!debug]
func verifyFlowIfRequested(_: LibraryFlow): Unit {}
