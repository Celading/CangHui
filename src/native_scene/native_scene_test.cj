package chui.native_scene

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

@Test
func nativeSceneCallerBufferReportsAndCopiesUtf8(): Unit {
    let length = unsafe { LibC.malloc<Int64>() }
    let buffer = unsafe { LibC.malloc<UInt8>(count: 32) }
    try (lengthResource = length.asResource()) {
        try (bufferResource = buffer.asResource()) {
            unsafe { lengthResource.value.write(0) }
            @Expect(copyNativeSceneUtf8ToCaller(
                "ExplorerX-仓颉", CPointer<UInt8>(), 0, lengthResource.value), Int32(-2))
            let required = unsafe { lengthResource.value.read() }
            @Expect(required > 12)
            @Expect(copyNativeSceneUtf8ToCaller(
                "ExplorerX-仓颉", bufferResource.value, required - 1, lengthResource.value), Int32(-2))
            @Expect(copyNativeSceneUtf8ToCaller(
                "ExplorerX-仓颉", bufferResource.value, required, lengthResource.value), Int32(0))
            @Expect(unsafe { bufferResource.value.read(0) }, UInt8(69))
            @Expect(unsafe { lengthResource.value.read() }, required)
        }
    }
}

@Test
func nativeSceneCallerBufferRejectsInvalidContract(): Unit {
    @Expect(copyNativeSceneUtf8ToCaller(
        "x", CPointer<UInt8>(), 0, CPointer<Int64>()), Int32(-1))
    let length = unsafe { LibC.malloc<Int64>() }
    try (resource = length.asResource()) {
        @Expect(copyNativeSceneUtf8ToCaller(
            "x", CPointer<UInt8>(), -1, resource.value), Int32(-1))
    }
}

@Test
func nativeSceneRoundedStrokeKeepsGeometryWidthSeparate(): Unit {
    let scene = NativeScene("stroke", 320.0, 240.0, NativeColor.rgb(255, 255, 255))
    scene.strokeRounded(NativeRect(20.0, 30.0, 120.0, 48.0), 8.0,
        NativeColor.rgb(46, 120, 198), width: 3.0)
    let report = scene.report()
    @Expect(report.contains("\"width\":120.000000"), true)
    @Expect(report.contains("\"strokeWidth\":3.000000"), true)
}

@Test
func nativeSceneTextCarriesMeasuredLayoutHints(): Unit {
    let scene = NativeScene("text-layout", 320.0, 240.0, NativeColor.rgb(255, 255, 255))
    scene.text("A longer line that wraps", 12.0, 20.0, NativeColor.rgb(20, 20, 20),
        pointSize: 14.0, width: 160.0, height: 64.0, lineLimit: 3, alignment: "center")
    let report = scene.report(inputCount: 0, selectedAction: "")
    @Expect(report.contains("\"width\":160.000000"))
    @Expect(report.contains("\"height\":64.000000"))
    @Expect(report.contains("\"lineLimit\":3"))
    @Expect(report.contains("\"alignment\":\"center\""))
}

@Test
func nativeSceneProductReportCarriesLayoutAndActions(): Unit {
    let state = NativeSceneProductState()
    let report = state.report(390.0, 640.0, 0, 0.0, 0.0, false)
    @Expect(report.contains("\"protocol\":\"canghui.native-scene.v0\""))
    @Expect(report.contains("\"name\":\"canghui-ios-product\""))
    @Expect(report.contains("\"id\":\"increment\""))
    @Expect(report.contains("\"id\":\"focus\""))
    @Expect(report.contains("\"lineLimit\":2"))
    @Expect(report.contains("\"lineLimit\":1"))
    @Expect(report.contains("\"alignment\":\"left\""))
    let scene = NativeScene("layout", 390.0, 640.0, NativeColor.rgb(0, 0, 0))
    @Expect(scene.hasMeasuredTextLayout(), false)
    scene.text("x", 0.0, 0.0, NativeColor.rgb(0, 0, 0), width: 100.0, lineLimit: 2)
    @Expect(scene.hasMeasuredTextLayout(), true)
}

@Test
func nativeSceneProductTapIncrementsOnlyForCommittedRelease(): Unit {
    let state = NativeSceneProductState()
    let _ = state.report(390.0, 640.0, 5, 99.0, 296.0, true)
    @Expect(state.currentCounter(), 1)
    @Expect(state.currentLastAction(), "increment")
    @Expect(state.totalInputCount(), 1)
    let _ = state.report(390.0, 640.0, 1, 99.0, 296.0, true)
    let _ = state.report(390.0, 640.0, 3, 300.0, 500.0, true)
    @Expect(state.currentCounter(), 1)
    let _ = state.report(390.0, 640.0, 5, 276.0, 296.0, true)
    @Expect(state.currentCounter(), 1)
    @Expect(state.currentLastAction(), "focus")
    let snapshot = state.report(390.0, 640.0, 0, 0.0, 0.0, false)
    @Expect(snapshot.contains("\"inputCount\":4"))
    @Expect(snapshot.contains("\"selectedAction\":\"focus\""))
}

@Test
func nativeSceneProductInputAndKeyboardState(): Unit {
    let state = NativeSceneProductState()
    @Expect(state.currentInputText(), "未输入")
    @Expect(state.setInputText("仓绘"))
    @Expect(state.currentInputText(), "仓绘")
    @Expect(state.currentLastAction(), "ime")
    @Expect(state.key(1, 42))
    @Expect(state.currentInputText(), "仓")
    @Expect(state.key(1, 42))
    @Expect(state.currentInputText(), "未输入")
    @Expect(state.key(1, 40))
    @Expect(state.currentLastAction(), "return")
    @Expect(state.totalKeyCount(), 3)
    @Expect(state.currentLastKeyCode(), 40)
    let json = state.stateJson()
    @Expect(json.contains("\"counter\":0"))
    @Expect(json.contains("\"textLayout\":true"))
    @Expect(json.contains("\"actionCount\":2"))
    @Expect(!state.key(2, 40))
    @Expect(!state.key(1, 70000))
}

@Test
func nativeSceneProductCAbiRejectsInvalidFrames(): Unit {
    let length = unsafe { LibC.malloc<Int64>() }
    try (lengthResource = length.asResource()) {
        unsafe {
            @Expect(canghui_ios_product_render(
                0, 640000, 0, 0, 0, CPointer<UInt8>(), 0, lengthResource.value), Int32(-1))
            @Expect(canghui_ios_product_render(
                390000, 640000, 9, 0, 0, CPointer<UInt8>(), 0, lengthResource.value), Int32(-1))
            @Expect(canghui_ios_product_render(
                390000, 640000, 1, 20000000, 0, CPointer<UInt8>(), 0, lengthResource.value), Int32(-1))
            @Expect(canghui_ios_product_render(
                390000, 640000, 0, 0, 0, CPointer<UInt8>(), 0, CPointer<Int64>()), Int32(-1))
            @Expect(canghui_ios_product_set_text(CPointer<UInt8>(), -1), Int32(-1))
            @Expect(canghui_ios_product_key(9, 40), Int32(-1))
        }
    }
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
