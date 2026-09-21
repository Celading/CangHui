package chui.core

/** Retained across rebuilds; input coordinates are already logical viewport units. */
internal class ScrollPan {
    var pending = false
    var axis: Int64 = 0
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var offsetX: Float32 = 0.0
    var offsetY: Float32 = 0.0

    func begin(x: Float32, y: Float32, offsetX: Float32, offsetY: Float32): Unit {
        pending = true
        axis = 0
        this.x = x
        this.y = y
        this.offsetX = offsetX
        this.offsetY = offsetY
    }

    func cancel(ctx: UiContext, id: String): Unit {
        pending = false
        axis = 0
        if (ctx.isDragging(id)) { ctx.clearDrag() }
        ctx.releasePointerCapture(id)
    }
}
