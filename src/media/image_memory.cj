package chui.media

import std.runtime.{getMaxHeapSize, getAllocatedHeapSize}
import sdl.{ImageMemoryStats, imageMemoryStats}

/** Separate managed-heap facts from cache estimates; neither field measures total RSS or GPU residency. */
public struct FramePoolMemorySnapshot {
    public let managedHeapLimitBytes: Int64
    public let managedAllocatedBytes: Int64
    public let images: ImageMemoryStats

    public init() {
        managedHeapLimitBytes = getMaxHeapSize()
        managedAllocatedBytes = getAllocatedHeapSize()
        images = imageMemoryStats()
    }
}
