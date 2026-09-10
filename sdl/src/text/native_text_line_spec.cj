package sdl.text

import std.collection.HashSet

/** Advanced native text interop: a half-open UTF16 color range, later ranges win. */
public struct NativeTextColorSpan {
    public let start: Int64
    public let end: Int64
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(start: Int64, end: Int64, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        this.start = start; this.end = end
        this.red = red; this.green = green; this.blue = blue; this.alpha = alpha
    }
}

/**
 * Immutable source and color ranges for one native line. Ranges use UTF16 scalar
 * boundaries, NOT UTF8 editor offsets. Styling part of a shaped cluster can alter
 * glyphs and advances: use this same spec for drawing AND every geometry query.
 * The default RGBA is part of the spec as well; painting cannot override it.
 */
public class NativeTextLineSpec {
    public let text: String
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8
    internal let utf16Length: Int64
    private let stored: Array<NativeTextColorSpan>
    internal let colorKey: String

    public init(text: String, colors!: Array<NativeTextColorSpan> = [],
        red!: UInt8 = 0, green!: UInt8 = 0, blue!: UInt8 = 0, alpha!: UInt8 = 255) {
        let boundaries = HashSet<Int64>()
        var index: Int64 = 0
        boundaries.add(0)
        for (rune in text.toRuneArray()) {
            index += if (UInt32(rune) > UInt32(0xFFFF)) { 2 } else { 1 }
            boundaries.add(index)
        }
        let copy = Array<NativeTextColorSpan>(colors.size, {i => colors[i]})
        let key = StringBuilder()
        key.append("${red},${green},${blue},${alpha}")
        for (color in copy) {
            if (color.start < 0 || color.end < color.start ||
                !boundaries.contains(color.start) || !boundaries.contains(color.end)) {
                throw IllegalArgumentException("Native text color range must use exact UTF16 scalar boundaries")
            }
            key.append("|${color.start},${color.end},${color.red},${color.green},${color.blue},${color.alpha}")
        }
        this.text = text
        this.red = red; this.green = green; this.blue = blue; this.alpha = alpha
        this.utf16Length = index
        this.stored = copy
        this.colorKey = key.toString()
    }

    public func colors(): Array<NativeTextColorSpan> {
        Array<NativeTextColorSpan>(stored.size, {i => stored[i]})
    }

    internal func layoutColors(): Array<NativeTextColorSpan> { stored }
}
