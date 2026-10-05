package sdl

// Windows tests can bind any native thread. macOS tests run on the test runner's
// workers, so its native-main-thread requirement is exercised by the desktop example.
@When[os == "Windows"]
@Test
func windowsDesktopLeaseSurvivesSuspensionAndNestedRelease(): Unit {
    let outer = DesktopThreadLease()
    let owner = unsafe { SDL_GetCurrentThreadID() }
    try {
        try (inner = DesktopThreadLease()) {
            for (_ in 0..20) {
                let value = spawn { 42 }
                @Expect(value.get(), 42)
                sleep(Duration.millisecond)
                @Expect(unsafe { SDL_GetCurrentThreadID() }, owner)
            }
        }
        sleep(Duration.millisecond)
        @Expect(unsafe { SDL_GetCurrentThreadID() }, owner)
        let refused = spawn {
            try { outer.close(); false } catch (_: IllegalStateException) { true }
        }
        @Expect(refused.get())
        @Expect(!outer.isClosed())
    } finally { outer.close() }
    @Expect(outer.isClosed())
    outer.close()
    try (again = DesktopThreadLease()) { @Expect(!again.isClosed()) }
}

@When[os == "Windows"]
@Test
func windowsDesktopLeaseDoesNotTakeOverExternalBinding(): Unit {
    @Expect(unsafe { CJ_BindOSThread() }, Int32(0))
    try {
        var rejected = false
        try { let lease = DesktopThreadLease(); lease.close() }
        catch (_: IllegalStateException) { rejected = true }
        @Expect(rejected)
    } finally { @Expect(unsafe { CJ_UnbindOSThread() }, Int32(0)) }
    try (lease = DesktopThreadLease()) { @Expect(!lease.isClosed()) }
}
