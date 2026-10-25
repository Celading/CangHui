package chui_liquid_glass_effects

import chui.*
import canghui_style_liquid_glass.*

private let FRAME_GRAPH_ACCEPTANCE_STEPS: Int64 = 18

private class FrameGraphAcceptanceModel {
    let phase = State<Int64>(0)
    let animating = State<Bool>(true)
    let sceneVisible = State<Bool>(true)
    let dark = State<Bool>(false)
    let reducedTransparency = State<Bool>(false)
    let variantIndex = State<Int64>(0)

    func tick(controller: Scene3DViewController): Unit {
        if (!animating.value) { return }
        phase.value += 1
        if (phase.value >= FRAME_GRAPH_ACCEPTANCE_STEPS) {
            animating.value = false
            // End the simulated host placement before the widget leaves the tree. Later
            // observation-only frames then prove that the complete stable UI pass can be culled.
            let _ = controller.remove()
            sceneVisible.value = false
        }
    }

    func restart(): Unit {
        phase.value = 0
        sceneVisible.value = true
        animating.value = true
    }

    func preferences(): LiquidGlassPreferences {
        LiquidGlassPreferences(reduceTransparency: reducedTransparency.value)
    }

    /** The three recipes must be visibly and measurably different, not just three alphas. */
    func variant(): LiquidGlassVariant {
        match (variantIndex.value % 3) {
            case 0 => LiquidGlassVariant.Regular
            case 1 => LiquidGlassVariant.Clear
            case _ => LiquidGlassVariant.Vapor
        }
    }

    func variantLabel(): String {
        match (variantIndex.value % 3) {
            case 0 => "Regular"
            case 1 => "Clear"
            case _ => "Vapor"
        }
    }
}

