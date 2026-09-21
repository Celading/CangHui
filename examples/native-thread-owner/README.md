# Native thread owner (macOS)

Run `cjpm run`; the window closes after five asynchronous results. `--implicit` tests
automatic window-lifetime binding without an entry lease; `--throw` verifies original
exception preservation and owner-thread cleanup. `python3 verify.py --output <new-directory>`
performs 20 normal cold starts and two throwing runs without a processor-count override.

`DesktopApp` / `SdlRuntime` automatically hold a native-thread lease on macOS until native
shutdown. If startup suspends **before** constructing the first window, acquire
`DesktopThreadLease` at the beginning of `main` and keep it until all windows are closed.
It pins the current Cangjie thread, not all workers. Send prepared background results through
`postToUi`; never share mutable UI state or call window methods from a worker.

The macOS adapter uses CJNative's internal `CJ_BindOSThread` / `CJ_UnbindOSThread` C ABI.
It is not a supported std API; 1.0.5 and 1.1.3 symbol availability is checked, and the
native replay targets 1.1.3. New runtimes require this replay before support is claimed.
External bindings are rejected rather than unbound without ownership. Other platforms retain
their previous host contract; this macOS example is not Windows/Harmony runtime proof.
Do not globally set `cjProcessorNum=1` as a product fix.

This fixture does not access saved credentials or connect to business services. OS file-dialog
completion/cancellation must additionally be exercised in the consumer application.
