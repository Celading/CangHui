package chui.system

import std.collection.HashMap

@When[os == "macOS"]
internal type ShellRef = CPointer<Unit>

@When[os == "macOS"]
foreign {
    func dlopen(path: CString, flags: Int32): ShellRef
    func dlsym(handle: ShellRef, name: CString): ShellRef
    func dlclose(handle: ShellRef): Int32
}

/** Fixed OS libraries and fixed, SDK-typed selectors; not a plugin loader. */
@When[os == "macOS"]
internal class MacShellApi {
    private var objc = ShellRef()
    private var appKit = ShellRef()
    private let symbols = HashMap<String, ShellRef>()
    private let selectors = HashMap<String, ShellRef>()
    private var closed = false

    init() {
        try {
            objc = open("/usr/lib/libobjc.A.dylib")
            appKit = open("/System/Library/Frameworks/AppKit.framework/AppKit")
            requireMainThread()
        } catch (error: Exception) { close(); throw error }
    }

    private func open(path: String): ShellRef {
        var value = ShellRef()
        unsafe { try (c = LibC.mallocCString(path).asResource()) { value = dlopen(c.value, 2) } }
        require(value, "system library")
    }

    func require(value: ShellRef, operation: String): ShellRef {
        if (value.isNull()) { throw IllegalStateException("AppKit shell ${operation} failed") }
        value
    }

    func symbol(name: String): ShellRef {
        if (closed) { throw IllegalStateException("AppKit shell API is closed") }
        if (let Some(value) <- symbols.get(name)) { return value }
        var value = ShellRef()
        unsafe {
            try (c = LibC.mallocCString(name).asResource()) {
                value = dlsym(objc, c.value)
                if (value.isNull()) { value = dlsym(appKit, c.value) }
            }
        }
        require(value, name)
        symbols[name] = value
        value
    }

    func sel(name: String): ShellRef {
        if (let Some(value) <- selectors.get(name)) { return value }
        var value = ShellRef()
        unsafe { try (c = LibC.mallocCString(name).asResource()) {
            value = CFunc<(CString) -> ShellRef>(symbol("sel_registerName"))(c.value)
        } }
        selectors[name] = require(value, name)
        value
    }

    func cls(name: String): ShellRef {
        var value = ShellRef()
        unsafe { try (c = LibC.mallocCString(name).asResource()) {
            value = CFunc<(CString) -> ShellRef>(symbol("objc_getClass"))(c.value)
        } }
        require(value, name)
    }

