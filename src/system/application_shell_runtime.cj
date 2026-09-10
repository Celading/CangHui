package chui.system

import std.collection.ArrayList

/** Optional application-owner lifecycle for native providers. Native callbacks
 * enqueue action IDs; application handlers run only when the owner drains them. */
public interface SystemShellRuntimeProvider {
    func attach(manifest: ApplicationManifest): SystemShellResult
    func nextAction(): ?String
    func detach(): Unit
}

/** One non-reentrant runtime lease; old deterministic providers need no new SPI. */
internal class ApplicationShellRuntime {
    private let provider: SystemShellProvider
    private var attached = false
    private var closed = false
    private var dispatching = false

    init(provider: SystemShellProvider) { this.provider = provider }

    func isClosed(): Bool { closed }

    func attach(manifest: ApplicationManifest): SystemShellResult {
        if (closed) { return SystemShellResult(SystemShellResultStatus.Failed, message: "application shell is closed") }
        if (attached) { return SystemShellResult(SystemShellResultStatus.Applied, message: "application shell already attached") }
        if (let Some(native) <- (provider as SystemShellRuntimeProvider)) {
            let result = native.attach(manifest)
            if (!result.ok()) { return result }
        }
        attached = true
        SystemShellResult(SystemShellResultStatus.Applied, message: "application shell attached")
    }

    func dispatch(limit: Int64, invoke: (String) -> SystemShellResult): Array<SystemShellResult> {
        if (limit < 1 || limit > 256) { throw IllegalArgumentException("shell action limit must be in 1..256") }
        if (!attached || closed || dispatching) { return [] }
        let results = ArrayList<SystemShellResult>()
        dispatching = true
        try {
            if (let Some(native) <- (provider as SystemShellRuntimeProvider)) {
                while (!closed && results.size < limit) {
                    match (native.nextAction()) {
                        case Some(id) => results.add(invoke(id))
                        case None => break
                    }
                }
            }
        } finally { dispatching = false }
        results.toArray()
    }

    func detach(): Unit {
        if (closed) { return }
        closed = true
        if (attached) {
            attached = false
            if (let Some(native) <- (provider as SystemShellRuntimeProvider)) { native.detach() }
        }
    }
}
