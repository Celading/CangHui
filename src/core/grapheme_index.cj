package chui.core

import std.collection.ArrayList

/** Immutable Unicode15.1 extended-grapheme index; all exposed positions are UTF-8 bytes. */
protected class GraphemeIndex {
    private let offsets: Array<Int64>

    public init(text: String) {
        let out = ArrayList<Int64>()
        out.add(0)
        let machine = GraphemeBreakMachine()
        var position: Int64 = 0
        for (rune in text.toRuneArray()) {
            let point = UInt32(rune)
            if (machine.breakBefore(point)) { out.add(position) }
            position += if (point <= UInt32(0x7F)) { 1 } else if (point <= UInt32(0x7FF)) { 2 }
                else if (point <= UInt32(0xFFFF)) { 3 } else { 4 }
        }
        if (position > 0) { out.add(position) }
        this.offsets = out.toArray()
    }

    public prop count: Int64 { get() { offsets.size - 1 } }

    public func boundary(ordinal: Int64): Int64 { offsets[max(0, min(count, ordinal))] }

    public func ordinalFloor(position: Int64): Int64 {
        var low: Int64 = 0
        var high = count
        while (low < high) {
            let mid = low + (high - low + 1) / 2
            if (offsets[mid] <= position) { low = mid } else { high = mid - 1 }
        }
        low
    }

    public func floor(position: Int64): Int64 { boundary(ordinalFloor(position)) }
    public func previous(position: Int64): Int64 { boundary(ordinalFloor(position) - 1) }
    public func next(position: Int64): Int64 { boundary(ordinalFloor(position) + 1) }
    public func ceil(position: Int64): Int64 {
        let ordinal = ordinalFloor(position)
        if (boundary(ordinal) < position) { boundary(ordinal + 1) } else { boundary(ordinal) }
    }
}

// UAX29 revision43 GB3–GB999. State describes the suffix *before* the next code point.
// Actual GCB/InCB/Extended_Pictographic properties are generated, not general-category guesses.
private class GraphemeBreakMachine {
    private var previous: Int64 = -1
    private var regionalRun: Int64 = 0
    private var pictographicExtend = false
    private var pictographicZwj = false
    private var indic: Int64 = 0 // 0 none;1 consonant+extend*;2 contains a linker

    func breakBefore(point: UInt32): Bool {
        let current = graphemeGcb(point)
        let incb = graphemeIncb(point)
        let pictographic = graphemePictographic(point)
        let split = if (previous < 0) { false }
            else if (previous == 1 && current == 2) { false } // CR × LF
            else if (control(previous) || control(current)) { true }
            else if (previous == 9 && (current == 9 || current == 10 || current == 12 || current == 13)) { false }
            else if ((previous == 12 || previous == 10) && (current == 10 || current == 11)) { false }
            else if ((previous == 13 || previous == 11) && current == 11) { false }
            else if (current == 4 || current == 5 || current == 8 || previous == 7) { false }
            else if (indic == 2 && incb == 1) { false }
            else if (pictographicZwj && pictographic) { false }
            else if (previous == 6 && current == 6 && regionalRun % 2 == 1) { false }
            else { true }
        regionalRun = if (current == 6) { if (previous == 6) { regionalRun + 1 } else { 1 } } else { 0 }
        pictographicZwj = current == 5 && pictographicExtend
        pictographicExtend = pictographic || (current == 4 && pictographicExtend)
        indic = if (incb == 1) { 1 } else if (indic > 0 && incb == 2) { 2 }
            else if (incb == 3) { indic } else { 0 }
        previous = current
        split
    }

    private func control(value: Int64): Bool { value == 1 || value == 2 || value == 3 }
}