    func get(receiver: ShellRef, selector: String): ShellRef {
        unsafe { CFunc<(ShellRef, ShellRef) -> ShellRef>(symbol("objc_msgSend"))(receiver, sel(selector)) }
    }
    func getInteger(receiver: ShellRef, selector: String): Int64 {
        unsafe { CFunc<(ShellRef, ShellRef) -> Int64>(symbol("objc_msgSend"))(receiver, sel(selector)) }
    }
    func send(receiver: ShellRef, selector: String): Unit {
        unsafe { CFunc<(ShellRef, ShellRef) -> Unit>(symbol("objc_msgSend"))(receiver, sel(selector)) }
    }
    func set(receiver: ShellRef, selector: String, value: ShellRef): Unit {
        unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> Unit>(symbol("objc_msgSend"))(receiver, sel(selector), value) }
    }
    func integer(receiver: ShellRef, selector: String, value: Int64): Unit {
        unsafe { CFunc<(ShellRef, ShellRef, Int64) -> Unit>(symbol("objc_msgSend"))(receiver, sel(selector), value) }
    }
    func boolean(receiver: ShellRef, selector: String, value: Bool): Unit {
        unsafe { CFunc<(ShellRef, ShellRef, Bool) -> Unit>(symbol("objc_msgSend"))(receiver, sel(selector), value) }
    }
    func retain(value: ShellRef): ShellRef { get(value, "retain") }
    func release(value: ShellRef): Unit { send(value, "release") }
    func object(name: String): ShellRef { require(get(get(cls(name), "alloc"), "init"), name) }

    func requireMainThread(): Unit {
        let isMainThread = unsafe { CFunc<(ShellRef, ShellRef) -> Bool>(symbol("objc_msgSend"))(
            cls("NSThread"), sel("isMainThread")) }
        if (!isMainThread) { throw IllegalStateException("AppKit shell requires the native main thread") }
    }

    func text(value: String): ShellRef {
        if (value.contains("\u{0}")) { throw IllegalArgumentException("AppKit text contains NUL") }
        var result = ShellRef()
        unsafe { try (c = LibC.mallocCString(value).asResource()) {
            result = CFunc<(ShellRef, ShellRef, CString) -> ShellRef>(symbol("objc_msgSend"))(
                get(cls("NSString"), "alloc"), sel("initWithUTF8String:"), c.value)
        } }
        require(result, "UTF8 string")
    }

    func setText(receiver: ShellRef, selector: String, value: String): Unit {
        let native = text(value)
        try { set(receiver, selector, native) } finally { release(native) }
    }

    func menu(title: String): ShellRef {
        let name = text(title)
        try {
            require(unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> ShellRef>(symbol("objc_msgSend"))(
                get(cls("NSMenu"), "alloc"), sel("initWithTitle:"), name) }, "menu")
        } finally { release(name) }
    }

    func item(title: String, action: ShellRef, target: ShellRef, key: String, mask: Int64): ShellRef {
        let name = text(title)
        var equivalent = ShellRef()
        var value = ShellRef()
        try {
            equivalent = text(key)
            value = require(unsafe { CFunc<(ShellRef, ShellRef, ShellRef, ShellRef, ShellRef) -> ShellRef>(
                symbol("objc_msgSend"))(get(cls("NSMenuItem"), "alloc"), sel("initWithTitle:action:keyEquivalent:"),
                    name, action, equivalent) }, "menu item")
            set(value, "setTarget:", target)
            unsafe { CFunc<(ShellRef, ShellRef, UIntNative) -> Unit>(symbol("objc_msgSend"))(
                value, sel("setKeyEquivalentModifierMask:"), UIntNative(mask)) }
            value
        } catch (error: Exception) { release(value); throw error }
        finally { release(equivalent); release(name) }
    }

    func dictionaryText(dict: ShellRef, key: String, value: String): Unit {
        let native = text(value)
        try {
            let nativeKey = unsafe { CPointer<ShellRef>(symbol(key)).read() }
            unsafe { CFunc<(ShellRef, ShellRef, ShellRef, ShellRef) -> Unit>(symbol("objc_msgSend"))(
                dict, sel("setObject:forKey:"), native, nativeKey) }
        } finally { release(native) }
    }

    func targetClass(): ShellRef {
        var result = ShellRef()
        unsafe { try (name = LibC.mallocCString("CHUIAppMenuTarget_v1").asResource()) {
            result = CFunc<(CString) -> ShellRef>(symbol("objc_getClass"))(name.value)
            if (result.isNotNull()) { return result }
            result = require(CFunc<(ShellRef, CString, UIntNative) -> ShellRef>(symbol("objc_allocateClassPair"))(
                cls("NSObject"), name.value, 0), "target class")
            try (encoding = LibC.mallocCString("v@:@").asResource()) {
                let added = CFunc<(ShellRef, ShellRef, CFunc<(ShellRef, ShellRef, ShellRef) -> Unit>, CString) -> Bool>(
                    symbol("class_addMethod"))(result, sel("chuiPerformAction:"), macShellActionCallback, encoding.value)
                if (!added) {
                    CFunc<(ShellRef) -> Unit>(symbol("objc_disposeClassPair"))(result)
                    throw IllegalStateException("AppKit shell target method registration failed")
                }
            }
            // Derive BOOL's encoding from the current SDK runtime (B on arm64,
            // c on older Intel ABI), instead of assuming one host's metadata.
            let sample = require(CFunc<(ShellRef, ShellRef) -> ShellRef>(symbol("class_getInstanceMethod"))(
                cls("NSMenuItem"), sel("isEnabled")), "BOOL sample method")
            let sampleEncoding = CFunc<(ShellRef) -> CString>(symbol("method_getTypeEncoding"))(sample).toString()
            let first = sampleEncoding.toRuneArray()[0].toString()
            if (first != "B" && first != "c") { throw IllegalStateException("unsupported AppKit BOOL encoding") }
            try (encoding = LibC.mallocCString(first + "@:@").asResource()) {
                let added = CFunc<(ShellRef, ShellRef, CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>, CString) -> Bool>(
                    symbol("class_addMethod"))(result, sel("validateMenuItem:"), macShellValidateCallback, encoding.value)
                if (!added) {
                    CFunc<(ShellRef) -> Unit>(symbol("objc_disposeClassPair"))(result)
                    throw IllegalStateException("AppKit shell validation registration failed")
                }
            }
            CFunc<(ShellRef) -> Unit>(symbol("objc_registerClassPair"))(result)
        } }
        result
    }

    func close(): Unit {
        if (closed) { return }
        closed = true
        symbols.clear(); selectors.clear()
        unsafe {
            if (appKit.isNotNull()) { let _ = dlclose(appKit) }
            if (objc.isNotNull()) { let _ = dlclose(objc) }
        }
    }
}
