package chui.native_scene

import std.collection.ArrayList
import std.sync.Mutex

let IOS_PRODUCT_MAX_FRAME_MILLI: Int64 = 10_000_000
let IOS_PRODUCT_MAX_TEXT_BYTES: Int64 = 4096
let IOS_PRODUCT_BACKSPACE_KEY: Int64 = 42
let IOS_PRODUCT_RETURN_KEY: Int64 = 40
let IOS_PRODUCT_PLACEHOLDER = "未输入"

/**
 * Reference product state for the iOS consumer shell.
 *
 * Product code owns the counter, the input text and the action labels; the
 * scene builder and the Draw IR protocol stay in this package. The state is
 * only mutated from the Cangjie scheduler thread through [report] and [key].
 */
public class NativeSceneProductState {
    private let stateMutex = Mutex()
    private let pointer = NativeScenePointer()
    private var counter: Int64 = 0
    private var inputText = IOS_PRODUCT_PLACEHOLDER
    private var textEntered = false
    private var lastAction = ""
    private var renderCount: Int64 = 0
    private var inputCount: Int64 = 0
    private var keyCount: Int64 = 0
    private var imeCount: Int64 = 0
    private var lastKeyCode: Int64 = -1

    public static func incrementRect(): NativeRect {
        NativeRect(24.0, 272.0, 150.0, 48.0)
    }

    public static func focusRect(width: Float32): NativeRect {
        NativeRect(186.0, 272.0, max(96.0, width - 210.0), 48.0)
    }

    /**
     * Builds one frame report. When [applyEvent] is true the input event is
     * committed exactly once, then the scene is rebuilt so the same frame
     * shows the resulting state.
     */
    public func report(
        width: Float32,
        height: Float32,
        eventKind: Int64,
        x: Float32,
        y: Float32,
        applyEvent: Bool
    ): String {
        synchronized(stateMutex) {
            renderCount += 1
            var scene = buildScene(width, height)
            if (applyEvent && eventKind != 0) {
                inputCount += 1
                let action = pointer.dispatch(scene, eventKind, x, y)
                match (action) {
                    case Some(value) =>
                        lastAction = value
                        if (value == "increment") { counter += 1 }
                    case None => ()
                }
                scene = buildScene(width, height)
            }
            scene.report(inputCount: inputCount, selectedAction: lastAction)
        }
    }

    public func setInputText(value: String): Bool {
        if (value.toArray().size > IOS_PRODUCT_MAX_TEXT_BYTES) { return false }
        synchronized(stateMutex) {
            textEntered = !value.isEmpty()
            inputText = if (textEntered) { value } else { IOS_PRODUCT_PLACEHOLDER }
            imeCount += 1
            lastAction = "ime"
        }
        true
    }

    public func key(phase: Int64, keyCode: Int64): Bool {
        if (phase < 0 || phase > 1 || keyCode < 0 || keyCode > 65535) { return false }
        synchronized(stateMutex) {
            keyCount += 1
            lastKeyCode = keyCode
            if (phase == 1) {
                if (keyCode == IOS_PRODUCT_BACKSPACE_KEY) {
                    removeLastRune()
                } else if (keyCode == IOS_PRODUCT_RETURN_KEY) {
                    lastAction = "return"
                }
            }
        }
        true
    }

    public func stateJson(): String {
        synchronized(stateMutex) {
            let scene = buildScene(1000.0, 1000.0)
            "{\"protocol\":" + nativeSceneQuote(CANGHUI_NATIVE_SCENE_PROTOCOL) +
                ",\"counter\":" + counter.toString() +
                ",\"inputText\":" + nativeSceneQuote(inputText) +
                ",\"lastAction\":" + nativeSceneQuote(lastAction) +
                ",\"renderCount\":" + renderCount.toString() +
                ",\"inputCount\":" + inputCount.toString() +
                ",\"keyCount\":" + keyCount.toString() +
                ",\"imeCount\":" + imeCount.toString() +
                ",\"lastKeyCode\":" + lastKeyCode.toString() +
                ",\"commandCount\":" + scene.commandCount().toString() +
                ",\"actionCount\":" + scene.actionCount().toString() +
                ",\"textLayout\":" + (scene.hasMeasuredTextLayout()).toString() +
                "}"
        }
    }

