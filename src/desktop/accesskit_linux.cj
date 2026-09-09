package chui.desktop

import std.collection.HashMap
import chui.core.{SemanticActionKind, SemanticNativeBinding, SemanticNativeSnapshot,
    SemanticNode, SemanticTreeSnapshot}

@When[os == "Linux"]
internal type AccessibilityRef = CPointer<Unit>

@When[os == "Linux"]
foreign {
    func dlopen(path: CString, flags: Int32): AccessibilityRef
    func dlsym(handle: AccessibilityRef, name: CString): AccessibilityRef
}

/**
 * Opt-in Linux AccessKit C0.23 bridge. Paths must name trusted, absolute local
 * native/bridge libraries supplied by the application; no search, download or
 * environment-controlled selection. Loading executable code is not authenticated
 * by an ABI check. Libraries intentionally remain loaded until process exit:
 * upstream adapter destruction deregisters asynchronously, without joining callbacks.
 * This preview requires measured X11 screen bounds and projects through the
 * window's existing scale transform. Other native geometry backends, glyph bounds
 * and reader SDK dependency delivery still require integration.
 */
@When[os == "Linux"]
public func linuxAccessKitAccessibility(nativeLibrary: String, bridgeLibrary: String): DesktopAccessibilityFactory {
    let api = LinuxAccessibilityApi(nativeLibrary, bridgeLibrary)
    {windowId, title => LinuxAccessibilityAdapter(api, windowId, title)}
}

@When[os == "Linux"]
private class LinuxAccessibilityAdapter <: DesktopAccessibilityAdapter & DesktopAccessibilityGeometryAdapter {
    private let api: LinuxAccessibilityApi
    private let windowId: String
    private let title: String
    private var token: UInt64
    private var latest: ?SemanticTreeSnapshot = None
    private var bindings: Array<SemanticNativeBinding> = []
    private var geometry: ?DesktopAccessibilityGeometry = None
    private var committedGeometry: ?DesktopAccessibilityGeometry = None

    init(api: LinuxAccessibilityApi, windowId: String, title: String) {
        api.checkText(title)
        this.api = api
        this.windowId = windowId
        this.title = title
        token = unsafe { CFunc<() -> UInt64>(api.symbol("chui_ak_unix_new"))() }
        api.require(token != UInt64(0), "adapter allocation/capacity")
    }

    public func publish(snapshot: SemanticNativeSnapshot): Unit {
        requireOpen()
        let measured = geometry.getOrThrow()
        api.require(snapshot.tree.windowId == windowId, "foreign window")
        // Cache detached data, never a caller-mutable array, for idle activation.
        let tree = SemanticTreeSnapshot(snapshot.tree.windowId, snapshot.tree.revision, snapshot.tree.nodes)
        let ownedBindings = snapshot.bindings.clone()
        api.windowBounds(token, measured.screen.getOrThrow())
        let update = api.buildTree(title, tree, ownedBindings, measured)
        // The checked bridge consumes on every path; all symbols resolved before allocation.
        api.require(unsafe { CFunc<(UInt64, UInt64, AccessibilityRef) -> Bool>(
            api.symbol("chui_ak_unix_publish"))(token, tree.revision, update) }, "tree publication")
        latest = Some(tree)
        bindings = ownedBindings
        committedGeometry = Some(measured)
    }

    public func setWindowGeometry(value: DesktopAccessibilityGeometry): Unit {
        requireOpen()
        api.require(value.videoDriver == "x11" && value.screen.isSome(),
            "screen geometry unavailable: this preview requires measured X11 coordinates")
        geometry = Some(value)
        if (let Some(previous) <- committedGeometry) {
            // Moving a window does not require semantic redraw. A scale/resize
            // transaction, however, must wait for its matching committed layout.
            if (sameAccessibilityTransform(previous.metrics, value.metrics)) {
                api.windowBounds(token, value.screen.getOrThrow())
                committedGeometry = Some(value)
            }
        }
    }

    public func setWindowFocused(focused: Bool): Unit {
        requireOpen()
        api.require(unsafe { CFunc<(UInt64, Bool) -> Bool>(api.symbol("chui_ak_unix_focus"))(
            token, focused) }, "window focus")
    }

