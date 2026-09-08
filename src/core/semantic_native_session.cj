package chui.core

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex

/** Native identity within ONE adapter instance; 1 is reserved for its synthetic window root. */
public struct SemanticNativeBinding {
    public let semanticId: String
    public let nativeId: UInt64
    public let parentNativeId: UInt64

    public init(semanticId: String, nativeId: UInt64, parentNativeId: UInt64) {
        this.semanticId = semanticId
        this.nativeId = nativeId
        this.parentNativeId = parentNativeId
    }
}

/** A detached semantic frame and its native identities, always from the same revision. */
public struct SemanticNativeSnapshot {
    public let tree: SemanticTreeSnapshot
    public let bindings: Array<SemanticNativeBinding>

    internal init(tree: SemanticTreeSnapshot, bindings: Array<SemanticNativeBinding>) {
        this.tree = SemanticTreeSnapshot(tree.windowId, tree.revision, tree.nodes)
        this.bindings = bindings.clone()
    }

    public func binding(id: String): ?SemanticNativeBinding {
        for (value in bindings) { if (value.semanticId == id) { return Some(value) } }
        None
    }
}

/**
 * Per-window native-adapter identity/lifetime bridge, NOT a platform accessibility provider.
 *
 * The UI owner publishes committed SemanticRuntime snapshots and closes the session. Native
 * callback threads can read detached views or enqueue typed actions into the existing owner queue.
 * IDs survive reorder/reparent but are never recycled after removal or a role/widget-type change.
 * One session belongs to one native adapter instance; never share its callbacks across windows.
 */
public class SemanticNativeSession {
    public let windowId: String
    private let mutex = Mutex()
    private var closed = false
    private var nextId = UInt64(1)
    private var current: ?SemanticNativeSnapshot = None

    public init(windowId: String) {
        let _ = SemanticTreeSnapshot(windowId, UInt64(0), [])
        this.windowId = windowId
    }

    /** Rejects stale, foreign or malformed input without changing the previous published frame. */
    public func publish(tree: SemanticTreeSnapshot): Unit {
        let owned = SemanticTreeSnapshot(tree.windowId, tree.revision, tree.nodes)
        synchronized(mutex) {
            if (closed) { throw IllegalStateException("native semantic session is closed") }
            if (owned.windowId != windowId || owned.revision == UInt64(0)) {
                throw IllegalArgumentException("native semantic frame must have the matching window and a committed revision")
            }
            if (let Some(previous) <- current) {
                if (owned.revision <= previous.tree.revision) {
                    throw IllegalArgumentException("native semantic revision must advance")
                }
            }
            validateNativeSemanticParents(owned)
            let previousNodes = HashMap<String, SemanticNode>()
            let previousIds = HashMap<String, UInt64>()
            if (let Some(previous) <- current) {
                for (node in previous.tree.nodes) { previousNodes[node.id] = node }
                for (binding in previous.bindings) { previousIds[binding.semanticId] = binding.nativeId }
            }
            let ids = HashMap<String, UInt64>()
            var allocated = nextId
            for (node in owned.nodes) {
                var retained: ?UInt64 = None
                if (let Some(before) <- previousNodes.get(node.id)) {
                    if (before.role == node.role && before.widgetType == node.widgetType) {
                        retained = previousIds.get(node.id)
                    }
                }
                let id = match (retained) {
                    case Some(value) => value
                    case None =>
                        if (allocated == UInt64.Max) {
                            throw IllegalStateException("native semantic identity space exhausted")
                        }
                        allocated += UInt64(1)
                        allocated
                }
                ids[node.id] = id
            }
            let bindings = ArrayList<SemanticNativeBinding>()
            for (node in owned.nodes) {
                let parent = if (node.parentId.isEmpty()) { UInt64(1) } else { ids[node.parentId] }
                bindings.add(SemanticNativeBinding(node.id, ids[node.id], parent))
            }
            current = Some(SemanticNativeSnapshot(owned, bindings.toArray()))
            nextId = allocated
        }
    }

    /** None before first publication or after close; returned arrays never alias session state. */
    public func snapshot(): ?SemanticNativeSnapshot {
        synchronized(mutex) {
            match (current) {
                case Some(value) => Some(SemanticNativeSnapshot(value.tree, value.bindings))
                case None => None
            }
        }
    }

    /**
     * Native callback ingress. Validation happens again when the existing UI owner drains, so an
     * action queued before a frame change/removal/close cannot be rebound to the replacement.
     * The handler runs outside this session's lock; it must dispatch through SemanticRuntime,
     * whose window/revision/source/declared-action policy remains the final authority.
     */
    public func postAction(
        queue: UiOwnerQueue,
        nativeId: UInt64,
        observedRevision: UInt64,
        action: SemanticActionKind,
        handler: SemanticNativeActionHandler
    ): UiOwnerTicket {
        queue.post({=>
            let request = resolveAction(nativeId, observedRevision, action)
            match (request) {
                case Some(value) => handler(value)
                case None => throw IllegalStateException("native semantic action is stale, unsupported or closed")
            }
        })
    }

    /** Owner-side close is terminal. Already queued actions fail when drained. */
    public func close(): Unit {
        synchronized(mutex) { closed = true; current = None }
    }

    private func resolveAction(nativeId: UInt64, revision: UInt64, action: SemanticActionKind): ?SemanticActionRequest {
        synchronized(mutex) {
            if (closed) { return None }
            let frame = match (current) { case Some(value) => value; case None => return None }
            if (frame.tree.revision != revision) { return None }
            for (binding in frame.bindings) {
                if (binding.nativeId != nativeId) { continue }
                let node = frame.tree.node(binding.semanticId).getOrThrow()
                if (!node.enabled || (node.readOnly && semanticActionName(action) != "focus")) { return None }
                for (allowed in node.actions) {
                    if (semanticActionName(allowed) == semanticActionName(action)) {
                        return Some(SemanticActionRequest(windowId, revision, node.id, action,
                            SemanticActionSource.Accessibility))
                    }
                }
                return None
            }
            None
        }
    }
}

public type SemanticNativeActionHandler = (SemanticActionRequest) -> Unit

private func validateNativeSemanticParents(tree: SemanticTreeSnapshot): Unit {
    let parents = HashMap<String, String>()
    for (node in tree.nodes) { parents[node.id] = node.parentId }
    for (node in tree.nodes) {
        var ancestor = node.parentId
        var depth: Int64 = 0
        while (!ancestor.isEmpty()) {
            depth += 1
            if (depth > SEMANTIC_RUNTIME_HARD_MAX_DEPTH || ancestor == node.id) {
                throw IllegalArgumentException("native semantic tree has a cycle or exceeds the depth limit")
            }
            ancestor = match (parents.get(ancestor)) {
                case Some(value) => value
                case None => throw IllegalArgumentException("native semantic parent is missing")
            }
        }
    }
}
