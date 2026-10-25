package chui_liquid_glass_effects

import chui.*
import canghui_style_liquid_glass.*

private let FRAME_GRAPH_ACCEPTANCE_STEPS: Int64 = 18

private class FrameGraphAcceptanceModel {
    let phase = State<Int64>(0)
    let animating = State<Bool>(true)
    let sceneVisible = State<Bool>(true)
    let dark = State<Bool>(true)
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

/**
 * Content behind the glass. Must look like real cover art, not UI chrome: the material only reads
 * as glass when it sits on a dense, saturated image with hard structure to bend.
 */
private func playerBackdrop(): Unit {
    ZStack {
        CoverArt()
        structureLines()
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
        // Reference layout: cover and transport on the left, metadata/lyrics/progress on the right,
        // with a vertical tool rail hugging the right edge.
        HStack {
            VStack {
                Spacer()
                playerTransport(model)
            }.spacing(0.vp).padding(22.vp).width(430.vp).fillHeight()
            VStack {
                playerHeader(model, app)
                Spacer().height(18.vp)
                playerLyrics()
                Spacer()
                playerProgress()
            }.spacing(0.vp).padding(26.vp).fillWidth().fillHeight()
            playerRail(model)
        }.spacing(0.vp).fillWidth().fillHeight()
    }.fillWidth().fillHeight()
}

/** Vertical tool rail on the right edge, as in the reference. */
private func playerRail(model: FrameGraphAcceptanceModel): Unit {
    VStack {
        Spacer()
        VStack {
            glassPill(44.vp, 44.vp) {
                IconButton(IconName.Process) {
                    => ()
                }
            }
            glassPill(44.vp, 44.vp) {
                IconButton(IconName.Brush) {
                    => ()
                }
            }
            glassPill(44.vp, 44.vp) {
                IconButton(IconName.Save) {
                    => ()
                }
            }
            glassPill(44.vp, 44.vp) {
                IconButton(IconName.Copy) {
                    => ()
                }
            }
            glassPill(44.vp, 44.vp) {
                IconButton(IconName.Calculator) {
                    => ()
                }
            }
        }.spacing(10.vp)
        Spacer()
    }.spacing(0.vp).width(64.vp).fillHeight()
}

/** Progress rail and elapsed/remaining times, bottom of the right column. */
private func playerProgress(): Unit {
    VStack {
        // Knob sits on the rail, as in the reference.
        ZStack {
            Spacer().height(3.vp).fillWidth().background(Color.rgba(255, 255, 255, 130), 1.5)
            HStack {
                Spacer().width(196.vp)
                Spacer().width(12.vp).height(12.vp).background(Color.rgba(255, 255, 255, 240), 6.0)
                Spacer()
            }.fillWidth()
        }.fillWidth()
        HStack {
            Label("01:02").fontSize(FontSizes.CAPTION).muted().width(46.vp)
            Spacer()
            Label("02:56").fontSize(FontSizes.CAPTION).muted().width(46.vp)
        }.hug().fillWidth()
    }.spacing(12.vp).hug().width(320.vp)
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
    }.spacing(8.vp).fillWidth()
}

private func playerLyrics(): Unit {
    VStack {
        Label("I found you").fontSize(FontSizes.TITLE).bold()
        Label("Heaven when I held you again").muted()
        Label("How could we ever just be friends").muted()
    }.spacing(10.vp).hug().fillWidth()
}

private func playerTransport(model: FrameGraphAcceptanceModel): Unit {
    // Transport only: the progress rail lives in the right column, so it is not drawn twice.
    HStack {
        glassPill(46.vp, 46.vp) {
            IconButton(IconName.ChevronLeft) {
                => ()
            }
        }
        glassPill(62.vp, 62.vp) {
            IconButton(IconName.Process) {
                => ()
            }
        }
        glassPill(46.vp, 46.vp) {
            IconButton(IconName.ChevronRight) {
                => ()
            }
        }
        Spacer()
    }.spacing(12.vp).hug().fillWidth()
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
