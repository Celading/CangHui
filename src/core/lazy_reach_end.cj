package chui.core

// Retained by the list identity. Claim before calling user code to make reentrant frames safe.
class LazyReachEndGate {
    private var count: Int64 = -1
    private var revision: Int64 = 0
    private var delivered = false
    private var pending = false

    func schedule(count: Int64, revision: Int64, near: Bool, loading: Bool, hasMore: Bool): Bool {
        if (this.count != count || this.revision != revision || !near) {
            delivered = false
        }
        this.count = count
        this.revision = revision
        pending = near && hasMore && !loading && !delivered
        pending
    }

    func take(count: Int64, revision: Int64, loading: Bool, hasMore: Bool): Bool {
        let allowed = pending && !loading && hasMore && this.count == count && this.revision == revision
        pending = false
        if (allowed) { delivered = true }
        allowed
    }
}