    public func currentCounter(): Int64 { synchronized(stateMutex) { counter } }
    public func currentInputText(): String { synchronized(stateMutex) { inputText } }
    public func currentLastAction(): String { synchronized(stateMutex) { lastAction } }
    public func totalRenderCount(): Int64 { synchronized(stateMutex) { renderCount } }
    public func totalInputCount(): Int64 { synchronized(stateMutex) { inputCount } }
    public func totalKeyCount(): Int64 { synchronized(stateMutex) { keyCount } }
    public func totalImeCount(): Int64 { synchronized(stateMutex) { imeCount } }
    public func currentLastKeyCode(): Int64 { synchronized(stateMutex) { lastKeyCode } }

    private func removeLastRune(): Unit {
        if (!textEntered) { return }
        let runes = inputText.toRuneArray()
        if (runes.size <= 1) {
            textEntered = false
            inputText = IOS_PRODUCT_PLACEHOLDER
            return
        }
        let out = StringBuilder()
        var index: Int64 = 0
        while (index < runes.size - 1) {
            out.append(runes[index].toString())
            index += 1
        }
        inputText = out.toString()
    }

    private func buildScene(width: Float32, height: Float32): NativeScene {
        let background = NativeColor.rgb(12, 18, 28)
        let panelColor = NativeColor.rgb(24, 34, 50)
        let accent = NativeColor.rgb(64, 156, 255)
        let primaryText = NativeColor.rgb(240, 246, 255)
        let secondaryText = NativeColor.rgb(158, 174, 196)
        let scene = NativeScene("canghui-ios-product", width, height, background)
        scene.text("仓绘 · iOS", 24.0, 28.0, primaryText, pointSize: 26.0, bold: true)
        scene.text(
            "同一份 CangHui 场景在 iPad 上由 UIKit 承载、Metal 呈现。",
            24.0, 64.0, secondaryText,
            pointSize: 14.0, width: width - 48.0, height: 44.0,
            lineLimit: 2, alignment: "left")
        scene.panel(
            NativeRect(24.0, 124.0, width - 48.0, 128.0),
            panelColor, radius: 14.0)
        scene.text("交互计数", 44.0, 142.0, secondaryText, pointSize: 14.0)
        scene.text(counter.toString(), 44.0, 162.0, primaryText,
            pointSize: 44.0, bold: true)
        scene.text(
            "点击下方按钮，计数由 Cangjie 场景状态驱动。",
            44.0, 218.0, secondaryText,
            pointSize: 13.0, width: width - 88.0, height: 22.0,
            lineLimit: 1, alignment: "left")
        scene.button("increment", "加一", NativeSceneProductState.incrementRect(),
            accent, primaryText)
        scene.button("focus", "聚焦输入", NativeSceneProductState.focusRect(width),
            NativeColor.rgb(38, 52, 74), primaryText,
            edge: NativeColor.rgb(72, 92, 120))
        scene.panel(
            NativeRect(24.0, 340.0, width - 48.0, 88.0),
            panelColor, radius: 12.0)
        scene.text("输入内容", 44.0, 354.0, secondaryText, pointSize: 13.0)
        scene.text(inputText, 44.0, 376.0, primaryText,
            pointSize: 18.0, bold: true,
            width: width - 88.0, height: 34.0, lineLimit: 1, alignment: "left")
        let status = if (lastAction.isEmpty()) { "尚无操作" } else { lastAction }
        scene.text("最近操作：" + status, 24.0, 448.0, secondaryText, pointSize: 14.0)
        scene.text(
            "CangHui native-scene.v0 · 产品消费侧样例",
            24.0, max(480.0, height - 36.0), secondaryText, pointSize: 12.0)
        scene
    }
}

