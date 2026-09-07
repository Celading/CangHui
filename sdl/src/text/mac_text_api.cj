package sdl.text

import std.collection.{ArrayList, HashMap}

@When[os == "macOS"]
internal type MacRef = CPointer<Unit>

@When[os == "macOS"]
foreign {
    func dlopen(path: CString, flags: Int32): CPointer<Unit>
    func dlsym(handle: CPointer<Unit>, name: CString): CPointer<Unit>
    func dlclose(handle: CPointer<Unit>): Int32
}

@When[os == "macOS"]
@C
internal struct MacTextPoint {
    var x: Float64 = 0.0
    var y: Float64 = 0.0
}

@When[os == "macOS"]
@C
internal struct MacTextRange {
    var location: Int64 = 0
    var length: Int64 = 0
}

@When[os == "macOS"]
@C
internal struct MacTextRect {
    var x: Float64 = 0.0
    var y: Float64 = 0.0
    var w: Float64 = 0.0
    var h: Float64 = 0.0
}

// The only dynamically loaded libraries are fixed OS frameworks. This is not a
// public plugin loader; all symbols below have SDK-verified signatures.
@When[os == "macOS"]
internal class MacTextApi {
    private var cf = MacRef()
    private var ct = MacRef()
    private var cg = MacRef()
    private var closed = false
    private let symbols = HashMap<String, MacRef>()

