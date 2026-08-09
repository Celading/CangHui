package cui.native_scene

@Test
func nativeSceneReportCarriesDrawIrAndActions(): Unit {
    let scene = NativeScene("probe", 640.0, 480.0, NativeColor.rgb(245, 247, 250))
    scene.panel(NativeRect(20.0, 20.0, 300.0, 120.0), NativeColor.rgb(255, 255, 255))
    scene.pushClip(NativeRect(20.0, 20.0, 300.0, 120.0))
    scene.symbol("sf", "folder", NativeRect(36.0, 40.0, 24.0, 24.0), NativeColor.rgb(46, 120, 198))
    scene.text("ExplorerX", 72.0, 42.0, NativeColor.rgb(24, 31, 42), pointSize: 20.0, bold: true)
    scene.popClip()
    scene.button("open", "Open", NativeRect(36.0, 88.0, 96.0, 36.0),
        NativeColor.rgb(46, 120, 198), NativeColor.rgb(255, 255, 255))

    let report = scene.report(inputCount: 2, selectedAction: "open")
    @Expect(report.contains("\"protocol\":\"canghui.native-scene.v0\""))
    @Expect(report.contains("\"kind\":\"clip.push\""))
    @Expect(report.contains("\"kind\":\"symbol\""))
    @Expect(report.contains("\"id\":\"open\""))
    @Expect(report.contains("\"selectedAction\":\"open\""))
}

@Test
func nativeScenePointerCancelsMoveOutRelease(): Unit {
    let scene = pointerFixture()
    let pointer = NativeScenePointer()
    @Expect(actionName(pointer.dispatch(scene, 1, 40.0, 40.0)), "")
    @Expect(pointer.isPressed("action"))
    @Expect(actionName(pointer.dispatch(scene, 2, 240.0, 240.0)), "")
    @Expect(!pointer.isPressed("action"))
    @Expect(actionName(pointer.dispatch(scene, 3, 40.0, 40.0)), "")
}

@Test
func nativeScenePointerActivatesReleaseInsideAndSyntheticTap(): Unit {
    let scene = pointerFixture()
    let pointer = NativeScenePointer()
    let _ = pointer.dispatch(scene, 1, 40.0, 40.0)
    @Expect(actionName(pointer.dispatch(scene, 3, 40.0, 40.0)), "action")
    @Expect(actionName(pointer.dispatch(scene, 5, 40.0, 40.0)), "action")
}

private func pointerFixture(): NativeScene {
    let scene = NativeScene("pointer", 320.0, 240.0, NativeColor.rgb(255, 255, 255))
    scene.button("action", "Action", NativeRect(20.0, 20.0, 120.0, 48.0),
        NativeColor.rgb(46, 120, 198), NativeColor.rgb(255, 255, 255))
    scene
}

private func actionName(value: ?String): String {
    match (value) {
        case Some(name) => name
        case None => ""
    }
}
