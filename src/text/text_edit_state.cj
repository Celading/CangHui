package chui.text

import chui.core.{Bindable, GraphemeIndex, State}

/**
 * Shared text-editing model for cursor-aware text fields and text areas.
 */
public class TextEditState {
    public let text: Bindable<String>
    public let cursor: State<Int64>
    // The selection is the span between `anchor` and `cursor`. When they coincide there is
    // no selection and editing behaves exactly as a plain caret — this keeps controls that
    // never pass an anchor (a read-only text area) on their original code path.
    public let anchor: State<Int64>
    private var boundaryCache = TextBoundaryCache()
    private var indexedRevision: ?UInt64 = None
    private var graphemes = GraphemeIndex("")

    private func boundaryIndex(): GraphemeIndex {
        let value = text.value
        let revision = text.revision
        match (indexedRevision) {
            case Some(previous) => if (previous == revision) { return graphemes }
            case None => ()
        }
        graphemes = boundaryCache.index(value)
        indexedRevision = Some(revision)
        graphemes
    }

    // Controls retain only this one-entry cache, not a stale binding captured by
    // a prior Widget instance. Each wrapper still owns the current caller's states.
    init(text: Bindable<String>, caret: State<Int64>, selection: State<Int64>, cache: TextBoundaryCache) {
        this.text = text
        this.cursor = caret
        this.anchor = selection
        this.boundaryCache = cache
        normalizeCursor()
    }

    public init(text: Bindable<String>, cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None) {
        this.text = text
        this.cursor = match (cursor) {
            case Some(value) => value
            case None => State<Int64>(text.value.size)
        }
        this.anchor = match (anchor) {
            case Some(value) => value
            case None => State<Int64>(this.cursor.value)
        }
        normalizeCursor()
    }

    public init(value: String) {
        this.text = State<String>(value)
        this.cursor = State<Int64>(value.size)
        this.anchor = State<Int64>(value.size)
    }

    public func normalizeCursor(): Unit {
        // Runs every frame (draw calls it): skip the write when already normalized so callers
        // that own and observe the cursor/anchor are not notified — and revisions not bumped —
        // for a no-op. Behaviour is unchanged; only redundant notifications are avoided.
        let _ = cursor.setIfChanged(boundaryIndex().floor(cursor.value))
        let _ = anchor.setIfChanged(boundaryIndex().floor(anchor.value))
    }

    /** Whether a non-empty range is selected. */
    public func hasSelection(): Bool {
        boundaryIndex().floor(anchor.value) != boundaryIndex().floor(cursor.value)
    }

    /** The lower byte offset of the selection (or the caret when nothing is selected). */
    public func selectionStart(): Int64 {
        min(boundaryIndex().floor(anchor.value), boundaryIndex().floor(cursor.value))
    }

    /** The upper byte offset of the selection (or the caret when nothing is selected). */
    public func selectionEnd(): Int64 {
        max(boundaryIndex().floor(anchor.value), boundaryIndex().floor(cursor.value))
    }

    /** The selected substring, empty when nothing is selected. */
    public func selectedText(): String {
        text.value[selectionStart()..selectionEnd()]
    }

    /** Selects the whole value, leaving the caret at the end. */
    public func selectAll(): Unit {
        anchor.value = 0
        cursor.value = text.value.size
    }

    /** Selects the run of same-class characters around `position` (a double-click). */
    public func selectWordAt(position: Int64): Unit {
        let content = text.value
        if (content.size == 0) {
            anchor.value = 0
            cursor.value = 0
            return
        }
        let boundaries = boundaryIndex()
        var probe = boundaries.floor(position)
        if (probe >= content.size) {
            probe = boundaries.previous(content.size)
        }
        let cls = charClassAt(content, probe)
        var start = probe
        while (start > 0) {
            let previous = boundaries.previous(start)
            if (charClassAt(content, previous) != cls) {
                break
            }
            start = previous
        }
        var end = boundaries.next(probe)
        while (end < content.size) {
            if (charClassAt(content, end) != cls) {
                break
            }
            end = boundaries.next(end)
        }
        anchor.value = start
        cursor.value = end
    }

    /** Selects the line containing `position`, including its trailing newline (a triple-click). */
    public func selectLineAt(position: Int64): Unit {
        let content = text.value
        let boundaries = boundaryIndex()
        let pos = boundaries.floor(position)
        anchor.value = lineStartBeforeOrAt(content, pos)
        let lineEnd = lineEndAfterOrAt(content, pos)
        cursor.value = if (lineEnd < content.size) {
            boundaries.next(lineEnd)
        } else {
            lineEnd
        }
    }

    /** Collapses any selection onto the caret. */
    public func clearSelection(): Unit {
        anchor.value = boundaryIndex().floor(cursor.value)
    }

