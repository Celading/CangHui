package chui.desktop

import sdl.Rect

// Window-local acknowledgement of the last caret area sent to the platform.
internal class TextInputAnchorState {
    private var applied: ?Rect = None

    func invalidate(): Unit { applied = None }

    func update(next: ?Rect, send: (Rect) -> Unit): Unit {
        match (next) {
            case Some(anchor) =>
                if (!sameAnchorRect(applied, anchor)) {
                    try {
                        send(anchor)
                        applied = Some(anchor)
                    } catch (_: Exception) {
                        // A refusal is not an acknowledgement. Retry on a later
                        // draw; never spin or assume the platform retained old state.
                        invalidate()
                    }
                }
            case None => invalidate()
        }
    }
}

private func sameAnchorRect(applied: ?Rect, next: Rect): Bool {
    match (applied) {
        case Some(rect) => rect.x == next.x && rect.y == next.y && rect.w == next.w && rect.h == next.h
        case None => false
    }
}