    public func poll(): ?DesktopAccessibilityAction {
        requireOpen()
        if (let Some(tree) <- latest) {
            let refresh = unsafe { CFunc<(UInt64) -> Bool>(api.symbol("chui_ak_unix_needs_refresh"))(token) }
            if (refresh) {
                let update = api.buildTree(title, tree, bindings, committedGeometry.getOrThrow())
                // A concurrent deactivation may withdraw the request after needs_refresh.
                // False still consumes the update; the next poll observes any newer activation.
                unsafe { let _ = CFunc<(UInt64, UInt64, AccessibilityRef) -> Bool>(
                    api.symbol("chui_ak_unix_refresh"))(token, tree.revision, update) }
            }
        }
        var target = UInt64(0)
        var revision = UInt64(0)
        var action = UInt32(0)
        let available = unsafe {
            CFunc<(UInt64, CPointer<UInt64>, CPointer<UInt64>, CPointer<UInt32>) -> Bool>(
                api.symbol("chui_ak_unix_poll"))(token, inout target, inout revision, inout action)
        }
        if (!available) { return None }
        let kind = match (action) {
            case 1 => SemanticActionKind.Focus
            case 2 => SemanticActionKind.Activate
            case 4 => SemanticActionKind.Increment
            case 8 => SemanticActionKind.Decrement
            case _ => throw IllegalStateException("AccessKit bridge returned an unknown action")
        }
        Some(DesktopAccessibilityAction(target, revision, kind))
    }

    public func close(): Unit {
        if (isClosed()) { return }
        let previous = token
        token = UInt64(0)
        latest = None
        bindings = []
        geometry = None
        committedGeometry = None
        unsafe { CFunc<(UInt64) -> Unit>(api.symbol("chui_ak_unix_close"))(previous) }
    }

    public func isClosed(): Bool { token == UInt64(0) }
    private func requireOpen(): Unit { api.require(!isClosed(), "adapter closed") }
}

@When[os == "Linux"]
private class LinuxAccessibilityApi {
    private var native = AccessibilityRef()
    private var bridge = AccessibilityRef()
    private let symbols = HashMap<String, AccessibilityRef>()

    init(nativePath: String, bridgePath: String) {
        checkPath(nativePath); checkPath(bridgePath)
        native = open(nativePath)
        bridge = open(bridgePath)
        for (name in ["chui_ak_unix_abi_version", "chui_ak_unix_new", "chui_ak_unix_publish",
            "chui_ak_unix_needs_refresh", "chui_ak_unix_refresh", "chui_ak_unix_focus",
            "chui_ak_unix_poll", "chui_ak_unix_close", "chui_ak_unix_bounds", "chui_ak_tree_new", "chui_ak_tree_add",
            "chui_ak_tree_finish", "chui_ak_tree_free", "chui_ak_tree_text", "chui_ak_tree_selection",
            "chui_ak_tree_multiline"]) {
            var address = AccessibilityRef()
            unsafe { try (text = LibC.mallocCString(name).asResource()) {
                address = dlsym(bridge, text.value)
            } }
            require(address.isNotNull(), "missing symbol ${name}")
            symbols[name] = address
        }
        require(unsafe { CFunc<() -> UInt32>(symbol("chui_ak_unix_abi_version"))() } == UInt32(1), "bridge ABI")
        // No dlclose, including initialization failure: a loaded library may have
        // asynchronous native state. The process owns the loader references.
    }

    func require(valid: Bool, operation: String): Unit {
        if (!valid) { throw IllegalStateException("AccessKit ${operation} failed") }
    }
    func checkText(text: String): Unit {
        if (text.contains("\u{0}")) { throw IllegalArgumentException("AccessKit text contains NUL") }
    }
    private func checkPath(path: String): Unit {
        checkText(path)
        if (!path.startsWith("/") || path.size <= 1) {
            throw IllegalArgumentException("AccessKit requires an explicit absolute library path")
        }
    }
    private func open(path: String): AccessibilityRef {
        var handle = AccessibilityRef()
        unsafe { try (text = LibC.mallocCString(path).asResource()) { handle = dlopen(text.value, 2) } }
        require(handle.isNotNull(), "load ${path}")
        handle
    }
    func symbol(name: String): AccessibilityRef { symbols[name] }

    func windowBounds(token: UInt64, bounds: DesktopAccessibilityScreenBounds): Unit {
        let outer = bounds.outer
        let inner = bounds.inner
        require(unsafe { CFunc<(UInt64, Float64, Float64, Float64, Float64,
            Float64, Float64, Float64, Float64) -> Bool>(symbol("chui_ak_unix_bounds"))(
                token, Float64(outer.x), Float64(outer.y), Float64(outer.w), Float64(outer.h),
                Float64(inner.x), Float64(inner.y), Float64(inner.w), Float64(inner.h)) }, "window bounds")
    }