    /** Removes the selected span if any; returns whether text changed. */
    public func deleteSelection(): Bool {
        let start = selectionStart()
        let end = selectionEnd()
        if (start == end) {
            return false
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = boundaryIndex().floor(start)
        anchor.value = cursor.value
        true
    }

    public func insert(value: String): Unit {
        let _ = deleteSelection()
        let position = boundaryIndex().floor(cursor.value)
        text.value = text.value[0..position] + value + text.value[position..text.value.size]
        cursor.value = boundaryIndex().ceil(position + value.size)
        anchor.value = cursor.value
    }

    public func backspace(): Unit {
        if (deleteSelection()) {
            return
        }
        let end = boundaryIndex().floor(cursor.value)
        let start = boundaryIndex().previous(end)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = boundaryIndex().floor(start)
        anchor.value = cursor.value
    }

    public func deleteForward(): Unit {
        if (deleteSelection()) {
            return
        }
        let start = boundaryIndex().floor(cursor.value)
        let end = boundaryIndex().next(start)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = boundaryIndex().floor(start)
        anchor.value = cursor.value
    }

    // Plain navigation collapses any selection: to its near edge when one exists, otherwise
    // one boundary in the travel direction. The `extend*` variants keep the anchor so a
    // held Shift grows or shrinks the selection.

    public func moveLeft(): Unit {
        if (hasSelection()) {
            cursor.value = selectionStart()
        } else {
            cursor.value = boundaryIndex().previous(cursor.value)
        }
        anchor.value = cursor.value
    }

    public func moveRight(): Unit {
        if (hasSelection()) {
            cursor.value = selectionEnd()
        } else {
            cursor.value = boundaryIndex().next(cursor.value)
        }
        anchor.value = cursor.value
    }

    public func extendLeft(): Unit {
        cursor.value = boundaryIndex().previous(cursor.value)
    }

    public func extendRight(): Unit {
        cursor.value = boundaryIndex().next(cursor.value)
    }

    public func moveToStart(): Unit {
        cursor.value = 0
        anchor.value = 0
    }

    public func moveToEnd(): Unit {
        cursor.value = text.value.size
        anchor.value = cursor.value
    }

    public func extendToStart(): Unit {
        cursor.value = 0
    }

    public func extendToEnd(): Unit {
        cursor.value = text.value.size
    }

    public func moveToLineStart(): Unit {
        extendToLineStart()
        anchor.value = cursor.value
    }

    public func moveToLineEnd(): Unit {
        extendToLineEnd()
        anchor.value = cursor.value
    }

    public func extendToLineStart(): Unit {
        cursor.value = lineStartBeforeOrAt(text.value, cursor.value)
    }

    public func extendToLineEnd(): Unit {
        cursor.value = boundaryIndex().floor(lineEndAfterOrAt(text.value, cursor.value))
    }

    public func moveLineUp(): Unit {
        extendLineUp()
        anchor.value = cursor.value
    }

    public func moveLineDown(): Unit {
        extendLineDown()
        anchor.value = cursor.value
    }

    // Column-preserving vertical motion that keeps the anchor, so Shift+Up / Shift+Down grow
    // the selection. The plain move* variants above delegate here and then collapse.

    public func extendLineUp(): Unit {
        let current = boundaryIndex().floor(cursor.value)
        let currentStart = lineStartBeforeOrAt(text.value, current)
        if (currentStart <= 0) {
            cursor.value = 0
            return
        }
        let previousEnd = previousTextBoundary(text.value, currentStart)
        let previousStart = lineStartBeforeOrAt(text.value, previousEnd)
        let column = current - currentStart
        cursor.value = boundaryIndex().floor(advanceTextCursorByBytes(text.value, previousStart, column, previousEnd))
    }

    public func extendLineDown(): Unit {
        let current = boundaryIndex().floor(cursor.value)
        let currentEnd = lineEndAfterOrAt(text.value, current)
        if (currentEnd >= text.value.size) {
            cursor.value = text.value.size
            return
        }
        let nextStart = nextTextBoundary(text.value, currentEnd)
        let nextEnd = lineEndAfterOrAt(text.value, nextStart)
        let column = current - lineStartBeforeOrAt(text.value, current)
        cursor.value = boundaryIndex().floor(advanceTextCursorByBytes(text.value, nextStart, column, nextEnd))
    }

    /** Places the caret at `position`, collapsing any selection (a plain click). */
    public func moveTo(position: Int64): Unit {
        cursor.value = boundaryIndex().floor(position)
        anchor.value = cursor.value
    }

    /** Moves the caret to `position` while keeping the anchor (a drag-select). */
    public func extendTo(position: Int64): Unit {
        cursor.value = boundaryIndex().floor(position)
    }
}