let iosProductState = NativeSceneProductState()

@C
public func canghui_ios_product_render(
    widthMilli: Int64,
    heightMilli: Int64,
    eventKind: Int64,
    xMilli: Int64,
    yMilli: Int64,
    output: CPointer<UInt8>,
    outputCapacity: Int64,
    outputLength: CPointer<Int64>
): Int32 {
    if (outputLength.isNull()) { return -1 }
    if (widthMilli <= 0 || heightMilli <= 0 ||
        widthMilli > IOS_PRODUCT_MAX_FRAME_MILLI || heightMilli > IOS_PRODUCT_MAX_FRAME_MILLI) {
        return -1
    }
    if (eventKind < 0 || eventKind > 5) { return -1 }
    if (eventKind != 0 &&
        (xMilli < -IOS_PRODUCT_MAX_FRAME_MILLI || xMilli > IOS_PRODUCT_MAX_FRAME_MILLI ||
         yMilli < -IOS_PRODUCT_MAX_FRAME_MILLI || yMilli > IOS_PRODUCT_MAX_FRAME_MILLI)) {
        return -1
    }
    let applyEvent = output.isNull() || outputCapacity <= 0
    let report = iosProductState.report(
        Float32(widthMilli) / Float32(1000),
        Float32(heightMilli) / Float32(1000),
        eventKind,
        Float32(xMilli) / Float32(1000),
        Float32(yMilli) / Float32(1000),
        applyEvent)
    copyNativeSceneUtf8ToCaller(report, output, outputCapacity, outputLength)
}

@C
public func canghui_ios_product_set_text(
    text: CPointer<UInt8>,
    length: Int64
): Int32 {
    if (length < 0 || length > IOS_PRODUCT_MAX_TEXT_BYTES) { return -1 }
    let value = match (iosProductUtf8String(text, length)) {
        case Some(decoded) => decoded
        case None => return -1
    }
    if (iosProductState.setInputText(value)) { 0 } else { -1 }
}

@C
public func canghui_ios_product_key(phase: Int64, keyCode: Int64): Int32 {
    if (iosProductState.key(phase, keyCode)) { 0 } else { -1 }
}

@C public func canghui_ios_product_counter(): Int64 { iosProductState.currentCounter() }
@C public func canghui_ios_product_render_count(): Int64 { iosProductState.totalRenderCount() }
@C public func canghui_ios_product_input_count(): Int64 { iosProductState.totalInputCount() }
@C public func canghui_ios_product_key_count(): Int64 { iosProductState.totalKeyCount() }
@C public func canghui_ios_product_ime_count(): Int64 { iosProductState.totalImeCount() }
@C public func canghui_ios_product_last_key_code(): Int64 { iosProductState.currentLastKeyCode() }

@C
public func canghui_ios_product_input_text(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosProductState.currentInputText(), output, capacity, length)
}

@C
public func canghui_ios_product_last_action(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosProductState.currentLastAction(), output, capacity, length)
}

@C
public func canghui_ios_product_state(
    output: CPointer<UInt8>,
    capacity: Int64,
    length: CPointer<Int64>
): Int32 {
    copyNativeSceneUtf8ToCaller(iosProductState.stateJson(), output, capacity, length)
}

private func iosProductUtf8String(text: CPointer<UInt8>, length: Int64): ?String {
    if (text.isNull() || length <= 0) { return Some("") }
    let bytes = ArrayList<UInt8>()
    unsafe {
        for (i in 0..length) {
            bytes.add(text.read(i))
        }
    }
    try {
        Some(String.fromUtf8(bytes.toArray()))
    } catch (error: Exception) {
        None
    }
}