private class FrameGraphAcceptanceSceneFrames <: Scene3DViewFrameSource {
    public func snapshot(clock: Scene3DFrameClock): Scene3DFrameSnapshot {
        Scene3DFrameSnapshot("framegraph-acceptance-${clock.frameId}")
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let model = FrameGraphAcceptanceModel()
    let controller = frameGraphAcceptanceSceneController()
    let app = DesktopApp(
        WindowSpec("CangHui FrameGraph · Liquid Glass", 920, 600, scale: 1.0),
        theme: frameGraphAcceptanceTheme(model)
    )
    app.setMinimumSize(760, 520)
    app.run {
        if (model.animating.value || model.sceneVisible.value) {
            FrameHandler(onFrame: {_ => model.tick(controller)}) {
                effectGallery(model, Some(app), controller)
            }
        }
        if (!model.animating.value && !model.sceneVisible.value) {
            effectGallery(model, Some(app), controller)
        }
    }
    0
}

func effectGallery(): Unit {
    effectGallery(
        FrameGraphAcceptanceModel(),
        None<DesktopApp>,
        frameGraphAcceptanceSceneController())
}

/**
 * The glass material is used the way the reference uses it: as the **parent container** for a
 * whole layer of content, not as a small card with a border. The player layer sits on the
 * material, the floating controls are their own glass surfaces, and every one of them is the
 * same reusable `LiquidGlass` painter.
 */
private func effectGallery(
    model: FrameGraphAcceptanceModel,
    app: ?DesktopApp,
    controller: Scene3DViewController
): Unit {
    ZStack {
        playerBackdrop()
        playerGlassLayer(model, app, controller)
    }.fillWidth().fillHeight()
}

/** Content behind the glass. Structure is intentional: displacement is invisible over a wash. */
private func playerBackdrop(): Unit {
    ZStack {
        VStack {
            colorBand(Color.rgb(96, 74, 116), Color.rgb(150, 116, 168))
            colorBand(Color.rgb(178, 132, 168), Color.rgb(214, 168, 186))
            colorBand(Color.rgb(206, 158, 176), Color.rgb(238, 202, 200))
        }.spacing(0.vp).fillWidth().fillHeight()
        albumArt()
        structureLines()
    }.fillWidth().fillHeight()
}

/** Stand-in cover art: stacked tonal blocks so the lens has real edges and gradients to bend. */
private func albumArt(): Unit {
    VStack {
        Spacer().height(56.vp)
        HStack {
            Spacer().width(86.vp)
            VStack {
                Spacer().height(150.vp).fillWidth().background(Color.rgba(58, 40, 74, 210), 18.0)
                Spacer().height(3.vp)
                Spacer().height(96.vp).fillWidth().background(Color.rgba(196, 120, 132, 190), 18.0)
            }.hug().width(210.vp)
            Spacer().width(20.vp)
            VStack {
                Spacer().height(64.vp).fillWidth().background(Color.rgba(96, 66, 110, 180), 16.0)
                Spacer().height(3.vp)
                Spacer().height(240.vp).fillWidth().background(Color.rgba(150, 96, 120, 170), 16.0)
            }.hug().width(180.vp)
            Spacer()
        }.hug()
        Spacer()
    }.fillWidth().fillHeight()
}

/**
 * The parent glass layer. This single material instance hosts the entire player UI, which is
 * what makes the style reusable instead of a one-off card decoration.
 */
private func playerGlassLayer(
    model: FrameGraphAcceptanceModel,
    app: ?DesktopApp,
    controller: Scene3DViewController
): Unit {
    let spec = LiquidGlassSpec(
        variant: model.variant(),
        radius: 30.0,
        preferences: model.preferences())
    Surface(
        shape: Shape.rounded(30.0),
        material: LiquidGlass.material(spec: spec),
        painter: Some(LiquidGlass.surfacePainter(spec: spec)),
        clip: ClipPolicy.Shape
    ) {
        VStack {
            playerHeader(model, app)
            Spacer()
            playerLyrics()
            Spacer()
            playerTransport(model)
        }.spacing(0.vp).padding(26.vp).fillWidth().fillHeight()
    }.fillWidth().fillHeight()
}

/**
 * Floating glass controls live inside the parent material but keep their own rounded surface.
 * `Surface` is a block node whose size comes from its content, so the control size is applied to
 * the inner stack rather than chained onto the surface itself.
 */
private func glassPill(width: Length, height: Length, content: () -> Unit): Unit {
    let radius = min(9999.0, Float32(height.value) / 2.0)
    let spec = LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        radius: radius)
    Surface(
        shape: Shape.rounded(radius),
        material: LiquidGlass.material(spec: spec),
        painter: Some(LiquidGlass.surfacePainter(spec: spec)),
        clip: ClipPolicy.Shape
    ) {
        HStack {
            content()
        }.hug().width(width).height(height)
    }
}

private func playerHeader(model: FrameGraphAcceptanceModel, app: ?DesktopApp): Unit {
    HStack {
        VStack {
            Label("until I found you").fontSize(FontSizes.TITLE).bold()
            Label("Stephen Sanchez · 70人在听").muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).hug()
        Spacer()
        IconButton(IconName.Refresh) { model.restart() }.width(34.vp).height(34.vp)
        IconButton(if (model.dark.value) { IconName.Sun } else { IconName.Moon }) {
            model.dark.value = !model.dark.value
            applyFrameGraphAcceptanceTheme(model, app)
        }.width(34.vp).height(34.vp)
        Button(model.variantLabel(), { =>
            model.variantIndex.value += 1
            applyFrameGraphAcceptanceTheme(model, app)
        }).height(32.vp)
        Button(if (model.reducedTransparency.value) { "Opaque" } else { "Glass" }, { =>
            model.reducedTransparency.value = !model.reducedTransparency.value
            applyFrameGraphAcceptanceTheme(model, app)
        }).height(32.vp)
    }.spacing(8.vp).hug().fillWidth()
}

private func playerLyrics(): Unit {
    VStack {
        Label("I found you").fontSize(FontSizes.TITLE).bold()
        Label("Heaven when I held you again").muted()
        Label("How could we ever just be friends").muted()
    }.spacing(10.vp).hug().fillWidth()
}

