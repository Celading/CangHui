package chui.core

/** Only this wrapper opts into StateStore disposal; shared State values stay borrowed. */
internal class RememberedUiTaskScope {
    let scope: UiTaskScope
    private let queue: UiOwnerQueue
    private let policyName: String

    init(key: String, queue: UiOwnerQueue, policy: UiTaskPolicy) {
        this.queue = queue
        this.policyName = uiTaskPolicyName(policy)
        this.scope = UiTaskScope(key, queue, policy: policy)
    }

    func reuse(queue: UiOwnerQueue, policy: UiTaskPolicy): UiTaskScope {
        if (!refEq((this.queue as Object).getOrThrow(), (queue as Object).getOrThrow()) ||
            policyName != uiTaskPolicyName(policy)) {
            throw IllegalStateException("Remembered task scope changed owner queue or policy; use a new key")
        }
        scope
    }
}

/**
 * Remembers a view-owned task scope in the active Keyed/StateStore identity.
 * Successful unmount, rollback of a newly created entry, or store clear closes it.
 * A cancelled retained frame does not close scopes from the last committed tree.
 * Queue and policy must stay stable for a key. The shared queue is never closed.
 */
public func rememberUiTaskScope(key: String, queue: UiOwnerQueue,
    policy!: UiTaskPolicy = UiTaskPolicy.LatestOnly): UiTaskScope {
    currentStateStore().rememberTaskScope(key, queue, policy)
}
