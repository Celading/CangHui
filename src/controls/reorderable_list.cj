package chui.controls

import std.collection.{ArrayList, HashSet}
import sdl.{GamepadButton, GamepadConnectionState, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent, clampF32}
import chui.core.{CUI_SHADOW_CLEARANCE, CursorShape, State, UiContext, Widget, resolveControlKey, buildLazyChildren,
    ControlSemantics, SemanticActionKind, drawFocusRing, drawSurface, emit, lazyKeyOrIndex, localState,
    recordControlSemantics, registerFocusable}

// Width of the drag handle at the left of each row.
private let REORDER_HANDLE_W: Float32 = 30.0

/**
 * A vertical list whose fixed-height rows can be dragged to reorder. Each row carries a grip handle on
 * its left; pressing the handle lifts the row to follow the pointer while the others part to open a gap
 * at the drop position. Releasing commits the move by calling `onMove(from, to)` — the caller reorders
 * its own data, and the next build shows the new order.
 *
 * Rows are ordinary widgets built by `item`, so a row can hold its own content and controls (presses
 * outside the handle fall through to the row). Row identity follows `key` so per-row state survives the
 * reorder. Suited to modest, fully visible lists (a settings order, a playlist); wrap a long one so the
 * drag interaction stays within view.
 */
public class ReorderableList <: Widget {
    private let count: Int64
    private let rowHeight: Float32
    private let spacing: Float32
    private let onMove: (Int64, Int64) -> Unit
    private let rows: Array<Widget>
    private let dragIndex: State<Int64>
    private let grabOffset: State<Float32>
    private let pointerY: State<Float32>
    private let dragId: String
    private let rowKeys: Array<String>
    private let gripIds: Array<String>
    private let transactionKeys: State<Array<String>>
    private let keyboardDrag: State<Bool>
    private let keyboardTarget: State<Int64>
    private let gamepadOwner: State<Int64>
    private var rowLabel: (Int64) -> String = {i => "Reorder item ${i + 1}"}
    private var frame = Rect.zero()

