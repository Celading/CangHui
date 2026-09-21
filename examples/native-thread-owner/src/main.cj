package native_thread_owner

import chui.*
import std.env.getCommandLine

foreign func pthread_self(): UInt64
foreign func pthread_main_np(): Int32

func check(owner: UInt64, phase: String): Unit {
    let actual = unsafe { pthread_self() }
    let mainThread = unsafe { pthread_main_np() }
    if (actual != owner || mainThread != 1) { throw Exception("owner mismatch: ${phase}") }
    println("owner=${actual} main=${mainThread} phase=${phase}")
}

main(): Unit {
    if (getCommandLine().contains("--implicit")) { runCase(false); return }
    // Entry lease also protects blocking initialization BEFORE constructing DesktopApp.
    try (entry = DesktopThreadLease()) {
        if (getCommandLine().contains("--dialog")) { dialogCase(); return }
        // A worker must not be able to release another thread's owned binding.
        let wrongClose = spawn {
            try { entry.close(); false }
            catch (_: IllegalStateException) { true }
        }
        if (!wrongClose.get()) { throw Exception("wrong-owner close accepted") }
        try (nested = DesktopThreadLease()) { sleep(Duration.millisecond) }
        runCase(true)
    }
}

func dialogCase(): Unit {
    let owner = unsafe { pthread_self() }
    let app = DesktopApp(WindowSpec("Native dialog owner regression", 400, 240, supersample: 1))
    let request = app.openFileDialog(options: FileDialogOptions(defaultLocation: Some("/private/tmp/")))
    app.run {
        FrameHandler(onFrame: {_ =>
            check(owner, "dialog-frame")
            match (request.result()) {
                case FileDialogResult.FileDialogPending => ()
                case FileDialogResult.FileDialogCanceled =>
                    println("native-dialog-canceled"); app.requestWindowClose()
                case FileDialogResult.FileDialogSelected(paths, _) =>
                    println("native-dialog-selected count=${paths.size}"); app.requestWindowClose()
                case FileDialogResult.FileDialogFailed(message) => throw Exception(message)
            }
        }) { Label("Choose a temporary fixture or cancel. No file contents are read.") }
    }
    check(owner, "dialog-destroyed")
}

func runCase(early: Bool): Unit {
        let owner = unsafe { pthread_self() }
        check(owner, "entry")
        if (early) {
            let startup = spawn { sleep(5 * Duration.millisecond); 42 }
            if (startup.get() != 42) { throw Exception("startup result") }
            check(owner, "startup-result")
        }
        let app = DesktopApp(WindowSpec("Native owner regression", 400, 240, supersample: 1))
        check(owner, "created")
        let state = State<Int64>(0)
        let fail = getCommandLine().contains("--throw")
        let worker = spawn {
            for (i in 1..6) {
                sleep(25 * Duration.millisecond)
                let value = i
                let _ = app.postToUi({ =>
                    check(owner, "async-${value}")
                    state.value = value
                    if (value == 5) { app.requestWindowClose() }
                })
            }
        }
        try {
            app.run {
                // Force scheduler suspension inside the UI callback, not just before run.
                sleep(Duration.millisecond)
                check(owner, "build-${state.value}")
                if (fail) { throw Exception("owner-primary-test") }
                Label("Background result: ${state.value}")
            }
        } catch (error: Exception) {
            if (!fail || error.message != "owner-primary-test") { throw error }
            println("primary-exception-preserved")
        }
        // Native resources have closed before app.run returns. Implicit ownership has
        // also unbound by now, so only the explicit entry scope promises affinity here.
        if (early) { check(owner, "destroyed") }
        worker.get()
}
