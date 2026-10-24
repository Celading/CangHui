package chui.host

import chui.core.*
import chui.core.LengthUnits

private let IOS_WIDGET_MAX_DIMENSION_MILLI: Int64 = 10_000_000

private let widgetCounter = State<Int64>(0)
private let widgetRuntime = MobileWidgetRuntime()
private var widgetFamily: Int64 = 0
private var widgetWidth: Float32 = 0.0
private var widgetHeight: Float32 = 0.0
private var widgetProfile = classifyIOSDevice(0, 1.0, 1.0)
private var widgetRenderCount: Int64 = 0

private func refreshWidgetProfile(width: Float32, height: Float32): Unit {
    widgetWidth = width
    widgetHeight = height
    widgetProfile = classifyIOSDevice(widgetFamily, width, height, scale: 1.0)
}

private func widgetScreenContent(): Unit {
    let profile = widgetProfile
    let inset: Float32 = if (profile.breakpoint == IOSLayoutBreakpoint.Compact) {
        12.0
    } else {
        20.0
    }
    VStack {
        Button("加一", {=> widgetCounter.value += 1}).key("increment")
        Label("仓绘 · iOS").fontSize(24.fp).bold()
        Label("${profile.deviceClass.name()} · ${profile.breakpoint.name()} · " +
            "${Int64(widgetWidth)}x${Int64(widgetHeight)}").muted().fontSize(13.fp)
        Panel {
            VStack {
                Label("真实 CangHui Widget 树").fontSize(13.fp).muted()
                Label(widgetCounter.value.toString()).fontSize(40.fp).bold()
                Label("点击按钮，状态由 State 驱动并重新生成 Draw IR").fontSize(12.fp).muted()
            }.spacing(6.vp).padding(14.vp)
        }
        HStack {
            Button("重置", {=> widgetCounter.value = 0}).key("reset")
        }
        Divider()
        Label("Widget → Renderer.recordingHeadless → canghui.native-scene.v0 → Metal")
            .fontSize(11.fp).muted()
    }.spacing(10.vp).padding(Float64(inset).vp).fillWidth()
}

@C
public func canghui_ios_widgets_start(): Int64 {
    widgetRuntime.setBody({=> widgetScreenContent() })
    0
}

@C
public func canghui_ios_widgets_set_family(family: Int64): Int64 {
    if (family < 0 || family > 2) { return -1 }
    widgetFamily = family
    0
}

@C
public func canghui_ios_widgets_render(
    widthMilli: Int64,
    heightMilli: Int64,
    eventKind: Int64,
    xMilli: Int64,
    yMilli: Int64,
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    if (length.isNull()) { return -1 }
    if (widthMilli <= 0 || heightMilli <= 0 ||
        widthMilli > IOS_WIDGET_MAX_DIMENSION_MILLI ||
        heightMilli > IOS_WIDGET_MAX_DIMENSION_MILLI) {
        return -1
    }
    if (eventKind < 0 || eventKind > 5) { return -1 }
    let width = Float32(widthMilli) / Float32(1000)
    let height = Float32(heightMilli) / Float32(1000)
    refreshWidgetProfile(width, height)
    let sizing = output.isNull() || capacity <= 0
    if (sizing && eventKind != 0) {
        let x = Float32(xMilli) / Float32(1000)
        let y = Float32(yMilli) / Float32(1000)
        match (eventKind) {
            case 1 => let _ = widgetRuntime.pointerDown(x, y)
            case 2 => let _ = widgetRuntime.pointerMove(x, y)
            case 3 => let _ = widgetRuntime.pointerUp(x, y)
            case 5 =>
                let _ = widgetRuntime.pointerDown(x, y)
                let _ = widgetRuntime.pointerUp(x, y)
            case _ => ()
        }
    }
    widgetRenderCount += 1
    let report = widgetRuntime.renderReport(width, height)
    let bytes = report.toArray()
    unsafe {
        length.write(Int64(bytes.size))
        if (output.isNull() || capacity < Int64(bytes.size)) { return -2 }
        for (i in 0..bytes.size) {
            output.write(i, UInt8(bytes[i]))
        }
    }
    0
}

@C public func canghui_ios_widgets_counter(): Int64 { widgetCounter.value }
@C public func canghui_ios_widgets_render_count(): Int64 { widgetRenderCount }

@C public func canghui_ios_widgets_profile(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    if (length.isNull() || capacity < 0) { return -1 }
    let bytes = widgetProfile.json().toArray()
    unsafe {
        length.write(Int64(bytes.size))
        if (output.isNull() || capacity < Int64(bytes.size)) { return -2 }
        for (i in 0..bytes.size) {
            output.write(i, UInt8(bytes[i]))
        }
    }
    0
}
