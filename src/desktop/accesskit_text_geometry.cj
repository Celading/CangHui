package chui.desktop

import chui.core.SemanticTextGeometry
import sdl.Rect
import std.collection.ArrayList

// Groups follow logical character order. A bidi boundary (including reordered
// same-direction islands) splits a run, not a hard line. The checked C bridge
// owns same-line links, exact span counts, selection and generated identities.
@When[os == "Linux"]
internal func appendLinuxTextGeometry(symbol: (String) -> AccessibilityRef,
    tree: AccessibilityRef, id: UInt64, text: SemanticTextGeometry,
    window: DesktopAccessibilityGeometry): Unit {
    let layout = text.layout
    let starts = ArrayList<Int64>()
    starts.add(0)
    for (i in 1..layout.count) {
        let a = layout.glyph(i - 1); let b = layout.glyph(i)
        let reversed = if (b.rightToLeft) { b.frame.right() > a.frame.right() }
            else { b.frame.x < a.frame.x }
        if (a.line != b.line || a.rightToLeft != b.rightToLeft ||
            a.frame.y != b.frame.y || a.frame.h != b.frame.h || reversed) { starts.add(i) }
    }
    // No enclosing/fabricated glyph geometry when native run capacity is exceeded.
    if (starts.size > 4096) { return }
    starts.add(layout.count)
    let count = starts.size - 1
    unsafe {
        let spans = LibC.malloc<UIntNative>(count: count)
        requireTextGeometry(spans.isNotNull(), "partition allocation")
        try {
            for (i in 0..count) {
                let first = layout.glyph(starts[i])
                spans.write(i, UIntNative(if (first.startByte == first.endByte) { 0 }
                    else { starts[i + 1] - starts[i] }))
            }
            requireTextGeometry(CFunc<(AccessibilityRef, UInt64, UIntNative, CPointer<UIntNative>) -> Bool>(
                symbol("chui_ak_tree_partition"))(tree, id, UIntNative(count), spans), "partition")
        } finally { LibC.free(spans) }
    }
    for (i in 0..count) {
        appendLinuxGlyphRun(symbol, tree, id, i, text, window, starts[i], starts[i + 1])
    }
}

@When[os == "Linux"]
private func appendLinuxGlyphRun(symbol: (String) -> AccessibilityRef,
    tree: AccessibilityRef, id: UInt64, run: Int64, text: SemanticTextGeometry,
    window: DesktopAccessibilityGeometry, start: Int64, end: Int64): Unit {
    let first = text.layout.glyph(start)
    let count = if (first.startByte == first.endByte) { 0 } else { end - start }
    let frames = Array<Rect>(end - start, {i =>
        let r = text.layout.glyph(start + i).frame
        window.logicalToPixels(Rect(text.x + r.x, text.y + r.y, r.w, r.h))
    })
    var left = frames[0].x; var right = frames[0].right()
    for (r in frames) { left = min(left, r.x); right = max(right, r.right()) }
    unsafe {
        let positions = LibC.malloc<Float32>(count: max(Int64(1), count))
        requireTextGeometry(positions.isNotNull(), "position allocation")
        try {
            let widths = LibC.malloc<Float32>(count: max(Int64(1), count))
            requireTextGeometry(widths.isNotNull(), "width allocation")
            try {
                var extent = Float64(right) - Float64(left)
                for (i in 0..count) {
                    let r = frames[i]
                    let p = if (first.rightToLeft) { right - r.right() } else { r.x - left }
                    positions.write(i, p); widths.write(i, r.w)
                    // Arrays are Float32 but AccessKit bounds are Float64. Keep
                    // their actual rounded sum inside the run, never guess widths.
                    extent = max(extent, Float64(p) + Float64(r.w))
                }
                let x = if (first.rightToLeft) { Float64(right) - extent } else { Float64(left) }
                requireTextGeometry(CFunc<(AccessibilityRef, UInt64, UIntNative,
                    Float64, Float64, Float64, Float64, UInt32, UIntNative,
                    CPointer<Float32>, CPointer<Float32>) -> Bool>(symbol("chui_ak_tree_run_geometry"))(
                        tree, id, UIntNative(run), x, Float64(frames[0].y), extent,
                        Float64(frames[0].h), if (first.rightToLeft) { UInt32(1) } else { UInt32(0) },
                        UIntNative(count), positions, widths), "glyph projection")
            } finally { LibC.free(widths) }
        } finally { LibC.free(positions) }
    }
}

@When[os == "Linux"]
private func requireTextGeometry(valid: Bool, operation: String): Unit {
    if (!valid) { throw IllegalStateException("AccessKit text ${operation} failed") }
}