    init() {
        try {
            cf = open("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
            ct = open("/System/Library/Frameworks/CoreText.framework/CoreText")
            cg = open("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        } catch (e: Exception) { close(); throw e }
    }

    private static func open(path: String): MacRef {
        var value = MacRef()
        unsafe {
            try (c = LibC.mallocCString(path).asResource()) { value = dlopen(c.value, 2) }
        }
        require(value, "system framework")
    }

    static func require(value: MacRef, operation: String): MacRef {
        if (value.isNull()) { throw NativeTextException("CoreText ${operation} failed") }
        value
    }

    func symbol(library: Int64, name: String): MacRef {
        if (closed) { throw NativeTextException("CoreText API is closed") }
        let key = "${library}:${name}"
        if (let Some(value) <- symbols.get(key)) { return value }
        let handle = if (library == 0) { cf } else if (library == 1) { ct } else { cg }
        var value = MacRef()
        unsafe {
            try (c = LibC.mallocCString(name).asResource()) { value = dlsym(handle, c.value) }
        }
        require(value, name)
        symbols[key] = value
        value
    }

    func constant(library: Int64, name: String): MacRef {
        unsafe { CPointer<MacRef>(symbol(library, name)).read() }
    }

    func release(value: MacRef): Unit {
        if (value.isNotNull()) { unsafe { CFunc<(MacRef) -> Unit>(symbol(0, "CFRelease"))(value) } }
    }

    func string(text: String): MacRef {
        var value = MacRef()
        unsafe {
            try (c = LibC.mallocCString(text).asResource()) {
                value = CFunc<(MacRef, CString, Int64, UInt32, Bool) -> MacRef>(symbol(0,
                    "CFStringCreateWithBytes"))(MacRef(), c.value, text.size, 0x08000100, false)
            }
        }
        require(value, "UTF8 string")
    }

    func stringValue(value: MacRef): String {
        let buffer = unsafe { LibC.malloc<UInt8>(count: 4096) }
        if (buffer.isNull()) { throw NativeTextException("CoreText string buffer allocation failed") }
        try {
            let ok = unsafe { CFunc<(MacRef, CPointer<UInt8>, Int64, UInt32) -> Bool>(symbol(0,
                "CFStringGetCString"))(value, buffer, 4096, 0x08000100) }
            if (!ok) { throw NativeTextException("CoreText font name exceeds limit") }
            CString(buffer).toString()
        } finally { unsafe { LibC.free(buffer) } }
    }

    func dictionary(): MacRef {
        require(unsafe { CFunc<(MacRef, Int64, MacRef, MacRef) -> MacRef>(symbol(0,
            "CFDictionaryCreateMutable"))(MacRef(), 0, symbol(0, "kCFTypeDictionaryKeyCallBacks"),
                symbol(0, "kCFTypeDictionaryValueCallBacks")) }, "dictionary")
    }

    func set(dict: MacRef, key: MacRef, value: MacRef): Unit {
        unsafe { CFunc<(MacRef, MacRef, MacRef) -> Unit>(symbol(0,
            "CFDictionarySetValue"))(dict, key, value) }
    }

    func count(array: MacRef): Int64 {
        unsafe { CFunc<(MacRef) -> Int64>(symbol(0, "CFArrayGetCount"))(array) }
    }

    func item(array: MacRef, index: Int64): MacRef {
        unsafe { CFunc<(MacRef, Int64) -> MacRef>(symbol(0, "CFArrayGetValueAtIndex"))(array, index) }
    }

    func fontFromFile(path: String, size: Float64, bold: Bool): MacRef {
        if (!(size > 0.0 && size <= 4096.0)) {
            throw NativeTextException("CoreText font size is outside the supported range")
        }
        if (path.isEmpty() || path.contains("\u{0}")) {
            throw NativeTextException("CoreText needs a nonempty font file path")
        }
        var url = MacRef()
        unsafe {
            try (c = LibC.mallocCString(path).asResource()) {
                url = CFunc<(MacRef, CString, Int64, Bool) -> MacRef>(symbol(0,
                    "CFURLCreateFromFileSystemRepresentation"))(MacRef(), c.value, path.size, false)
            }
        }
        require(url, "font URL")
        var descriptors = MacRef()
        try {
            descriptors = require(unsafe { CFunc<(MacRef) -> MacRef>(symbol(1,
                "CTFontManagerCreateFontDescriptorsFromURL"))(url) }, "font descriptors")
            let total = count(descriptors)
            if (total < 1 || total > 256) { throw NativeTextException("CoreText descriptor count is invalid") }
            var selected = item(descriptors, 0)
            var matched = false
            for (i in 0..total) {
                let descriptor = item(descriptors, i)
                let style = unsafe { CFunc<(MacRef, MacRef) -> MacRef>(symbol(1,
                    "CTFontDescriptorCopyAttribute"))(descriptor, constant(1, "kCTFontStyleNameAttribute")) }
                if (style.isNotNull()) {
                    try {
                        let name = stringValue(style)
                        if ((!bold && name == "Regular") || (bold && name == "Bold")) {
                            selected = descriptor
                            matched = true
                        }
                    } finally { release(style) }
                }
            }
            var font = require(unsafe { CFunc<(MacRef, Float64, MacRef) -> MacRef>(symbol(1,
                "CTFontCreateWithFontDescriptor"))(selected, size, MacRef()) }, "file font")
            try {
                if (bold && !matched) {
                    let copy = unsafe { CFunc<(MacRef, Float64, MacRef, UInt32, UInt32) -> MacRef>(symbol(1,
                        "CTFontCreateCopyWithSymbolicTraits"))(font, size, MacRef(), 2, 2) }
                    release(font)
                    font = copy
                    require(font, "bold face")
                }
                font
            } catch (e: Exception) { release(font); throw e }
        } finally { release(descriptors); release(url) }
    }

    func fontName(font: MacRef): String {
        let value = require(unsafe { CFunc<(MacRef) -> MacRef>(symbol(1,
            "CTFontCopyPostScriptName"))(font) }, "font name")
        try { stringValue(value) } finally { release(value) }
    }

    func fontChain(paths: Array<String>, defaultPath: String, size: Float64, bold: Bool): (MacRef, String) {
        let fonts = ArrayList<MacRef>()
        var primaryPath = defaultPath
        var cascade = MacRef()
        var attrs = MacRef()
        var descriptor = MacRef()
        try {
            for (path in paths) {
                try {
                    let font = fontFromFile(path, size, bold)
                    if (fonts.isEmpty()) { primaryPath = path }
                    fonts.add(font)
                } catch (_: NativeTextException) { () }
            }
            if (fonts.isEmpty()) { fonts.add(fontFromFile(defaultPath, size, bold)) }
            cascade = require(unsafe { CFunc<(MacRef, Int64, MacRef) -> MacRef>(symbol(0,
                "CFArrayCreateMutable"))(MacRef(), 0, symbol(0, "kCFTypeArrayCallBacks")) }, "font cascade")
            for (i in 1..fonts.size) {
                let face = require(unsafe { CFunc<(MacRef) -> MacRef>(symbol(1,
                    "CTFontCopyFontDescriptor"))(fonts[i]) }, "fallback descriptor")
                try {
                    unsafe { CFunc<(MacRef, MacRef) -> Unit>(symbol(0,
                        "CFArrayAppendValue"))(cascade, face) }
                } finally { release(face) }
            }
            attrs = dictionary()
            set(attrs, constant(1, "kCTFontCascadeListAttribute"), cascade)
            descriptor = require(unsafe { CFunc<(MacRef) -> MacRef>(symbol(1,
                "CTFontDescriptorCreateWithAttributes"))(attrs) }, "cascade descriptor")
            let result = require(unsafe { CFunc<(MacRef, Float64, MacRef, MacRef) -> MacRef>(symbol(1,
                "CTFontCreateCopyWithAttributes"))(fonts[0], size, MacRef(), descriptor) }, "cascade font")
            (result, primaryPath)
        } finally {
            release(descriptor); release(attrs); release(cascade)
            for (font in fonts) { release(font) }
        }
    }

    func close(): Unit {
        if (closed) { return }
        closed = true
        symbols.clear()
        unsafe {
            if (cg.isNotNull()) { let _ = dlclose(cg) }
            if (ct.isNotNull()) { let _ = dlclose(ct) }
            if (cf.isNotNull()) { let _ = dlclose(cf) }
        }
    }
}
