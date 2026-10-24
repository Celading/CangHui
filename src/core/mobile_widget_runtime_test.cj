package chui.core

@Test
func mobileWidgetRuntimeRecordsRealWidgetTree(): Unit {
    let runtime = MobileWidgetRuntime()
    let count = State<Int64>(0)
    runtime.setBody({=>
        VStack {
            Label("ExplorerX 0.6.44")
            Label("设备与文件")
            Button("加一", {=> count.value += 1}).key("increment")
        }.spacing(8.vp).padding(12.vp)
    })
    let report = runtime.renderReport(402.0, 874.0)
    @Expect(report.contains("\"protocol\":\"canghui.native-scene.v0\""))
    @Expect(report.contains("\"name\":\"canghui.mobile-widgets\""))
    @Expect(report.contains("\"kind\":\"scene.begin\""))
    @Expect(report.contains("\"kind\":\"text\""))
    @Expect(report.contains("ExplorerX 0.6.44"))
    @Expect(report.contains("\"kind\":\"paint.fill-rounded-rect\""))
    @Expect(report.contains("\"inputCount\":0"))
    @Expect(runtime.lastFrameCount(), 1)
}

@Test
func mobileWidgetRuntimeDispatchesPointerToRealButton(): Unit {
    let runtime = MobileWidgetRuntime()
    let count = State<Int64>(0)
    runtime.setBody({=>
        VStack {
            Button("加一", {=> count.value += 1}).key("increment")
        }.padding(10.vp)
    })
    let first = runtime.renderReport(300.0, 300.0)
    @Expect(count.value, 0)
    @Expect(runtime.pointerDown(40.0, 30.0))
    @Expect(runtime.pointerUp(40.0, 30.0))
    @Expect(count.value, 1)
    @Expect(runtime.totalInputCount(), 2)
    let second = runtime.renderReport(300.0, 300.0)
    @Expect(second.contains("\"inputCount\":2"))
    @Expect(first != second)
}

@Test
func mobileWidgetRuntimeRejectsMissingBodyAndBadViewport(): Unit {
    let runtime = MobileWidgetRuntime()
    let missing = runtime.renderReport(300.0, 300.0)
    @Expect(missing.contains("\"ok\":false"))
    @Expect(missing.contains("no-body"))
    runtime.setBody({=> Label("ready") })
    let invalid = runtime.renderReport(0.0, 300.0)
    @Expect(invalid.contains("\"ok\":false"))
    @Expect(invalid.contains("invalid-viewport"))
}
