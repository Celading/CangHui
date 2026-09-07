package chui.text

import chui.core.GraphemeIndex

// One UI-owner entry per retained control. No global document cache or listener;
// normal StateStore disposal releases the previous text and index together.
class TextBoundaryCache {
    private var content = ""
    private var boundaries = GraphemeIndex("")
    private var builds: UInt64 = 0

    func index(value: String): GraphemeIndex {
        if (value != content) {
            boundaries = GraphemeIndex(value)
            content = value
            builds += UInt64(1)
        }
        boundaries
    }

    func rebuildCount(): UInt64 { builds }
}