    func buildTree(title: String, tree: SemanticTreeSnapshot, bindings: Array<SemanticNativeBinding>,
        geometry: DesktopAccessibilityGeometry): AccessibilityRef {
        let index = HashMap<String, SemanticNativeBinding>()
        for (binding in bindings) { index[binding.semanticId] = binding }
        var transaction = AccessibilityRef()
        try {
            unsafe { try (text = LibC.mallocCString(title).asResource()) {
                transaction = CFunc<(CString) -> AccessibilityRef>(symbol("chui_ak_tree_new"))(text.value)
            } }
            require(transaction.isNotNull(), "tree allocation")
            for (node in tree.nodes) {
                appendNode(transaction, index[node.id], node, geometry)
                if (let Some(lengths) <- accessibilityTextLengths(node.role, node.value)) {
                    appendText(transaction, index[node.id].nativeId, lengths, node.role == "textarea")
                    if (let Some((anchor, focus)) <- accessibilityTextSelection(node, lengths)) {
                        require(unsafe { CFunc<(AccessibilityRef, UInt64, UIntNative, UIntNative) -> Bool>(
                            symbol("chui_ak_tree_selection"))(transaction, index[node.id].nativeId,
                            UIntNative(anchor), UIntNative(focus)) }, "text selection projection")
                    }
                }
            }
            let result = unsafe { CFunc<(AccessibilityRef) -> AccessibilityRef>(
                symbol("chui_ak_tree_finish"))(transaction) }
            transaction = AccessibilityRef() // finish consumes even on rejection.
            require(result.isNotNull(), "full tree validation")
            result
        } finally {
            if (transaction.isNotNull()) {
                unsafe { CFunc<(AccessibilityRef) -> Unit>(symbol("chui_ak_tree_free"))(transaction) }
            }
        }
    }

    private func appendText(tree: AccessibilityRef, id: UInt64, lengths: Array<UInt8>, multiline: Bool): Unit {
        unsafe {
            let bytes = LibC.malloc<UInt8>(count: max(Int64(1), lengths.size))
            require(bytes.isNotNull(), "text span allocation")
            try {
                for (i in 0..lengths.size) { bytes.write(i, lengths[i]) }
                require(CFunc<(AccessibilityRef, UInt64, UIntNative, CPointer<UInt8>) -> Bool>(
                    symbol(if (multiline) { "chui_ak_tree_multiline" } else { "chui_ak_tree_text" }))(
                        tree, id, UIntNative(lengths.size), bytes), "text projection")
            } finally { LibC.free(bytes) }
        }
    }

    private func appendNode(tree: AccessibilityRef, binding: SemanticNativeBinding, node: SemanticNode,
        geometry: DesktopAccessibilityGeometry): Unit {
        for (text in [node.role, node.label, node.value, node.placeholder]) { checkText(text) }
        let frame = geometry.logicalToPixels(node.frame)
        var states = UInt32(0)
        if (!node.enabled) { states += 1 }
        if (node.readOnly) { states += 2 }
        if (let Some(selected) <- node.selected) { states += 4; if (selected) { states += 8 } }
        if (let Some(expanded) <- node.expanded) { states += 16; if (expanded) { states += 32 } }
        if (node.focused == Some(true)) { states += 64 }
        var actions = UInt32(0)
        for (action in node.actions) {
            actions = actions | match (action) {
                case SemanticActionKind.Focus => UInt32(1)
                case SemanticActionKind.Activate => UInt32(2)
                case SemanticActionKind.Increment => UInt32(4)
                case SemanticActionKind.Decrement => UInt32(8)
                case SemanticActionKind.Dismiss => UInt32(16)
            }
        }
        unsafe {
            try (role = LibC.mallocCString(node.role).asResource()) {
              try (label = LibC.mallocCString(node.label).asResource()) {
                try (value = LibC.mallocCString(node.value).asResource()) {
                  try (placeholder = LibC.mallocCString(node.placeholder).asResource()) {
                    require(CFunc<(AccessibilityRef, UInt64, UInt64, CString, CString, CString, CString,
                        Float64, Float64, Float64, Float64, UInt32, UInt32) -> Bool>(symbol("chui_ak_tree_add"))(
                        tree, binding.nativeId, binding.parentNativeId, role.value, label.value, value.value,
                        placeholder.value, Float64(frame.x), Float64(frame.y), Float64(frame.w),
                        Float64(frame.h), states, actions), "node projection")
                  }
                }
              }
            }
        }
    }
}
