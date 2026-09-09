package chui.system

// Native objects can outlive the provider when retained by AppKit/another host.
// Keep only fixed OS API/class metadata alive, never a global delegate/menu map.
@When[os == "macOS"]
private var macDockRuntime: ?MacDockRuntime = None

@When[os == "macOS"]
private class MacDockRuntime {
    let api = MacShellApi()
    var proxyClass = ShellRef()
    let originalKey: ShellRef
    let menuKey: ShellRef

    init() {
        originalKey = api.sel("chuiDockOriginalDelegate_v1")
        menuKey = api.sel("chuiDockCustomMenu_v1")
        try { proxyClass = createClass() }
        catch (error: Exception) { api.close(); throw error }
    }

    func associated(receiver: ShellRef, key: ShellRef): ShellRef {
        unsafe { CFunc<(ShellRef, ShellRef) -> ShellRef>(api.symbol("objc_getAssociatedObject"))(receiver, key) }
    }
    func associate(receiver: ShellRef, key: ShellRef, value: ShellRef): Unit {
        unsafe { CFunc<(ShellRef, ShellRef, ShellRef, UIntNative) -> Unit>(api.symbol("objc_setAssociatedObject"))(
            receiver, key, value, 1) }
    }
    func supports(receiver: ShellRef, selector: ShellRef): Bool {
        unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>(api.symbol("objc_msgSend"))(
            receiver, api.sel("respondsToSelector:"), selector) }
    }
    func ownMethod(selector: ShellRef): Bool {
        unsafe { CFunc<(ShellRef, ShellRef) -> ShellRef>(api.symbol("class_getInstanceMethod"))(
            proxyClass, selector).isNotNull() }
    }
    func call(receiver: ShellRef, name: String, argument: ShellRef): ShellRef {
        unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> ShellRef>(api.symbol("objc_msgSend"))(
            receiver, api.sel(name), argument) }
    }
    func conforms(receiver: ShellRef, protocol: ShellRef): Bool {
        let own = unsafe { CFunc<(ShellRef, ShellRef) -> Bool>(api.symbol("class_conformsToProtocol"))(proxyClass, protocol) }
        own || unsafe { CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>(api.symbol("objc_msgSend"))(
            associated(receiver, originalKey), api.sel("conformsToProtocol:"), protocol) }
    }

    private func add(cls: ShellRef, name: String,
        callback: CFunc<(ShellRef, ShellRef, ShellRef) -> ShellRef>, encoding: String): Unit {
        unsafe { try (text = LibC.mallocCString(encoding).asResource()) {
            if (!CFunc<(ShellRef, ShellRef, CFunc<(ShellRef, ShellRef, ShellRef) -> ShellRef>, CString) -> Bool>(
                api.symbol("class_addMethod"))(cls, api.sel(name), callback, text.value)) {
                throw IllegalStateException("Dock delegate method registration failed")
            }
        } }
    }
    private func add(cls: ShellRef, name: String,
        callback: CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>, encoding: String): Unit {
        unsafe { try (text = LibC.mallocCString(encoding).asResource()) {
            if (!CFunc<(ShellRef, ShellRef, CFunc<(ShellRef, ShellRef, ShellRef) -> Bool>, CString) -> Bool>(
                api.symbol("class_addMethod"))(cls, api.sel(name), callback, text.value)) {
                throw IllegalStateException("Dock delegate method registration failed")
            }
        } }
    }
    private func createClass(): ShellRef {
        var result = ShellRef()
        unsafe { try (name = LibC.mallocCString("CHUIDockDelegate_v1").asResource()) {
            result = CFunc<(CString) -> ShellRef>(api.symbol("objc_getClass"))(name.value)
            if (result.isNotNull()) { return result }
            result = api.require(CFunc<(ShellRef, CString, UIntNative) -> ShellRef>(api.symbol("objc_allocateClassPair"))(
                api.cls("NSObject"), name.value, 0), "Dock delegate class")
        } }
        try {
            let sample = unsafe { CFunc<(ShellRef, ShellRef) -> ShellRef>(api.symbol("class_getInstanceMethod"))(
                api.cls("NSMenuItem"), api.sel("isEnabled")) }
            let encoding = unsafe { CFunc<(ShellRef) -> CString>(api.symbol("method_getTypeEncoding"))(sample).toString() }
            let boolType = encoding.toRuneArray()[0].toString()
            if (boolType != "B" && boolType != "c") { throw IllegalStateException("unsupported AppKit BOOL encoding") }
            add(result, "applicationDockMenu:", macDockMenuCallback, "@@:@")
            add(result, "forwardingTargetForSelector:", macDockForwardCallback, "@@::")
            add(result, "methodSignatureForSelector:", macDockSignatureCallback, "@@::")
            add(result, "respondsToSelector:", macDockRespondsCallback, boolType + "@::")
            add(result, "conformsToProtocol:", macDockConformsCallback, boolType + "@:@")
            unsafe { try (name = LibC.mallocCString("NSApplicationDelegate").asResource()) {
                let protocol = api.require(CFunc<(CString) -> ShellRef>(api.symbol("objc_getProtocol"))(name.value), "application delegate protocol")
                if (!CFunc<(ShellRef, ShellRef) -> Bool>(api.symbol("class_addProtocol"))(result, protocol)) {
                    throw IllegalStateException("Dock delegate protocol registration failed")
                }
            } }
        } catch (error: Exception) {
            unsafe { CFunc<(ShellRef) -> Unit>(api.symbol("objc_disposeClassPair"))(result) }
            throw error
        }
        unsafe { CFunc<(ShellRef) -> Unit>(api.symbol("objc_registerClassPair"))(result) }
        result
    }
}

