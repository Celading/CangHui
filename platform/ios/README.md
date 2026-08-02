# iOS Host Bootstrap

CangHui embeds its platform-neutral host contracts into an Xcode application as
a Cangjie static library. The platform host may be Objective-C,
Objective-C++ or Swift. Applications use the supplied Objective-C bootstrap
helper instead of writing a separate C shim or calling an `@C` symbol directly
from an arbitrary UIKit thread.

## Build

Use a Cangjie SDK that contains `ios_aarch64_cjnative` and
`ios_simulator_aarch64_cjnative` targets:

```bash
export CANGJIE_HOME=/path/to/cangjie-ios-sdk
./scripts/build-ios-host-staticlibs.sh
```

The default output is ignored under `target/ios-host/`:

- `libcanghui_host_ios.a`
- `libcanghui_host_ios_simulator.a`

The build also emits `libcangjiegui_host_ios*.a` compatibility aliases for
existing hosts. Pass `device` or `simulator` as the first argument to build one
target. The second argument overrides the output directory.

The iOS static package is compiled with `-O2`. This is part of the tested
bootstrap contract for Cangjie `1.3.0-alpha.20260725010033`: its unoptimized
static-package safepoint stub does not return to the original call site, while
the optimized form keeps the safepoint slow path local to the function.

## Xcode Link Contract

For the selected device or simulator target:

1. Add the generated CangHui archive.
2. Add `section.o`, then `cjstart.o`, from the matching Cangjie runtime target.
3. Link the Cangjie runtime and required standard-library archives. The
   repository probe uses `std-collection`, `std-math`, `std-core`, `runtime`,
   `boundscheck-static` and `cangjie-thread`; adding every `.a` from the matching
   runtime directory follows the broader toolchain guidance.
4. Link UIKit, Foundation and `libc++`.
5. Set Dead Code Stripping to `No`.
6. With Xcode 15 or later, add `-Wl,-no_compact_unwind` when required by the
   linker.
7. Add `platform/ios/bootstrap/CangHuiRuntimeBootstrap.m` to the native target
   and expose `platform/ios/include` as a header search path.

The target runtime must match the application destination:

- device: `$CANGJIE_HOME/lib/ios_aarch64_cjnative`
- Apple Silicon simulator:
  `$CANGJIE_HOME/lib/ios_simulator_aarch64_cjnative`

## Runtime Bootstrap

Include `CangHuiRuntimeBootstrap.h` and `CangHuiHost.h`. Start the runtime from a
background queue using the executable basename registered in the final app,
then enter exported Cangjie functions through `canghui_runtime_run_task`:

```objective-c
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    const char *name =
        NSBundle.mainBundle.executableURL.lastPathComponent.UTF8String;
    CangHuiRuntimeBootstrapResult bootstrap =
        canghui_runtime_bootstrap_start(name, 5000000000LL);
    CangHuiRuntimeTaskResult task =
        canghui_runtime_run_task(my_cangjie_entry, NULL, 5000000000LL);
});
```

The helper performs the process-wide sequence:

1. `InitCJRuntime`;
2. fixed scheduler creation with `InitUIScheduler` and `RunUIScheduler`;
3. `InitCJLibrary` using the final executable basename;
4. foreign-thread invocation with `RunCJTask` and bounded result wait.

`InitCJLibraryStub` is not a package initializer and is not used by this path.
The bootstrap start function is process-wide; later calls return the first
result. Application code should initialize it once before renderer startup.

## Replayable Probe

The repository probe recompiles the Cangjie static library, compiles the native
helper and UIKit app, links the final executable, installs it and requires this
exact result:

```text
CANGHUI_IOS_PROBE result runtime=0 scheduler=ready library=0 task=0 abi=1
```

Run the simulator acceptance with no signing configuration:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/verify-ios-static-package.sh simulator
```

The script uses a booted simulator, or boots the first available simulator when
none is running. Set `CANGHUI_IOS_SIMULATOR_DEVICE` to a name or identifier to
select one explicitly.

Physical-device acceptance requires values owned by the local developer
environment; none are stored in the repository:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
CANGHUI_IOS_DEVICE=<device-name-or-id> \
CANGHUI_IOS_BUNDLE_ID=<profile-bundle-id> \
CANGHUI_IOS_CODESIGN_IDENTITY=<identity-name-or-sha> \
CANGHUI_IOS_PROVISIONING_PROFILE=/path/to/profile.mobileprovision \
    ./scripts/verify-ios-static-package.sh device
```

The device must be unlocked. The script validates the provisioning profile
against the requested bundle id before signing and installing the app.

## Surface Proxy

The iOS backend follows an XComponent-like proxy model:

- UIKit owns a `UIView` backed by `CAMetalLayer` or `MTKView`.
- UIKit forwards lifecycle, safe-area, touch, IME, accessibility,
  surface-generation and `CADisplayLink` events.
- `HostNativeSurfaceService` publishes the host-owned surface descriptor.
- `NativeSurfaceRenderer` keeps layout, state and drawing on the Cangjie side.
- Native callbacks are marshalled through the runtime task gate onto the fixed
  Cangjie scheduler thread.

The host still owns signing and packaging. Successful bootstrap and ABI return
do not implement this renderer adapter by themselves.

## Host Modes

- `OwnedWindow` follows SDL3's callback application model. SDL owns the iOS
  window, event pump and renderer; this is preferred for a standalone app.
- `EmbeddedSurface` keeps the UIKit `CAMetalLayer/MTKView` proxy described
  above; this is preferred when CangHui is one surface inside an existing
  application.

Both modes require a launch screen, high-pixel-density configuration, bundled
resources and correctly embedded or statically linked dependencies. Current
device and simulator proof covers runtime, scheduler, static-package
initialization, N2C task entry and ABI return only. Lifecycle adapters, native
surface rendering, input, IME, accessibility and product acceptance remain
separate platform work.