private func playerTransport(model: FrameGraphAcceptanceModel): Unit {
    VStack {
        // Progress track: a thin rail plus the elapsed knob. Time labels keep their own width so
        // the rail cannot squeeze them into ellipses.
        HStack {
            Label("01:02").muted().fontSize(FontSizes.CAPTION).width(46.vp)
            Spacer().width(8.vp)
            Spacer().height(3.vp).fillWidth().background(Color.rgba(255, 255, 255, 140), 1.5)
            Spacer().width(8.vp)
            Label("02:56").muted().fontSize(FontSizes.CAPTION).width(46.vp)
        }.hug().fillWidth()
        HStack {
            glassPill(44.vp, 44.vp) { Icon(IconName.ChevronLeft, size: 18.vp) }
            Spacer().width(8.vp)
            glassPill(60.vp, 60.vp) { Icon(IconName.Process, size: 22.vp) }
            Spacer().width(8.vp)
            glassPill(44.vp, 44.vp) { Icon(IconName.ChevronRight, size: 18.vp) }
            Spacer()
            glassPill(98.vp, 44.vp) { Label(model.variantLabel()).fontSize(FontSizes.CAPTION) }
        }.hug().fillWidth()
    }.spacing(14.vp).hug().fillWidth()
}

private func colorBand(start: Color, end: Color): Unit {
    Spacer().fillWidth().fillHeight().gradientBackground(
        Gradient(start: start, end: end, vertical: false),
        0.0
    )
}

/**
 * Hard structure the glass must visibly bend. Built from the gallery-proven `Spacer().height()`
 * + `background` pattern: this renderer has no rectangle primitive, and a flat wash would hide
 * exactly the displacement this packet is about.
 */
private func structureLines(): Unit {
    VStack {
        Spacer().height(48.vp)
        Spacer().height(2.vp).fillWidth().background(Color.rgba(255, 255, 255, 74), 1.0)
        Spacer().height(96.vp)
        Spacer().height(2.vp).fillWidth().background(Color.rgba(255, 255, 255, 62), 1.0)
        Spacer().height(104.vp)
        Spacer().height(3.vp).fillWidth().background(Color.rgba(255, 255, 255, 92), 1.5)
        Spacer().height(92.vp)
        Spacer().height(2.vp).fillWidth().background(Color.rgba(255, 255, 255, 70), 1.0)
        Spacer().height(110.vp)
        Spacer().height(2.vp).fillWidth().background(Color.rgba(255, 255, 255, 56), 1.0)
        Spacer()
    }.spacing(0.vp).fillWidth().fillHeight()
}

private func frameGraphMotionOffset(model: FrameGraphAcceptanceModel): Float32 {
    6.0 + Float32(model.phase.value % 9) * 5.0
}

private func frameGraphAcceptanceSceneController(): Scene3DViewController {
    let host = FakeScene3DViewHost()
    let controller = Scene3DViewController(
        "framegraph-acceptance-scene",
        host,
        FakeScene3DProvider(),
        Scene3DResource(
            "framegraph-acceptance-resource",
            "memory://framegraph-acceptance",
            "sha256:framegraph-acceptance",
            0),
        FrameGraphAcceptanceSceneFrames(),
        compositionMode: Scene3DCompositionMode.PreferSharedFrame)
    host.publish(NativeSurfaceEvent.Available(NativeSurfaceDescriptor(
        "framegraph-acceptance-surface",
        NativeSurfaceBackend.Software,
        UInt64(1),
        268.0,
        116.0,
        268,
        116,
        1.0,
        1)))
    host.publish(NativeSurfaceEvent.Frame(NativeSurfaceFrame(1, 0, 16)))
    controller
}

private func applyFrameGraphAcceptanceTheme(
    model: FrameGraphAcceptanceModel,
    app: ?DesktopApp
): Unit {
    match (app) {
        case Some(value) => value.transitionTheme(frameGraphAcceptanceTheme(model))
        case None => ()
    }
}

private func frameGraphAcceptanceTheme(model: FrameGraphAcceptanceModel): Theme {
    let preferences = model.preferences()
    if (model.dark.value) {
        LiquidGlass.dark(tint: Color.rgb(72, 156, 255), preferences: preferences)
    } else {
        LiquidGlass.light(tint: Color.rgb(55, 126, 246), preferences: preferences)
    }
}
