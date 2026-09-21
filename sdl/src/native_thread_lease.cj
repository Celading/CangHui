package sdl

// Runtime adapter, not a public std API. ABI verified against CJNative 1.0.5/1.1.3.
// Keep isolated so a future supported runtime API can replace it without app changes.
@When[os == "macOS"]
foreign {
    func CJ_BindOSThread(): Int32
    func CJ_UnbindOSThread(): Int32
    func pthread_main_np(): Int32
}

private let desktopThreadDepth = ThreadLocal<Int64>()

/**
 * macOS desktop-owner scope. Enter on the native main thread before suspending startup
 * work; close on the same Cangjie thread after all windows close. Nested leases are safe.
 * Other platforms currently retain their existing native host contract.
 */
public class DesktopThreadLease <: Resource {
    private let owner = Thread.currentThread.id
    private var closed = false

    public init() {
        acquireDesktopThread()
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (closed) { return }
        if (Thread.currentThread.id != owner) {
            throw IllegalStateException("desktop thread lease must close on its creating Cangjie thread")
        }
        releaseDesktopThread()
        closed = true
    }
}

@When[os == "macOS"]
private func acquireDesktopThread(): Unit {
    let depth = desktopThreadDepth.get() ?? 0
    if (depth == 0) {
        if (unsafe { CJ_BindOSThread() } != 0) {
            throw IllegalStateException("cannot acquire desktop native-thread binding; external binding is not owned by CangHui")
        }
        if (unsafe { pthread_main_np() } != 1) {
            let _ = unsafe { CJ_UnbindOSThread() }
            throw IllegalStateException("macOS desktop must start on the native main thread; acquire DesktopThreadLease at main entry before blocking startup")
        }
    }
    desktopThreadDepth.set(depth + 1)
}

@When[os == "macOS"]
private func releaseDesktopThread(): Unit {
    let depth = desktopThreadDepth.get() ?? 0
    if (depth <= 0) { throw IllegalStateException("desktop thread lease underflow") }
    if (depth == 1 && unsafe { CJ_UnbindOSThread() } != 0) {
        throw IllegalStateException("cannot release desktop native-thread binding")
    }
    desktopThreadDepth.set(depth - 1)
}

@When[os != "macOS"]
private func acquireDesktopThread(): Unit {}

@When[os != "macOS"]
private func releaseDesktopThread(): Unit {}