    public init(
        count: Int64,
        rowHeight: Float32,
        onMove: (Int64, Int64) -> Unit,
        spacing!: Float32 = 6.0,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "ReorderableList")
        this.count = max(0, count)
        this.rowHeight = max(1.0, rowHeight)
        this.spacing = max(0.0, spacing)
        this.onMove = onMove
        this.dragId = "ReorderableList:${ident}:drag"
        this.dragIndex = localState<Int64>("ReorderableList:${ident}:dragIndex") {-1}
        this.grabOffset = localState<Float32>("ReorderableList:${ident}:grab") {0.0}
        this.pointerY = localState<Float32>("ReorderableList:${ident}:pointerY") {0.0}
        this.transactionKeys = localState<Array<String>>("ReorderableList:${ident}:keys") {[]}
        this.keyboardDrag = localState<Bool>("ReorderableList:${ident}:keyboard") {false}
        this.keyboardTarget = localState<Int64>("ReorderableList:${ident}:target") {-1}
        this.gamepadOwner = localState<Int64>("ReorderableList:${ident}:gamepad") {-1}
        let keyAt = lazyKeyOrIndex(key)
        let keys = Array<String>(this.count, {i => keyAt(i)})
        let seen = HashSet<String>()
        for (value in keys) {
            if (value.isEmpty() || seen.contains(value)) {
                throw IllegalArgumentException("ReorderableList keys must be nonempty and unique")
            }
            seen.add(value)
        }
        this.rowKeys = keys
        let grips = Array<String>(this.count, {i => "ReorderableList:${ident}:item:${keys[i]}:grip"})
        this.gripIds = grips
        let pairs = buildLazyChildren("ReorderableList:${ident}", 0, this.count - 1, {i => keys[i]}) {i =>
            registerFocusable(grips[i])
            item(i)
        }
        let built = ArrayList<Widget>()
        for (pair in pairs) {
            let (_, widget) = pair
            built.add(widget)
        }
        this.rows = built.toArray()
        emit(this)
    }

    /** Names each grip using the current data index, without changing its stable key. */
    public func accessibilityLabels(label: (Int64) -> String): ReorderableList {
        rowLabel = label
        this
    }

    /**
     * The data-driven form: reorder over an `Array<T>`. `onMove(from, to)` receives array indices; the
     * caller applies the move to its own state. `key` gives each item a stable identity across the move.
     *
     * ```
     * ReorderableList.of(model.tracks, 52.0, {from, to => model.move(from, to)}, key: {t => t.id}) {
     *     track => trackRow(track)
     * }
     * ```
     */
    public static func of<T>(
        data: Array<T>,
        rowHeight: Float32,
        onMove: (Int64, Int64) -> Unit,
        spacing!: Float32 = 6.0,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        item!: (T) -> Unit
    ): ReorderableList {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        ReorderableList(data.size, rowHeight, onMove, spacing: spacing, key: itemKey, id: id) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, contentHeight())
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        reconcileInteraction(ctx)
        let contentX = rect.x + REORDER_HANDLE_W
        let contentW = max(0.0, rect.w - REORDER_HANDLE_W)
        let target = dropTarget()
        for (i in 0..rows.size) {
            let y = rowTop(i, target)
            rows[i].layout(ctx, Rect(contentX, y, contentW, rowHeight))
        }
    }

    public func draw(ctx: UiContext): Unit {
        if (!ctx.interactionsEnabled()) { cancelDrag(ctx) }
        let target = dropTarget()
        let dragging = dragIndex.value
        // Non-dragged rows at their (possibly shifted) slots.
        for (i in 0..rows.size) {
            if (i != dragging) {
                drawRow(ctx, i, rowTop(i, target), false)
            }
        }
        // The dragged row last, lifted, so it floats above the rest.
        if (dragging >= 0 && dragging < rows.size) {
            drawRow(ctx, dragging, rowTop(dragging, target), true)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        reconcileInteraction(ctx)
        if (!ctx.interactionsEnabled()) { cancelDrag(ctx); return false }
        let dragging = dragIndex.value >= 0
        match (event) {
            case UiEvent.PointerCancelled | UiEvent.WindowFocusChanged(false) =>
                cancelDrag(ctx)
                for (row in rows) { let _ = row.handle(ctx, event) }
                return dragging
            case UiEvent.GamepadConnectionChanged(device, GamepadConnectionState.Disconnected) =>
                if (gamepadOwner.value == Int64(device.id)) { cancelDrag(ctx); return dragging }
            case UiEvent.GamepadButtonDown(device, button) =>
                if (gamepadOwner.value >= 0 && gamepadOwner.value != Int64(device)) { return false }
                let mapped: ?Key = match (button) {
                    case GamepadButton.South => Some(Key.Enter)
                    case GamepadButton.East => Some(Key.Escape)
                    case GamepadButton.DPadUp => Some(Key.Up)
                    case GamepadButton.DPadDown => Some(Key.Down)
                    case _ => None
                }
                match (mapped) {
                    case Some(value) =>
                        if (handleKey(ctx, value, false)) {
                            if (keyboardDrag.value) { gamepadOwner.value = Int64(device) }
                            return true
                        }
                    case None => ()
                }
            case UiEvent.KeyDown(key, repeat) =>
                if (handleKey(ctx, key, repeat)) { return true }
            case UiEvent.Frame(_) =>
                for (row in rows) {
                    let _ = row.handle(ctx, event)
                }
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (keyboardDrag.value) { cancelDrag(ctx) }
                if (dragIndex.value < 0) {
                    let row = handleRowAt(x, y)
                    if (row >= 0) {
                        beginDrag(ctx, row, false)
                        grabOffset.value = y - slotTop(row)
                        pointerY.value = y
                        return true
                    }
                }
            case UiEvent.MouseMove(x, y) =>
                // Hovering a grip advertises the drag affordance; a live drag keeps the shape claimed
                // even as the pointer strays off the strip.
                if (dragging || handleRowAt(x, y) >= 0) {
                    ctx.claimHover(dragId, CursorShape.Interactive)
                }
                if (dragging && !keyboardDrag.value && ctx.isDragging(dragId) && ctx.leftMouseDown) {
                    pointerY.value = y
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                if (dragging && !keyboardDrag.value && ctx.isDragging(dragId)) {
                    commitDrag(ctx)
                    return true
                }
            case _ => ()
        }
        // Not a drag gesture: route to the row content so its own controls work.
        if (dragIndex.value < 0) {
            var i = rows.size - 1
            while (i >= 0) {
                if (rows[i].handle(ctx, event)) {
                    return true
                }
                i -= 1
            }
        }
        false
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (i in 0..rows.size) {
            ids.add(gripIds[i])
            for (fid in rows[i].focusableIds()) {
                ids.add(fid)
            }
        }
        ids.toArray()
    }

    private func contentHeight(): Float32 {
        if (count <= 0) {
            0.0
        } else {
            Float32(count) * rowHeight + Float32(count - 1) * spacing
        }
    }

    private func stride(): Float32 {
        rowHeight + spacing
    }

    // The resting top of row `pos` (its slot in display order).
    private func slotTop(pos: Int64): Float32 {
        frame.y + Float32(pos) * stride()
    }

    // The top of row `i` this frame: its lifted pointer position when dragged, otherwise its slot after
    // the drag preview reorders the list around the open gap.
    private func rowTop(i: Int64, target: Int64): Float32 {
        let dragging = dragIndex.value
        if (dragging < 0) {
            return slotTop(i)
        }
        if (i == dragging) {
            if (keyboardDrag.value) { return slotTop(target) }
            let lifted = pointerY.value - grabOffset.value
            return clampF32(lifted, frame.y, frame.y + Float32(max(0, count - 1)) * stride())
        }
        slotTop(previewPosition(i, dragging, target))
    }

    // Display position of a non-dragged row when the dragged row is previewed at `target`.
    private func previewPosition(i: Int64, dragging: Int64, target: Int64): Int64 {
        let reduced = if (i > dragging) {
            i - 1
        } else {
            i
        }
        if (reduced >= target) {
            reduced + 1
        } else {
            reduced
        }
    }

    // The drop index for the dragged row's current position (by its centre).
    private func dropTarget(): Int64 {
        if (dragIndex.value < 0 || count <= 0) {
            return dragIndex.value
        }
        if (keyboardDrag.value) { return keyboardTarget.value }
        let lifted = pointerY.value - grabOffset.value
        let center = lifted + rowHeight / 2.0
        let raw = Int64((center - frame.y) / stride())
        if (raw < 0) {
            0
        } else if (raw > count - 1) {
            count - 1
        } else {
            raw
        }
    }

    private func commitDrag(ctx: UiContext): Unit {
        let from = dragIndex.value
        let to = dropTarget()
        cancelDrag(ctx)
        if (from >= 0 && from < count && to >= 0 && to < count && from != to) {
            onMove(from, to)
        }
    }

    private func beginDrag(ctx: UiContext, row: Int64, keyboard: Bool): Unit {
        dragIndex.value = row
        transactionKeys.value = rowKeys.clone()
        keyboardDrag.value = keyboard
        keyboardTarget.value = row
        gamepadOwner.value = -1
        grabOffset.value = 0.0
        pointerY.value = slotTop(row)
        ctx.focus(gripIds[row], viaKeyboard: keyboard)
        ctx.beginDrag(dragId)
    }

    private func cancelDrag(ctx: UiContext): Unit {
        if (dragIndex.value >= 0) {
            dragIndex.value = -1
            grabOffset.value = 0.0
            transactionKeys.value = []
            keyboardDrag.value = false
            keyboardTarget.value = -1
            gamepadOwner.value = -1
        }
        if (ctx.isDragging(dragId)) { ctx.clearDrag() }
    }

    private func reconcileInteraction(ctx: UiContext): Unit {
        if (dragIndex.value < 0) { return }
        if (dragIndex.value >= count || transactionKeys.value.size != rowKeys.size ||
            !ctx.isDragging(dragId)) { cancelDrag(ctx); return }
        for (i in 0..rowKeys.size) {
            if (transactionKeys.value[i] != rowKeys[i]) { cancelDrag(ctx); return }
        }
        if (keyboardDrag.value && !ctx.hasFocus(gripIds[dragIndex.value])) { cancelDrag(ctx) }
    }

    private func handleKey(ctx: UiContext, key: Key, repeat: Bool): Bool {
        var focused: Int64 = -1
        for (i in 0..gripIds.size) {
            if (ctx.hasFocus(gripIds[i])) { focused = i; break }
        }
        if (focused < 0) { return false }
        match (key) {
            case Key.Escape =>
                if (dragIndex.value >= 0) { cancelDrag(ctx); return true }
            case Key.Space | Key.Enter =>
                if (repeat) { return true }
                if (dragIndex.value < 0) { beginDrag(ctx, focused, true) }
                else if (keyboardDrag.value) { commitDrag(ctx) }
                return true
            case Key.Up | Key.Left | Key.Down | Key.Right | Key.Home | Key.End =>
                if (dragIndex.value >= 0 && !keyboardDrag.value) { return false }
                let current = if (keyboardDrag.value) { dropTarget() } else { focused }
                let next = match (key) {
                    case Key.Up | Key.Left => max(0, current - 1)
                    case Key.Down | Key.Right => min(count - 1, current + 1)
                    case Key.Home => 0
                    case _ => count - 1
                }
                if (keyboardDrag.value) { keyboardTarget.value = next }
                else { ctx.focus(gripIds[next], viaKeyboard: true) }
                return true
            case _ => ()
        }
        false
    }

    // The row whose handle contains (x, y), or -1. The handle is the left strip of each row's slot.
    private func handleRowAt(x: Float32, y: Float32): Int64 {
        if (x < frame.x || x > min(frame.right(), frame.x + REORDER_HANDLE_W)) {
            return -1
        }
        if (y < frame.y || count <= 0) {
            return -1
        }
        let index = Int64((y - frame.y) / stride())
        if (index < 0 || index >= count) {
            return -1
        }
        // Reject the spacing gap between rows.
        if (y - slotTop(index) > rowHeight) {
            return -1
        }
        index
    }

    private func drawRow(ctx: UiContext, i: Int64, top: Float32, lifted: Bool): Unit {
        let target = dropTarget()
        let rowRect = Rect(frame.x, top, frame.w, rowHeight)
        if (lifted) {
            // A raised surface with a shadow so the dragged row reads as picked up.
            drawSurface(ctx, rowRect, SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.accent,
                radius: ctx.theme.controlRadius, borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 5.0))
        }
        let grip = Rect(frame.x, top, max(0.0, min(frame.w, REORDER_HANDLE_W)), rowHeight)
        let active = lifted && keyboardDrag.value
        let canActivate = dragIndex.value < 0 || active
        let shownPosition = if (lifted) {target} else if (dragIndex.value >= 0) {
            previewPosition(i, dragIndex.value, target)
        } else {i}
        let actions = ArrayList<SemanticActionKind>()
        actions.add(SemanticActionKind.Focus)
        if (canActivate) { actions.add(SemanticActionKind.Activate) }
        if (active) {
            if (target > 0) { actions.add(SemanticActionKind.Decrement) }
            if (target < count - 1) { actions.add(SemanticActionKind.Increment) }
            actions.add(SemanticActionKind.Dismiss)
        }
        recordControlSemantics(ctx, grip, "ReorderHandle", ControlSemantics(
            "button", label: rowLabel(i), value: "${shownPosition + 1}/${count}",
            selected: Some(lifted), focused: Some(ctx.hasFocus(gripIds[i])),
            action: if (canActivate) {"ReorderableList.grabOrCommit()"} else {""},
            shortcut: if (canActivate) {"Enter|Space; Up|Down; Escape"} else {""},
            actionOwner: gripIds[i], typedActions: actions.toArray()))
        drawHandle(ctx, grip, lifted)
        if (ctx.interactionsEnabled() && ctx.showFocusRing(gripIds[i])) {
            drawFocusRing(ctx, grip, ctx.theme.smallRadius)
        }
        // The slot clip is widened by the shadow clearance so a card row's soft halo wraps its
        // rounded corners instead of being sliced off at the slot boundary; row content itself is
        // slot-sized, so only the halo occupies the margin.
        ctx.renderer.pushClip(rowRect.inset(-CUI_SHADOW_CLEARANCE))
        rows[i].draw(ctx)
        ctx.renderer.popClip()
    }

    // Two columns of grip dots marking the draggable handle.
    private func drawHandle(ctx: UiContext, box: Rect, active: Bool): Unit {
        let color = if (active) {
            ctx.theme.accent
        } else {
            ctx.theme.mutedText
        }
        let cx = box.x + box.w / 2.0
        let cy = box.centerY()
        var row = -1
        while (row <= 1) {
            let dy = Float32(row) * 5.0
            ctx.renderer.fillCircle(cx - 3.0, cy + dy, 1.3, color)
            ctx.renderer.fillCircle(cx + 3.0, cy + dy, 1.3, color)
            row += 1
        }
    }
}
