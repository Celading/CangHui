package chui.core

import std.collection.ArrayList
import sdl.{Key, Rect, Size, UiEvent}

/* Frame-local bindings, not a global keyboard hook. A capture decorates exactly one
 * already-focusable control; its callback is separate from ordinary tree dispatch. */
class FocusedKeyboardBinding {
    let id: String
    let owner: Object
    let handler: (UiContext, UiEvent) -> Bool
    init(id: String, owner: Object, handler: (UiContext, UiEvent) -> Bool) {
        this.id = id
        this.owner = owner
        this.handler = handler
    }
}

class FocusedKeyboardRouter {
    private let bindings = ArrayList<FocusedKeyboardBinding>()
    private let ambiguous = ArrayList<String>()
    private var active = true
    private var tabHeld = false
    private var tabOwner = ""
    private var traversalReleasePending = false
    private var ownershipRevision: UInt64 = 0

    func beginLayout(): Unit { bindings.clear(); ambiguous.clear() }
    func invalidateHeld(): Unit { tabOwner = ""; ownershipRevision += 1 }
    func setActive(value: Bool): Unit {
        active = value
        if (!value) { invalidateHeld() }
    }

    func register(binding: FocusedKeyboardBinding): Unit {
        for (existing in bindings) {
            if (existing.id == binding.id) {
                if (!refEq(existing.owner, binding.owner) && !ambiguous.contains(binding.id)) {
                    ambiguous.add(binding.id)
                }
                return
            }
        }
        bindings.add(binding)
    }

    private func focused(ctx: UiContext): ?FocusedKeyboardBinding {
        if (!active || ctx.hasOverlay() || ctx.focusId.isEmpty() || ambiguous.contains(ctx.focusId) ||
            ctx.semanticFocusOrder(ctx.focusId).isNone()) { return None }
        for (binding in bindings) {
            if (binding.id == ctx.focusId) { return Some(binding) }
        }
        None
    }

    func dispatch(ctx: UiContext, root: Widget, event: UiEvent): Bool {
        // This entry owns physical keys only. TextInput/composition are never synthesized here.
        match (event) {
            case UiEvent.KeyDown(_, _) | UiEvent.KeyUp(_) => ()
            case _ => return false
        }
        if (!active) { return true }
        let binding = focused(ctx)
        if (ctx.hasOverlay()) { invalidateHeld() }
        // A held captured/escape Tab must not become navigation or a key-up in another owner.
        match (event) {
            case UiEvent.KeyUp(Key.Tab) where traversalReleasePending =>
                traversalReleasePending = false
                let _ = ctx.dispatchOverlay(event)
                return true
            case UiEvent.KeyUp(Key.Tab) where tabHeld =>
                let owner = tabOwner
                tabHeld = false
                tabOwner = ""
                if (ctx.dispatchOverlay(event)) { return true }
                if (let Some(current) <- binding) {
                    if (current.id == owner) { let _ = current.handler(ctx, event) }
                }
                return true
            case UiEvent.KeyDown(Key.Tab, true) where tabHeld =>
                if (ctx.dispatchOverlay(event)) { return true }
                if (let Some(current) <- binding) {
                    if (current.id == tabOwner) { let _ = current.handler(ctx, event) }
                    else { invalidateHeld() }
                } else { invalidateHeld() }
                return true
            case UiEvent.KeyDown(Key.Tab, false) =>
                tabHeld = false; tabOwner = ""; traversalReleasePending = false
            case _ => ()
        }
        if (ctx.dispatchOverlay(event)) { return true }
        match (event) {
            case UiEvent.KeyDown(Key.Tab, repeat) =>
                if (let Some(current) <- binding) {
                    let modifiers = ctx.keyModifiers()
                    // Ctrl, not Command; AltGr (Ctrl+Alt/mode) is not an escape chord.
                    if (modifiers.ctrl && !modifiers.alt && !modifiers.gui && !modifiers.mode) {
                        tabHeld = true
                        if (!repeat) {
                            if (modifiers.shift) { ctx.focusPrevious() } else { ctx.focusNext() }
                            if (ctx.focusId == current.id) { ctx.clearFocus() }
                        }
                        return true
                    }
                    // A repeat without a fresh press cannot begin a capture after window switching.
                    if (repeat) { return true }
                    let pressRevision = ownershipRevision
                    if (current.handler(ctx, event)) {
                        tabHeld = true
                        tabOwner = if (ownershipRevision == pressRevision && active && !ctx.hasOverlay() &&
                            ctx.focusId == current.id) { current.id } else { "" }
                        return true
                    }
                }
                traversalReleasePending = true
                if (ctx.keyModifiers().shift) { ctx.focusPrevious() } else { ctx.focusNext() }
                true
            case _ =>
                if (let Some(current) <- binding) {
                    if (current.handler(ctx, event)) { return true }
                }
                root.handle(ctx, event)
        }
    }
}

private class KeyboardCaptureWidget <: Widget {
    private let child: Widget
    private let handler: (UiContext, UiEvent) -> Bool

    init(child: Widget, handler: (UiContext, UiEvent) -> Bool) {
        this.child = child
        this.handler = handler
    }
    public func measure(ctx: UiContext, available: Size): Size { child.measure(ctx, available) }
    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
        if (!child.interactionsEnabled() || !child.participatesInLayout() || rect.w <= 0.0 || rect.h <= 0.0) { return }
        if (ctx.viewportWidth > 0.0 && ctx.viewportHeight > 0.0 &&
            (rect.right() <= 0.0 || rect.bottom() <= 0.0 || rect.x >= ctx.viewportWidth || rect.y >= ctx.viewportHeight)) { return }
        if (let Some(id) <- child.focusableId()) {
            ctx.registerFocusedKeyboardBinding(FocusedKeyboardBinding(id, this, handler))
        }
    }
    public func draw(ctx: UiContext): Unit { child.draw(ctx) }
    public func handle(ctx: UiContext, event: UiEvent): Bool { child.handle(ctx, event) }
    public func isFlexible(): Bool { child.isFlexible() }
    public func flexWeight(): Float32 { child.flexWeight() }
    public func acceptsStretch(axis: Axis): Bool { child.acceptsStretch(axis) }
    public func participatesInLayout(): Bool { child.participatesInLayout() }
    public func stackingIndex(): Int64 { child.stackingIndex() }
    public func focusableId(): ?String { child.focusableId() }
    public func focusableIds(): Array<String> { child.focusableIds() }
    public func interactionOwnerIds(): Array<String> { child.interactionOwnerIds() }
    public func interactionsEnabled(): Bool { child.interactionsEnabled() }
    public func designComputedFacts(ctx: UiContext): Array<DesignComputedFact> { child.designComputedFacts(ctx) }
}

protected func applyKeyboardCapture(widget: Widget, handler: (UiContext, UiEvent) -> Bool): Widget {
    let replacement = KeyboardCaptureWidget(widget, handler)
    replaceLastEmission(widget, replacement)
    replacement
}