@When[os == "macOS"]
@C
internal func macDockMenuCallback(receiver: ShellRef, _: ShellRef, _: ShellRef): ShellRef {
    try { if (let Some(runtime) <- macDockRuntime) {
        runtime.api.requireMainThread()
        return runtime.associated(receiver, runtime.menuKey)
    } } catch (_: Exception) { }
    ShellRef()
}

@When[os == "macOS"]
@C
internal func macDockForwardCallback(receiver: ShellRef, _: ShellRef, selector: ShellRef): ShellRef {
    try { if (let Some(runtime) <- macDockRuntime) {
        runtime.api.requireMainThread()
        let original = runtime.associated(receiver, runtime.originalKey)
        if (runtime.supports(original, selector)) { return original }
    } } catch (_: Exception) { }
    ShellRef()
}

@When[os == "macOS"]
@C
internal func macDockSignatureCallback(receiver: ShellRef, _: ShellRef, selector: ShellRef): ShellRef {
    try { if (let Some(runtime) <- macDockRuntime) {
        runtime.api.requireMainThread()
        if (runtime.ownMethod(selector)) { return runtime.call(runtime.proxyClass, "instanceMethodSignatureForSelector:", selector) }
        return runtime.call(runtime.associated(receiver, runtime.originalKey), "methodSignatureForSelector:", selector)
    } } catch (_: Exception) { }
    ShellRef()
}

@When[os == "macOS"]
@C
internal func macDockRespondsCallback(receiver: ShellRef, _: ShellRef, selector: ShellRef): Bool {
    try { if (let Some(runtime) <- macDockRuntime) {
        runtime.api.requireMainThread()
        return runtime.ownMethod(selector) || runtime.supports(runtime.associated(receiver, runtime.originalKey), selector)
    } } catch (_: Exception) { }
    false
}

@When[os == "macOS"]
@C
internal func macDockConformsCallback(receiver: ShellRef, _: ShellRef, protocol: ShellRef): Bool {
    try { if (let Some(runtime) <- macDockRuntime) {
        runtime.api.requireMainThread()
        return runtime.conforms(receiver, protocol)
    } } catch (_: Exception) { }
    false
}

/** One explicitly enabled delegate wrapper; no action dispatch or class swizzle. */
@When[os == "macOS"]
internal class MacShellDock {
    private var proxy = ShellRef()
    private var application = ShellRef()

    func apply(native: MacShellApi, app: ShellRef, menu: ShellRef): Unit {
        native.requireMainThread()
        if (macDockRuntime.isNone()) { macDockRuntime = Some(MacDockRuntime()) }
        let runtime = macDockRuntime.getOrThrow()
        if (proxy.isNotNull()) {
            if (native.get(app, "delegate").toUIntNative() != proxy.toUIntNative()) {
                throw IllegalStateException("another host replaced the Dock delegate; clear before enabling again")
            }
            runtime.associate(proxy, runtime.menuKey, menu)
            return
        }
        let value = native.require(native.get(native.get(runtime.proxyClass, "alloc"), "init"), "Dock delegate")
        try {
            runtime.associate(value, runtime.originalKey, native.get(app, "delegate"))
            runtime.associate(value, runtime.menuKey, menu)
            native.set(app, "setDelegate:", value)
            proxy = value
            application = app
        } catch (error: Exception) { native.release(value); throw error }
    }

    func detach(native: MacShellApi): Unit {
        native.requireMainThread()
        if (proxy.isNull()) { return }
        let runtime = macDockRuntime.getOrThrow()
        if (native.get(application, "delegate").toUIntNative() == proxy.toUIntNative()) {
            native.set(application, "setDelegate:", runtime.associated(proxy, runtime.originalKey))
        }
        runtime.associate(proxy, runtime.menuKey, ShellRef())
        // Keep original on the object until native deallocation: a retained proxy
        // must still forward safely after this provider and its API have closed.
        native.release(proxy)
        proxy = ShellRef()
        application = ShellRef()
    }
}
