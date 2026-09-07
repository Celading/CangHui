package chui.text

import chui.core.{GraphemeIndex, NativeTextIndex}

// One UI-owner entry per retained control. No global document cache or listener;
// normal StateStore disposal releases the previous text and index together.
class TextBoundaryCache {
    private var content = ""
    private var boundaries = GraphemeIndex("")
    private var builds: UInt64 = 0
    private var nativeContent = ""
    private var native: ?NativeTextIndex = None
    private var nativeBuilds: UInt64 = 0
    private var affinityOffset: Int64 = -1
    private var secondary = false

    func index(value: String): GraphemeIndex {
        if (value != content) {
            boundaries = GraphemeIndex(value)
            content = value
            builds += UInt64(1)
        }
        boundaries
    }

    func rebuildCount(): UInt64 { builds }

    // Native mapping is lazy and belongs to this control, never a process-global document cache.
    func nativeIndex(value: String): NativeTextIndex {
        if (value == nativeContent) {
            if (let Some(cached) <- native) { return cached }
        }
        let created = NativeTextIndex(value)
        nativeContent = value
        native = Some(created)
        nativeBuilds += UInt64(1)
        clearAffinity()
        created
    }

    func nativeRebuildCount(): UInt64 { nativeBuilds }
    func rememberAffinity(offset: Int64, useSecondary: Bool): Unit {
        affinityOffset = offset; secondary = useSecondary
    }
    func usesSecondary(offset: Int64): Bool { affinityOffset == offset && secondary }
    func clearAffinity(): Unit { affinityOffset = -1; secondary = false }
}
