package chui.core

import sdl.{Rect, Size, UiEvent, MouseButton}
import std.collection.ArrayList
import std.math.abs

// Effectively-infinite extent offered to a child during measure; shared by the scrolling and
// collapsible containers (Accordion, in chui.controls) that size a child to its natural content.
protected let LAYOUT_UNBOUNDED: Float32 = 999936.0

/** Layers children back-to-front and aligns each child inside the same frame. */
public class ZStack <: Widget {
    private let children: Array<Widget>
    private var contentAlignment = Alignment.Center

    public init(body!: () -> Unit) {
        children = buildChildren(body)
        emit(this)
    }

    /** Sets how non-stretching children are positioned in the overlay. */
    public func alignment(value: Alignment): ZStack {
        contentAlignment = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        var width: Float32 = 0.0
        var height: Float32 = 0.0
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let size = child.measure(ctx, available)
            width = max(width, size.w)
            height = max(height, size.h)
        }
        Size(min(width, available.w), min(height, available.h))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let measured = child.measure(ctx, Size(rect.w, rect.h))
            let width = if (child.acceptsStretch(Axis.Horizontal)) {
                rect.w
            } else {
                min(rect.w, measured.w)
            }
            let height = if (child.acceptsStretch(Axis.Vertical)) {
                rect.h
            } else {
                min(rect.h, measured.h)
            }
            child.layout(ctx, alignedRect(rect, width, height, contentAlignment))
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (index in stackingOrder(children)) {
            children[index].draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) | UiEvent.PointerCancelled =>
                for (child in children) {
                    let _ = child.handle(ctx, event)
                }
                return false
            case _ => ()
        }
        let ordered = stackingOrder(children)
        var i = ordered.size - 1
        while (i >= 0) {
            if (children[ordered[i]].handle(ctx, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    public func interactionOwnerIds(): Array<String> {
        collectInteractionOwnerIds(children)
    }
}

/** Stable low-to-high sibling order for one stacking context. */
private func stackingOrder(children: Array<Widget>): Array<Int64> {
    let ordered = Array<Int64>(children.size, {index => index})
    var i: Int64 = 0
    while (i < ordered.size) {
        var j = i + 1
        while (j < ordered.size) {
            if (children[ordered[j]].stackingIndex() < children[ordered[i]].stackingIndex()) {
                let current = ordered[i]
                ordered[i] = ordered[j]
                ordered[j] = current
            }
            j += 1
        }
        i += 1
    }
    ordered
}

/**
 * Arranges children in a fixed number of equal-width columns and content-sized rows.
 * Throws `IllegalArgumentException` when `columns` is not positive.
 */
public class Grid <: Widget {
    private let columns: Int64
    private let children: Array<Widget>
    private var horizontalGap: Length = vpLength(CUI_GAP)
    private var verticalGap: Length = vpLength(CUI_GAP)

    /** Creates a grid. Throws `IllegalArgumentException` when `columns` is not positive. */
    public init(columns: Int64, body!: () -> Unit) {
        if (columns <= 0) {
            throw IllegalArgumentException("Grid columns must be greater than zero")
        }
        this.columns = columns
        this.children = buildChildren(body)
        emit(this)
    }

    /** Sets equal horizontal and vertical gaps, e.g. `.spacing(12.vp)`. */
    public func spacing(value: Length): Grid {
        horizontalGap = value
        verticalGap = value
        this
    }

    /** Sets equal horizontal and vertical gaps in virtual pixels. */
    public func spacing(value: Float32): Grid {
        spacing(vpLength(value))
    }

    /** Sets independent horizontal and vertical gaps. */
    public func spacing(horizontal: Length, vertical: Length): Grid {
        horizontalGap = horizontal
        verticalGap = vertical
        this
    }

    /** Sets independent horizontal and vertical gaps in virtual pixels. */
    public func spacing(horizontal: Float32, vertical: Float32): Grid {
        spacing(vpLength(horizontal), vpLength(vertical))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let heights = rowHeights(ctx, available.w, available.h)
        Size(available.w, min(available.h, sum(heights) + gapExtent(heights.size, gapV(ctx))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let hGap = gapH(ctx)
        let cellWidth = gridCellWidth(rect.w, hGap)
        let heights = rowHeights(ctx, rect.w, rect.h)
        var y = rect.y
        var childIndex: Int64 = 0
        var row: Int64 = 0
        while (row < heights.size) {
            var column: Int64 = 0
            while (column < columns && childIndex < children.size) {
                if (!children[childIndex].participatesInLayout()) {
                    childIndex += 1
                    continue
                }
                let x = rect.x + Float32(column) * (cellWidth + hGap)
                let child = children[childIndex]
                let measured = child.measure(ctx, Size(cellWidth, heights[row]))
                let width = if (child.acceptsStretch(Axis.Horizontal)) {
                    cellWidth
                } else {
                    measured.w
                }
                let height = if (child.acceptsStretch(Axis.Vertical)) {
                    heights[row]
                } else {
                    measured.h
                }
                child.layout(ctx, Rect(x, y, min(cellWidth, width), min(heights[row], height)))
                column += 1
                childIndex += 1
            }
            y += heights[row] + gapV(ctx)
            row += 1
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        dispatchChildren(children, ctx, event)
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    public func interactionOwnerIds(): Array<String> {
        collectInteractionOwnerIds(children)
    }

    private func gapH(ctx: UiContext): Float32 {
        max(0.0, ctx.resolve(horizontalGap))
    }

    private func gapV(ctx: UiContext): Float32 {
        max(0.0, ctx.resolve(verticalGap))
    }

    private func rowHeights(ctx: UiContext, width: Float32, height: Float32): Array<Float32> {
        let count = participatingCount(children)
        let rows = (count + columns - 1) / columns
        let heights = Array<Float32>(rows, {_ => Float32(0.0)})
        let cellWidth = gridCellWidth(width, gapH(ctx))
        var i: Int64 = 0
        var activeIndex: Int64 = 0
        while (i < children.size) {
            if (!children[i].participatesInLayout()) {
                i += 1
                continue
            }
            let row = activeIndex / columns
            heights[row] = max(heights[row], children[i].measure(ctx, Size(cellWidth, height)).h)
            i += 1
            activeIndex += 1
        }
        heights
    }

    private func gridCellWidth(width: Float32, hGap: Float32): Float32 {
        max(0.0, width - gapExtent(columns, hGap)) / Float32(columns)
    }
}

/** Places children left-to-right and wraps them onto content-sized rows. */
public class FlowRow <: Widget {
    private let children: Array<Widget>
    private var horizontalGap: Length = vpLength(CUI_GAP)
    private var verticalGap: Length = vpLength(CUI_GAP)

    public init(body!: () -> Unit) {
        children = buildChildren(body)
        emit(this)
    }

    /** Sets equal horizontal and vertical gaps, e.g. `.spacing(10.vp)`. */
    public func spacing(value: Length): FlowRow {
        horizontalGap = value
        verticalGap = value
        this
    }

    /** Sets equal horizontal and vertical gaps in virtual pixels. */
    public func spacing(value: Float32): FlowRow {
        spacing(vpLength(value))
    }

    /** Sets independent horizontal and vertical gaps. */
    public func spacing(horizontal: Length, vertical: Length): FlowRow {
        horizontalGap = horizontal
        verticalGap = vertical
        this
    }

    /** Sets independent horizontal and vertical gaps in virtual pixels. */
    public func spacing(horizontal: Float32, vertical: Float32): FlowRow {
        spacing(vpLength(horizontal), vpLength(vertical))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let extent = flowExtent(ctx, available, false, Rect.zero())
        Size(min(available.w, extent.w), min(available.h, extent.h))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let _ = flowExtent(ctx, Size(rect.w, rect.h), true, rect)
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        dispatchChildren(children, ctx, event)
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    public func interactionOwnerIds(): Array<String> {
        collectInteractionOwnerIds(children)
    }

    private func flowExtent(ctx: UiContext, available: Size, shouldLayout: Bool, frame: Rect): Size {
        let hGap = max(0.0, ctx.resolve(horizontalGap))
        let vGap = max(0.0, ctx.resolve(verticalGap))
        var x: Float32 = 0.0
        var y: Float32 = 0.0
        var rowHeight: Float32 = 0.0
        var usedWidth: Float32 = 0.0
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let childSize = child.measure(ctx, available)
            if (x > 0.0 && x + childSize.w > available.w) {
                x = 0.0
                y += rowHeight + vGap
                rowHeight = 0.0
            }
            if (shouldLayout) {
                child.layout(ctx, Rect(frame.x + x, frame.y + y, childSize.w, childSize.h))
            }
            usedWidth = max(usedWidth, x + childSize.w)
            x += childSize.w + hGap
            rowHeight = max(rowHeight, childSize.h)
        }
        Size(usedWidth, y + rowHeight)
    }
}

/** A clipped, wheel-scrollable viewport with state retained by its stable `id`. */
public class ScrollView <: Widget {
    private let child: Widget
    private var scrollOffset: State<Float32>
    private let scrollBar: ScrollBar
    private let scrollMotion: ScrollMotion
    private var scrollPolicy = ScrollOptions.web()
    private let preserveDynamicAnchor: State<Bool>
    private let previousRawHeight: State<Float32>
    private let retainedTailPadding: State<Float32>
    private var frame = Rect.zero()
    private var contentHeight: Float32 = 0.0
    private var rawContentHeight: Float32 = 0.0
    private var requestedWidth: Float32 = 0.0
    private var horizontalOffset: State<Float32>
    private let horizontalMotion: ScrollMotion
    private let horizontalBar: HScrollBar
    private var viewport = Rect.zero()
    private var contentWidth: Float32 = 0.0
    private let pan: ScrollPan
    private let panId: String
    private var contentDrag = false

    public init(key!: ?String = None, body!: () -> Unit) {
        let ident = resolveControlKey(key, "ScrollView")
        child = buildChild(body)
        let initialScroll = localState<Float32>("ScrollView:${ident}:offset") {0.0}
        scrollOffset = initialScroll
        scrollBar = ScrollBar("ScrollView:${ident}:thumb")
        scrollMotion = localState<ScrollMotion>("ScrollView:${ident}:motion") {
            ScrollMotion(initialScroll.value)
        }.value
        preserveDynamicAnchor = localState<Bool>("ScrollView:${ident}:preserve-anchor") {false}
        horizontalOffset = localState<Float32>("ScrollView:${ident}:x") {0.0}
        horizontalMotion = localState<ScrollMotion>("ScrollView:${ident}:x-motion") { ScrollMotion(0.0) }.value
        horizontalBar = HScrollBar("ScrollView:${ident}:x-thumb")
        panId = "ScrollView:${ident}:pan"
        pan = localState<ScrollPan>(panId) { ScrollPan() }.value
        previousRawHeight = localState<Float32>("ScrollView:${ident}:previous-raw-height") {0.0}
        retainedTailPadding = localState<Float32>("ScrollView:${ident}:retained-tail-padding") {0.0}
        emit(this)
    }

    /** Uses an externally owned vertical scroll offset. */
    public func scrollState(value: State<Float32>): ScrollView {
        scrollOffset = value
        this
    }

    /** Opt into a finite horizontal canvas; vertical overflow remains automatic. */
    public func horizontalContent(width: Float32): ScrollView {
        if (!(width > 0.0 && width <= Float32.Max)) {
            throw IllegalArgumentException("horizontal scroll content width must be finite and positive")
        }
        requestedWidth = width
        this
    }

    /** App-owned horizontal offset; scrollState continues to own the vertical offset. */
    public func horizontalScrollState(value: State<Float32>): ScrollView {
        horizontalOffset = value
        this
    }

    /** Opt-in content panning; off by default to preserve text selection and control drags. */
    public func dragToScroll(enabled!: Bool = true): ScrollView {
        contentDrag = enabled
        this
    }

    /** Selects smooth/immediate wheel motion, wheel step, duration and easing. */
    public func scrollOptions(value: ScrollOptions): ScrollView {
        scrollPolicy = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // Each admitted scrollbar reserves its own gutter. Re-measure after admission
        // because either gutter can introduce overflow on the other axis.
        let gutter = scrollBarGutter(inset: scrollPolicy.contentInset)
        var vertical = false
        var horizontal = false
        var measured = Size(0.0, 0.0)
        // Monotonic gutter admission: either scrollbar can introduce overflow on the other axis.
        for (_ in 0..3) {
            let gutterX = if (vertical) {gutter} else {Float32(0.0)}
            let gutterY = if (horizontal) {gutter} else {Float32(0.0)}
            viewport = Rect(rect.x, rect.y, max(0.0, rect.w - gutterX), max(0.0, rect.h - gutterY))
            contentWidth = max(viewport.w, requestedWidth)
            measured = child.measure(ctx, Size(contentWidth, LAYOUT_UNBOUNDED))
            let nextVertical = vertical || measured.h + retainedTailPadding.value > viewport.h
            let nextHorizontal = horizontal || contentWidth > viewport.w
            if (nextVertical == vertical && nextHorizontal == horizontal) { break }
            vertical = nextVertical
            horizontal = nextHorizontal
        }
        rawContentHeight = measured.h
        if (preserveDynamicAnchor.value && previousRawHeight.value > 0.0) {
            let delta = rawContentHeight - previousRawHeight.value
            if (delta < 0.0) {
                retainedTailPadding.value += -delta
            } else if (delta > 0.0 && retainedTailPadding.value > 0.0) {
                retainedTailPadding.value = max(0.0, retainedTailPadding.value - delta)
            }
        } else if (!preserveDynamicAnchor.value && retainedTailPadding.value != 0.0) {
            retainedTailPadding.value = 0.0
        }
        // Layout is allowed to run repeatedly without invalidating the next frame. `State`
        // deliberately treats an equal assignment as a write, so guard this retained metric.
        if (previousRawHeight.value != rawContentHeight) {
            previousRawHeight.value = rawContentHeight
        }
        contentHeight = rawContentHeight + retainedTailPadding.value
        advanceScrollMotion(ctx, scrollMotion, scrollOffset, contentHeight, viewport.h, scrollPolicy)
        advanceScrollMotion(ctx, horizontalMotion, horizontalOffset, contentWidth, viewport.w, scrollPolicy)
        // Clamp writes only on change: layout runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clamped = clampScrollOffset(scrollOffset.value, contentHeight, viewport.h)
        if (clamped != scrollOffset.value) {
            scrollOffset.value = clamped
        }
        child.layout(ctx, Rect(rect.x - horizontalOffset.value, rect.y - scrollOffset.value, contentWidth, contentHeight))
    }

    public func draw(ctx: UiContext): Unit {
        // Clip exactly on the scroll axis, but give the cross axis shadow clearance: a card at the
        // viewport edge keeps its rounded soft halo instead of having it sliced off vertically.
        if (requestedWidth > 0.0) { ctx.renderer.pushClip(viewport) }
        else { ctx.renderer.pushClip(Rect(frame.x - CUI_SHADOW_CLEARANCE, frame.y,
            frame.w + 2.0 * CUI_SHADOW_CLEARANCE, viewport.h)) }
        child.draw(ctx)
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, verticalBarFrame(), scrollOffset.value, contentHeight, viewport.h,
            active: scrollBar.dragging(ctx))
        drawHorizontalScrollBar(ctx, horizontalBarFrame(), horizontalOffset.value, contentWidth, viewport.w,
            active: horizontalBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // A request is event-local to a descendant of this view. Discard any stale request left by
        // a control outside this subtree before offering the current event to our child.
        let _ = ctx.takeScrollAnchorRequest()
        match (event) {
            case UiEvent.PointerCancelled | UiEvent.WindowFocusChanged(false) =>
                pan.cancel(ctx, panId)
                let _ = child.handle(ctx, event)
                return false
            case _ => ()
        }
        if (contentDrag) {
            match (handleContentPan(ctx, event)) { case Some(result) => return result case None => () }
        } else if (pan.pending) { pan.cancel(ctx, panId) }
        match (event) {
            case UiEvent.MouseWheel(wheelX, wheelY, pointerX, pointerY) =>
                if (!viewport.contains(pointerX, pointerY)) { return false }
                if (child.handle(ctx, event)) { return true }
                if (abs(wheelX) > abs(wheelY)) {
                    if (!horizontalMotion.canWheel(horizontalOffset.value, wheelX, contentWidth, viewport.w)) {
                        return false
                    }
                    applyWheelScroll(ctx, horizontalMotion, horizontalOffset, wheelX, contentWidth, viewport.w, scrollPolicy)
                    return true
                }
                if (scrollMotion.canWheel(scrollOffset.value, wheelY, contentHeight, viewport.h)) {
                    releaseDynamicAnchor()
                    applyWheelScroll(ctx, scrollMotion, scrollOffset, wheelY, contentHeight, viewport.h, scrollPolicy)
                    return true
                }
                return false
            case UiEvent.MouseDown(_, x, y) =>
                if (horizontalBar.press(ctx, horizontalBarFrame(), horizontalOffset, contentWidth, viewport.w, x, y)) {
                    pan.cancel(ctx, panId)
                    cancelScrollMotion(horizontalMotion, horizontalOffset)
                    return true
                }
                if (scrollBarTrackRect(verticalBarFrame()).contains(x, y)) {
                    releaseDynamicAnchor()
                }
                if (scrollBar.press(ctx, verticalBarFrame(), scrollOffset, contentHeight, viewport.h, x, y)) {
                    pan.cancel(ctx, panId)
                    cancelScrollMotion(scrollMotion, scrollOffset)
                    return true
                }
                if (!frame.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (horizontalBar.drag(ctx, horizontalBarFrame(), horizontalOffset, contentWidth, viewport.w, x)) {
                    cancelScrollMotion(horizontalMotion, horizontalOffset)
                    return true
                }
                if (scrollBar.drag(ctx, verticalBarFrame(), scrollOffset, contentHeight, viewport.h, y)) {
                    cancelScrollMotion(scrollMotion, scrollOffset)
                    return true
                }
                // While a child drag is live (a slider knob, a text selection), track the
                // pointer past the viewport edge to the release — pointer capture — instead
                // of freezing the gesture at the boundary.
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
        let handled = child.handle(ctx, event)
        if (ctx.takeScrollAnchorRequest() && !preserveDynamicAnchor.value) {
            preserveDynamicAnchor.value = true
        }
        handled
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    public func interactionOwnerIds(): Array<String> {
        let ids = ArrayList<String>()
        ids.add(panId)
        for (id in child.interactionOwnerIds()) { ids.add(id) }
        ids.toArray()
    }

    private func verticalBarFrame(): Rect { Rect(frame.x, frame.y, frame.w, viewport.h) }
    private func horizontalBarFrame(): Rect { Rect(frame.x, frame.y, viewport.w, frame.h) }

    private func handleContentPan(ctx: UiContext, event: UiEvent): ?Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                pan.cancel(ctx, panId)
                if (viewport.contains(x, y)) { pan.begin(x, y, horizontalOffset.value, scrollOffset.value) }
            case UiEvent.MouseMove(x, y) =>
                if (!pan.pending) { return None }
                if (pan.axis == 0) {
                    let childHandled = child.handle(ctx, event)
                    if (childHandled || !ctx.pointerCaptureOwner().isEmpty() || !ctx.dragId.isEmpty()) {
                        pan.cancel(ctx, panId)
                        return Some(childHandled)
                    }
                    let dx = x - pan.x
                    let dy = y - pan.y
                    if (dx * dx + dy * dy < 64.0) { return Some(false) }
                    let horizontal = abs(dx) > abs(dy)
                    let admitted = if (horizontal) {
                        horizontalMotion.canWheel(horizontalOffset.value, dx, contentWidth, viewport.w)
                    } else { scrollMotion.canWheel(scrollOffset.value, dy, contentHeight, viewport.h) }
                    if (!admitted) { pan.cancel(ctx, panId); return Some(false) }
                    let _ = child.handle(ctx, UiEvent.PointerCancelled)
                    ctx.clearPress()
                    releaseDynamicAnchor()
                    pan.axis = if (horizontal) {1} else {2}
                    ctx.beginDrag(panId)
                    ctx.capturePointer(panId)
                }
                if (!ctx.hasPointerCapture(panId)) { pan.cancel(ctx, panId); return Some(false) }
                if (pan.axis == 1) {
                    let next = clampScrollOffset(pan.offsetX - (x - pan.x), contentWidth, viewport.w)
                    if (horizontalOffset.value != next) { horizontalOffset.value = next }
                    cancelScrollMotion(horizontalMotion, horizontalOffset)
                } else {
                    let next = clampScrollOffset(pan.offsetY - (y - pan.y), contentHeight, viewport.h)
                    if (scrollOffset.value != next) { scrollOffset.value = next }
                    cancelScrollMotion(scrollMotion, scrollOffset)
                }
                return Some(true)
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                let consumed = pan.axis != 0 && ctx.hasPointerCapture(panId)
                pan.cancel(ctx, panId)
                if (consumed) { return Some(true) }
            case _ => ()
        }
        None
    }

    private func releaseDynamicAnchor(): Unit {
        if (!preserveDynamicAnchor.value && retainedTailPadding.value == 0.0) { return }
        if (preserveDynamicAnchor.value) { preserveDynamicAnchor.value = false }
        if (retainedTailPadding.value != 0.0) { retainedTailPadding.value = 0.0 }
        contentHeight = rawContentHeight
        let clamped = clampScrollOffset(scrollOffset.value, contentHeight, viewport.h)
        if (scrollOffset.value != clamped) { scrollOffset.value = clamped }
        cancelScrollMotion(scrollMotion, scrollOffset)
    }
}

private func alignedRect(bounds: Rect, width: Float32, height: Float32, alignment: Alignment): Rect {
    let x = match (alignment) {
        case Alignment.Top => bounds.x + (bounds.w - width) / 2.0
        case Alignment.Center => bounds.x + (bounds.w - width) / 2.0
        case Alignment.Bottom => bounds.x + (bounds.w - width) / 2.0
        case Alignment.TopTrailing => bounds.right() - width
        case Alignment.Trailing => bounds.right() - width
        case Alignment.BottomTrailing => bounds.right() - width
        case _ => bounds.x
    }
    let y = match (alignment) {
        case Alignment.Leading => bounds.y + (bounds.h - height) / 2.0
        case Alignment.Center => bounds.y + (bounds.h - height) / 2.0
        case Alignment.Trailing => bounds.y + (bounds.h - height) / 2.0
        case Alignment.BottomLeading => bounds.bottom() - height
        case Alignment.Bottom => bounds.bottom() - height
        case Alignment.BottomTrailing => bounds.bottom() - height
        case _ => bounds.y
    }
    Rect(x, y, width, height)
}

internal func dispatchChildren(children: Array<Widget>, ctx: UiContext, event: UiEvent): Bool {
    match (event) {
        case UiEvent.Frame(_) | UiEvent.PointerCancelled =>
            for (child in children) {
                let _ = child.handle(ctx, event)
            }
            return false
        case _ => ()
    }
    match (event) {
        case UiEvent.MouseMove(_, _) | UiEvent.MouseUp(_, _, _) =>
            let owner = ctx.pointerCaptureOwner()
            if (!owner.isEmpty()) {
                var capturedIndex = children.size - 1
                while (capturedIndex >= 0) {
                    if (children[capturedIndex].interactionOwnerIds().contains(owner)) {
                        return children[capturedIndex].handle(ctx, event)
                    }
                    capturedIndex -= 1
                }
            }
        case _ => ()
    }
    var i = children.size - 1
    while (i >= 0) {
        if (children[i].handle(ctx, event)) {
            return true
        }
        i -= 1
    }
    false
}

private func gapExtent(count: Int64, gap: Float32): Float32 {
    if (count <= 1) {
        0.0
    } else {
        Float32(count - 1) * gap
    }
}

private func sum(values: Array<Float32>): Float32 {
    var total: Float32 = 0.0
    for (value in values) {
        total += value
    }
    total
}

private func participatingCount(children: Array<Widget>): Int64 {
    var count: Int64 = 0
    for (child in children) {
        if (child.participatesInLayout()) {
            count += 1
        }
    }
    count
}
