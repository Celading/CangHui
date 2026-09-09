package sdl.text

import std.collection.ArrayList

// Pango indices are UTF8 bytes; its hit trailing counts Unicode scalars. This
// boundary map does not segment graphemes or replace the editor's GraphemeIndex.
@When[os == "Linux"]
internal class PangoTextOffsets {
    private let bytes: Array<Int64>
    private let units: Array<Int64>
    let utf16Length: Int64

    init(text: String) {
        if (text.size > 1048576 || text.contains("\u{0}")) {
            throw NativeTextException("Pango line exceeds1MiB or contains an embedded NUL")
        }
        let b = ArrayList<Int64>([0]); let u = ArrayList<Int64>([0])
        var byteOffset: Int64 = 0; var unitOffset: Int64 = 0
        for (r in text.runes()) {
            let c = UInt32(r)
            byteOffset += if (c < 0x80) { 1 } else if (c < 0x800) { 2 } else if (c < 0x10000) { 3 } else { 4 }
            unitOffset += if (c > 0xFFFF) { 2 } else { 1 }
            b.add(byteOffset); u.add(unitOffset)
        }
        this.bytes = b.toArray(); this.units = u.toArray(); this.utf16Length = unitOffset
    }

    private func locate(values: Array<Int64>, value: Int64): Int64 {
        var lo: Int64 = 0; var hi = values.size
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            if (values[mid] < value) { lo = mid + 1 } else { hi = mid }
        }
        if (lo >= values.size || values[lo] != value) {
            throw NativeTextException("Pango offset must be an exact scalar boundary")
        }
        lo
    }

    func byteIndex(utf16: Int64): Int32 { Int32(bytes[locate(units, utf16)]) }

    func utf16Index(byteIndex: Int32, trailing: Int32): Int64 {
        let scalar = locate(bytes, Int64(byteIndex))
        if (trailing < 0 || Int64(trailing) >= units.size - scalar) {
            throw NativeTextException("Pango hit trailing scalar count is outside the line")
        }
        units[scalar + Int64(trailing)]
    }
}
