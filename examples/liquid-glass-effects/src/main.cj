package chui_liquid_glass_effects

import chui.*
import canghui_style_liquid_glass.*

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    let app = DesktopApp(
        WindowSpec("CangHui Backdrop Effects", 920, 600, scale: 1.0),
        theme: LiquidGlass.light(tint: Color.rgb(55, 126, 246))
    )
    app.setMinimumSize(720, 520)
    app.run { effectGallery() }
    0
}

func effectGallery(): Unit {
    ZStack {
        backdropMosaic()
        VStack {
            Spacer()
            HStack {
                glassCard(
                    "Native backdrop",
                    "The SDL adapter samples the stripes already painted behind this Surface.",
                    LiquidGlassVariant.Clear
                )
                glassCard(
                    "Vapor backdrop",
                    "The same adapter upgrades Vapor while SDR fallback stays available.",
                    LiquidGlassVariant.Vapor
                )
            }.spacing(22.vp).hug()
            HStack {
                Label("sdl-readback · bounded · current frame").fontSize(FontSizes.CAPTION)
                Spacer()
                Label("shape union: unsupported on this first adapter").muted().fontSize(FontSizes.CAPTION)
            }.padding(14.vp).background(Color.rgba(255, 255, 255, 176), 18.0).fillWidth().height(48.vp)
            Spacer()
        }.spacing(18.vp).padding(44.vp).fillWidth().fillHeight()
    }.fillWidth().fillHeight()
}

private func backdropMosaic(): Unit {
    VStack {
        colorBand(Color.rgb(255, 91, 110), Color.rgb(255, 190, 92), "CURRENT FRAME")
        colorBand(Color.rgb(91, 206, 250), Color.rgb(82, 107, 246), "SAMPLED BEHIND SURFACE")
        colorBand(Color.rgb(121, 84, 246), Color.rgb(230, 93, 184), "BOUNDED READBACK")
    }.spacing(0.vp).fillWidth().fillHeight()
}

private func colorBand(start: Color, end: Color, title: String): Unit {
    HStack {
        Label(title).foregroundColor(Color.rgba(255, 255, 255, 178)).fontSize(FontSizes.DISPLAY).bold()
        Spacer()
        Label("CangHui").foregroundColor(Color.rgba(255, 255, 255, 116)).fontSize(48.0).bold()
    }.padding(34.vp).fillWidth().fillHeight().gradientBackground(
        Gradient(start: start, end: end, vertical: false),
        0.0
    )
}

private func glassCard(title: String, summary: String, variant: LiquidGlassVariant): Unit {
    Surface(
        shape: Shape.rounded(30.0),
        material: LiquidGlass.material(spec: LiquidGlassSpec(variant: variant, radius: 30.0)),
        painter: Some(LiquidGlass.surfacePainter(spec: LiquidGlassSpec(
            variant: variant,
            radius: 30.0,
            optics: LiquidGlassOptics(clarity: 0.94, haze: 0.42, edgeEnergy: 0.94)
        ))),
        clip: ClipPolicy.Shape
    ) {
        VStack {
            Label(title).fontSize(FontSizes.TITLE).bold()
            Label(summary).wrap().muted()
            HStack {
                Icon(IconName.Refresh, size: 18.vp)
                Label("Surface-owned content and input").fontSize(FontSizes.CAPTION)
            }.spacing(8.vp).hug()
        }.spacing(12.vp).padding(24.vp).width(360.vp).height(176.vp)
    }
}
