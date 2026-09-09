package sdl.text

import std.collection.{ArrayList, HashMap}

@When[os == "Linux"]
internal type PangoRef = CPointer<Unit>

@When[os == "Linux"]
foreign {
    func dlopen(path: CString, flags: Int32): PangoRef
    func dlsym(handle: PangoRef, name: CString): PangoRef
    func dlclose(handle: PangoRef): Int32
}

@When[os == "Linux"]
@C
internal struct PangoTextRect {
    var x: Int32 = 0
    var y: Int32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
}

// Fixed system sonames, not an application/plugin loading surface. Pango1.48+
// is required. NODELETE preserves GType callbacks after the last engine closes;
// native lines/maps/textures still release their own references deterministically.
@When[os == "Linux"]
internal class PangoTextApi <: PlatformTextLineFactory {
    private let handles = ArrayList<PangoRef>()
    private let symbols = HashMap<String, PangoRef>()
    private let fonts = GenerationCache<PangoTextFonts>(8, {value => value.close()})
    private var closed = false

    init() {
        try {
            for (name in ["libpango-1.0.so.0", "libpangocairo-1.0.so.0", "libpangoft2-1.0.so.0",
                "libfontconfig.so.1", "libcairo.so.2", "libgobject-2.0.so.0", "libglib-2.0.so.0"]) {
                var handle = PangoRef()
                unsafe { try (c = LibC.mallocCString(name).asResource()) { handle = dlopen(c.value, 4098) } }
                handles.add(PangoTextApi.require(handle, name))
            }
            // Resolve every callable before advertising availability.
            for ((library, names) in pangoRequiredSymbols()) {
                for (name in names) { let _ = symbol(library, name) }
            }
        } catch (e: Exception) { close(); throw e }
    }

    static func require(pointer: PangoRef, operation: String): PangoRef {
        if (pointer.isNull()) { throw NativeTextException("Pango ${operation} unavailable") }
        pointer
    }

    func symbol(library: Int64, name: String): PangoRef {
        if (closed) { throw NativeTextException("Pango API is closed") }
        let key = "${library}:${name}"
        if (let Some(found) <- symbols.get(key)) { return found }
        var value = PangoRef()
        unsafe { try (c = LibC.mallocCString(name).asResource()) { value = dlsym(handles[library], c.value) } }
        let found = PangoTextApi.require(value, name)
        symbols[key] = found
        found
    }

    func unref(value: PangoRef): Unit {
        if (value.isNotNull()) { unsafe { CFunc<(PangoRef) -> Unit>(symbol(5, "g_object_unref"))(value) } }
    }

    func patternString(pattern: PangoRef, key: String): String {
        var out = CString(CPointer<UInt8>())
        unsafe {
            try (c = LibC.mallocCString(key).asResource()) {
                let status = CFunc<(PangoRef, CString, Int32, CPointer<CString>) -> Int32>(
                    symbol(3, "FcPatternGetString"))(pattern, c.value, 0, inout out)
                if (status == 0) { return out.toString() }
            }
        }
        ""
    }

    func fontMap(paths: Array<String>, defaultPath: String): PangoTextFonts {
        let key = "${defaultPath.size}:${defaultPath}|" + fontPathChainKey(paths)
        if (let Some(found) <- fonts.get(key)) { return found }
        let created = PangoTextFonts(this, paths, defaultPath)
        fonts.put(key, created)
        created
    }

    public func createLine(text: String, paths: Array<String>, defaultPath: String,
        size: Float32, bold: Bool, paint!: ?NativeTextLineSpec): PlatformTextLine {
        PangoTextLine(this, text, paths, defaultPath, size, bold, paint: paint)
    }

    public func close(): Unit {
        if (closed) { return }
        fonts.clear()
        closed = true
        symbols.clear()
        for (i in 0..handles.size) { unsafe { let _ = dlclose(handles[handles.size - 1 - i]) } }
        handles.clear()
    }
}
