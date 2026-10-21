package chui.text

import chui.core.{Length, LengthUnit, State, Theme, TypographyEnvironment, UiContext}
import sdl.{Fonts, FontStyle, MouseButton, Rect, SdlWindow, UiEvent, WindowSpec}
import sdl.text.NativeTextLineSpec
import std.env.getVariable
import std.math.abs

@When[os == "macOS"]
@Test
func textAreaCustomFontNativeAndFallbackShareMetricsThroughStyleScaleAndRows(): Unit {
    Fonts.registerBundledFallback("assets/fonts/HarmonyOS_Sans_SC.ttf")
    Fonts.register("Editor custom face", "assets/fonts/HarmonyOS_Sans_SC.ttf")
    let window = SdlWindow(WindowSpec("Custom editor typography", 640, 300, supersample: 1))
    try {
        let r = window.renderer
        var scene: Int64 = 0
        for (native in [false, true]) {
            @Expect(r.usePlatformTextLayout(native))
            for (scale in [Float32(1.0), Float32(1.5)]) {
                r.setScale(scale)
                for (size in [Float32(12.0), Float32(32.0)]) {
                    for (style in [FontStyle.regular, FontStyle(bold: true), FontStyle(italic: true)]) {
                        for (mode in [TextAreaWrapMode.NoWrap, TextAreaWrapMode.SoftWrap]) {
                            let sceneIndex = scene
                            let ctx = UiContext(r, if (sceneIndex % 2 == 0) { Theme.light() } else { Theme.dark() })
                            let text = State<String>("a你éb\n尾行")
                            let cursor = State<Int64>(4)
                            let area = TextArea(text, key: "custom-native", cursor: Some(cursor),
                                anchor: Some(State<Int64>(4)), wrapMode: mode)
                                .lineHeight(Length(56.0, LengthUnit.Vp))
                            ctx.withTypographyEnvironment(TypographyEnvironment(fontFamily: "Editor custom face",
                                fontSize: Length(size, LengthUnit.Fp), bold: style.bold, italic: style.italic)) {=>
                                r.clear(ctx.theme.bg)
                                area.layout(ctx, Rect(0.0, 0.0, 380.0, 180.0))
                                ctx.focus("custom-native")
                                area.draw(ctx)
                                let caret = ctx.textInputAnchorRect().getOrThrow()
                                let expectedX = if (native && style.ttfFlags() == 0 && !softWrapped(mode)) {
                                    r.textCaretPositionsUtf16(NativeTextLineSpec("a你éb"), Int64(2),
                                        pointSize: size, style: style, font: "Editor custom face").getOrThrow()[0]
                                } else { r.textWidth("a你", pointSize: size, style: style, font: "Editor custom face") }
                                let expectedH = r.textHeight(pointSize: size, style: style, font: "Editor custom face")
                                @Expect(abs(caret.x - 8.0 - expectedX) < 0.1)
                                @Expect(abs(caret.h - expectedH) < 0.1)
                                @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 66.0)))
                                @Expect(cursor.value, Int64(9))
                                @Expect(area.handle(ctx, UiEvent.TextInput("新")))
                                @Expect(text.value, "a你éb\n新尾行")
                                area.undo()
                                @Expect(text.value, "a你éb\n尾行")
                                area.redo()
                                @Expect(text.value, "a你éb\n新尾行")
                                println("editor-font scene=${sceneIndex} native=${native} scale=${scale} size=${size} flags=${style.ttfFlags()} caret=${caret.x},${caret.y},${caret.h}")
                                if (let Some(path) <- getVariable("CANGHUI_TEST_TEXTAREA_CAPTURE_DIR")) {
                                    r.capturePng(path + "/editor-${sceneIndex}.png")
                                }
                            }
                            scene += 1
                        }
                    }
                }
            }
        }
        @Expect(scene, Int64(48))
    } finally {
        window.close()
        Fonts.unregister("Editor custom face")
        Fonts.clearBundledFallbackOverride()
    }
}

private func softWrapped(mode: TextAreaWrapMode): Bool {
    match (mode) { case TextAreaWrapMode.SoftWrap => true case TextAreaWrapMode.NoWrap => false }
}
