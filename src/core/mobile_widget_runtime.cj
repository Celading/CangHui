package chui.core

import sdl.{Color, FrameInfo, MouseButton, Rect, Renderer, UiEvent}

/**
 * Device-free widget runtime for embedded hosts.
 *
 * It builds the same `Widget` tree as the desktop loop, lays it out for an
 * explicit viewport and records the frame as Draw IR. The host decides how to
 * present that list (CoreGraphics/Metal, a test, or a receipt) and feeds touch
 * and key events back through [pointerDown]/[pointerMove]/[pointerUp].
 */
public class MobileWidgetRuntime {
    private let renderer = Renderer.recordingHeadless()
    private let stateStore = StateStore()
    private let ctx: UiContext
    private var body: ?(() -> Unit) = None
    private var root: ?Widget = None
    private var viewportWidth: Float32 = 0.0
    private var viewportHeight: Float32 = 0.0
    private var elapsedMs: UInt64 = 0
    private var inputCount: Int64 = 0
    private var frameCount: Int64 = 0

    public init(theme!: Theme = Theme.light()) {
        this.ctx = UiContext(renderer, theme)
    }

    /** Installs the application view builder; safe to call once per app. */
    public func setBody(value: () -> Unit): Unit {
        this.body = value
        renderer.clearDrawIr()
    }

    public func hasBody(): Bool { body.isSome() }

    public func lastFrameCount(): Int64 { frameCount }

    public func totalInputCount(): Int64 { inputCount }

    public func dispatchEvent(event: UiEvent): Bool {
        inputCount += 1
        match (root) {
            case Some(widget) => widget.handle(ctx, event)
            case None => false
        }
    }

    public func pointerDown(x: Float32, y: Float32): Bool {
        dispatchEvent(UiEvent.MouseDown(MouseButton.Left, x, y))
    }

    public func pointerMove(x: Float32, y: Float32): Bool {
        dispatchEvent(UiEvent.MouseMove(x, y))
    }

    public func pointerUp(x: Float32, y: Float32): Bool {
        dispatchEvent(UiEvent.MouseUp(MouseButton.Left, x, y))
    }

    public func textInput(value: String): Bool {
        dispatchEvent(UiEvent.TextInput(value))
    }

    /**
     * Builds, lays out and records one frame. Returns the native-scene report or
     * an error report when no body was installed.
     */
    public func renderReport(width: Float32, height: Float32): String {
        if (width <= 0.0 || height <= 0.0) {
            return "{\"protocol\":\"canghui.native-scene.v0\",\"ok\":false," +
                "\"error\":\"invalid-viewport\"}"
        }
        let builder = match (body) {
            case Some(value) => value
            case None => return "{\"protocol\":\"canghui.native-scene.v0\",\"ok\":false," +
                "\"error\":\"no-body\"}"
        }
        viewportWidth = width
        viewportHeight = height
        frameCount += 1
        ctx.frame = FrameInfo(elapsedMs, if (frameCount > 1) { UInt64(16) } else { UInt64(0) })
        elapsedMs += UInt64(16)
        ctx.viewportWidth = width
        ctx.viewportHeight = height
        ctx.displayScale = 1.0
        ctx.fontScale = 1.0
        renderer.clearDrawIr()
        let widget = buildRoot(builder, stateStore)
        root = Some(widget)
        widget.layout(ctx, Rect(0.0, 0.0, width, height))
        renderer.beginScene(width, height, ctx.theme.bg)
        widget.draw(ctx)
        renderer.endScene()
        drawIrReport(width, height)
    }

    private func drawIrReport(width: Float32, height: Float32): String {
        let commands = renderer.drawIr()
        let out = StringBuilder()
        out.append("{\"protocol\":\"canghui.native-scene.v0\",")
        out.append("\"name\":\"canghui.mobile-widgets\",\"ok\":true,\"frames\":[{\"width\":")
        out.append(width.toString())
        out.append(",\"height\":")
        out.append(height.toString())
        out.append(",\"inputCount\":")
        out.append(inputCount.toString())
        out.append(",\"selectedAction\":\"\",\"drawIr\":[")
        var index: Int64 = 0
        while (index < commands.size) {
            if (index > 0) { out.append(",") }
            out.append(commands[index].toJson())
            index += 1
        }
        out.append("],\"actions\":[]}]}")
        out.toString()
    }
}
