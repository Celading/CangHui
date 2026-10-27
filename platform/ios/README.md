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
   repository probe uses `std-collection`, `std-math`, `std-sync`, `std-time`,
   `std-binary`, `std-convert`, `std-io`, `std-core`, `runtime`,
   `boundscheck-static` and `cangjie-thread`; adding every `.a` from the matching
   runtime directory follows the broader toolchain guidance.
4. Link UIKit, Foundation, QuartzCore, Metal and `libc++`.
5. Set Dead Code Stripping to `No`.
6. With Xcode 15 or later, add `-Wl,-no_compact_unwind` when required by the
   linker.
7. Add `platform/ios/bootstrap/CangHuiRuntimeBootstrap.m` and the Objective-C
   sources under `platform/ios/runtime` to the native target, then expose
   `platform/ios/include` as a header search path.

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
helper and UIKit app, links the final executable, installs it and requires both
the happy-path surface result and the negative/counterexample result:

```text
CANGHUI_IOS_NEGATIVE result passed=1 stale_resize=-2 stale_touch=-2 stale_pointer=-2 stale_frame=-2 invalid_handle=-1 future_frame=0 stale_future_frame=-3
CANGHUI_IOS_SURFACE result passed=1 negative=ready metal=ready drawable=ready attached=1 attaches=2 resizes=2 detaches=1 generation=2 frames=<positive> touches=1 pointers=1 traits=1
```

The negative line covers stale-generation resize/touch/pointer/frame rejection,
an invalid native handle, a valid future frame, and a non-monotonic frame after
reattachment. A probe that only prints the surface line is not considered passed.

Run the simulator acceptance with no signing configuration:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/verify-ios-static-package.sh simulator
```

The script uses a booted simulator, or boots the first available simulator when
none is running. Set `CANGHUI_IOS_SIMULATOR_DEVICE` to a name or identifier to
select one explicitly. It waits for the simulator system to become ready and
retries the install/launch once when a cold boot wins the race against
SpringBoard; a retry is reported explicitly and is not a code-regression claim.

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

The probe intentionally renders only a Cangjie-selected Metal clear color. Its
high-contrast diagnostic panel remains above the surface and explicitly says
that the CangHui scene is not mounted, so a successful native-surface probe cannot
be mistaken for a product application screen.

## Surface Proxy

The implemented iOS adapter follows an XComponent-like proxy model:

- UIKit owns a `UIView` backed by `CAMetalLayer` or `MTKView`.
- UIKit forwards lifecycle, safe-area, touch, Pencil/indirect-pointer hover,
  trait, surface-generation and `CADisplayLink` events through an integer-only
  C ABI.
- `IOSNativeSurfaceBridge` commits the host-owned surface facts through the
  Cangjie UI-owner queue and rejects stale generations.
- The probe uses the Cangjie-selected clear color for a real Metal clear pass.
- Native callbacks are marshalled through the runtime task gate onto the fixed
  Cangjie scheduler thread.

The host still owns signing and packaging. This proof does not yet connect the
full declarative CangHui scene renderer, IME or accessibility to UIKit.

## Native Scene Static Package

Embedded iOS consumers that need Cangjie-owned product scenes without the
desktop SDL dependency closure can build the focused `chui.native_scene`
package:

```bash
CANGJIE_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/build-ios-native-scene-staticlibs.sh simulator
```

The package emits `canghui.native-scene.v0` Draw IR, bounded hit regions and
press/move/release cancellation without SDL or a C shim. UIKit remains the
pixel presenter. This is a mobile display-list boundary, not a claim that the
desktop `Renderer.recordingHeadless()` archive is link-safe on iOS.

Applications can use `CangHuiNativeSceneSurfaceView` instead of copying the
native presenter. The view accepts one caller-buffer render function and
reuses the framework-owned UIKit/Metal lifecycle, display link and ordered
input path. It paints the native-scene Draw IR with CoreGraphics, resolves
`sf` symbols through SF Symbols and presents the result through the shared
CAMetalLayer. Product state, labels and acceptance receipts stay in the
consumer application.

The render callback uses a two-step event contract: the sizing callback applies
the input event exactly once, while the buffer-copy callback receives the
`none` event and snapshots the resulting state. Render functions must keep a
`none` event side-effect free.

## Product Consumer Sample

`platform/ios/product` is a reference product application shell. It owns the
counter, the input text and the action labels, mounts one
`CangHuiNativeSceneSurfaceView`, and renders its whole screen from the
`chui.native_scene` Draw IR. A tap on the increment button is resolved through
the scene's hit regions, IME text and hardware keys arrive through the shared
UIKit host, and the visible elements are published as accessibility nodes.
The product C ABI lives in `CangHuiProductScene.h` and
`src/native_scene/ios_product_scene.cj`.

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
    ./scripts/verify-ios-static-package.sh product-simulator
```

Device mode uses the same signing and provisioning preflight as the probe:

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
CANGHUI_IOS_DEVICE=<device> \
CANGHUI_IOS_BUNDLE_ID=<profile-bundle-id> \
CANGHUI_IOS_CODESIGN_IDENTITY=<identity> \
    ./scripts/verify-ios-static-package.sh product-device
```

The run asserts the `CANGHUI_IOS_PRODUCT result passed=1` line together with
presented scene frames, Draw IR command/action counts, the counter transition,
IME text round-trip, key ingress and the accessibility element count. This is a
reference consumer, not a store-distributed product or a release claim.

## Device Classes and Breakpoints

`chui.core.classifyIOSDevice` turns the interface family and logical viewport
into a stable `IOSDeviceProfile`:

- `IPhone` for phone-family viewports;
- `IPhoneDuo` when a phone-family viewport is at least 500 pt on its short edge
  and near-square (the folded/unfolded heuristic);
- `IPadMini` when a pad viewport is below 800 pt on its short edge;
- `IPadLarge` otherwise.

The profile also carries a width breakpoint (`Compact` below 600 pt, `Medium`
below 1024 pt, `Expanded` above), orientation, recommended column count and a
sidebar hint. Consumers can cache the profile per resize and use it for
navigation shape, column count and spacing instead of hard-coded widths.

The UIKit host publishes the interface family through
`canghui_ios_surface_set_idiom`. Because manually packaged bundles can report
`.unspecified`, the host falls back to the simulator model identifier or
`uname` machine string before the public idiom. The bridge exposes the profile
through `canghui_ios_surface_device_profile` and the probe requires a
`CANGHUI_IOS_PROFILE result passed=1` line.

## iPad Desktop Shell (macOS-style)

`platform/ios/desktop` is a second reference consumer that reproduces the macOS
reading order on iPad: window chrome with traffic lights, a sidebar, a toolbar
with search and a compose button, a "continue playing" hero, a card grid, a
play queue, an inspector and a status bar. Cangjie owns every pixel; UIKit owns
the surface, hover, hardware keys, IME and accessibility.

- `src/native_scene/ios_desktop_scene.cj` — scene state, layout rules and the
  `CangHuiDesktopScene.h` C ABI;
- `platform/ios/desktop/AppDelegate.m` — surface host, safe-area pinning,
  `UIHoverGestureRecognizer`, `pressesBegan/Ended` with modifiers and repeat,
  a hidden text field for IME, five accessibility nodes and the acceptance flow;
- `platform/ios/desktop/Info.plist` — `CangHuiDesktopDemo` / `dev.canghui.desktop.demo`.

Layout follows the device profile instead of fixed widths:

| viewport | panels | sidebar | cards | inspector | queue |
| --- | --- | --- | --- | --- | --- |
| expanded, width >= 1180 pt | three-pane | 252 pt | 3 | visible | visible |
| expanded, narrower | two-pane | 252 pt | 3 | hidden | when it fits |
| medium | two-pane | 208 pt | 2 | hidden | when it fits |
| compact | single pane | hidden | 1 | hidden | when it fits |

```bash
CANGJIE_IOS_HOME=/path/to/cangjie-ios-sdk \
    CANGHUI_IOS_SIMULATOR_DEVICE=<simulator-name-or-id> \
    ./scripts/verify-ios-static-package.sh desktop-simulator
```

Set `SIMCTL_CHILD_CANGHUI_IOS_DESKTOP_ORIENTATION=portrait|landscape` to drive
the acceptance orientation through `requestGeometryUpdate`. The run asserts one
line per configuration; these are the recorded simulator results:

```text
CANGHUI_IOS_DESKTOP result passed=1 layout=two-pane-desktop breakpoint=expanded device=ipad-large orientation=portrait sidebar=1 inspector=0 cards=3 commands=122 actions=17 section=2 play=1 hover=section.3 keys=1 ime=1 a11y=5 frames=3 text_layout=1 last=play.toggle bounds=1032x1327
CANGHUI_IOS_DESKTOP result passed=1 layout=three-pane-desktop breakpoint=expanded device=ipad-large orientation=landscape sidebar=1 inspector=1 cards=3 commands=136 actions=20 section=2 play=1 hover=section.3 keys=1 ime=1 a11y=5 frames=2 text_layout=1 last=play.toggle bounds=1376x983
CANGHUI_IOS_DESKTOP result passed=1 layout=two-pane-desktop breakpoint=medium device=ipad-mini orientation=portrait sidebar=1 inspector=0 cards=2 commands=122 actions=17 section=2 play=1 hover=section.3 keys=1 ime=1 a11y=5 frames=2 text_layout=1 last=play.toggle bounds=744x1084
CANGHUI_IOS_DESKTOP result passed=1 layout=two-pane-desktop breakpoint=expanded device=ipad-mini orientation=landscape sidebar=1 inspector=0 cards=3 commands=109 actions=14 section=2 play=1 hover=section.3 keys=1 ime=1 a11y=5 frames=2 text_layout=1 last=play.toggle bounds=1133x695
```

The scene covers section switching (`⌘1`–`⌘4`), play/pause (`space`), hover
highlighting, search text, card selection and five accessibility nodes.
Screenshots live in `proofs/20261024-canghui-ios-desktop-shell/`; landscape
captures are rotated with `sips` because the simulator framebuffer stays
portrait while the app runs in landscape.

Known gaps are filed as shared broker work requests rather than worked around
silently:

- Framework-level native-scene input ingress is still a follow-up capability;
  every consumer currently re-implements hover, hardware keys and IME.
- Scroll and virtualized-list primitives are still a follow-up capability; the
  queue is hidden when the viewport is too short instead of scrolling.
- The desktop widget tree and `Renderer.recordingHeadless()` are not link-safe
  on iOS, so this shell is a parallel hand-written scene rather than reuse of
  the macOS widget tree.

This is a simulator reference shell. It is not a signed product, a store
distribution, or a claim that the full desktop renderer runs on iOS.

## Host Modes

- `OwnedWindow` follows SDL3's callback application model. SDL owns the iOS
  window, event pump and renderer; this is preferred for a standalone app.
- `EmbeddedSurface` keeps the UIKit `CAMetalLayer/MTKView` proxy described
  above; this is preferred when CangHui is one surface inside an existing
  application.

Both modes require a launch screen, high-pixel-density configuration, bundled
resources and correctly embedded or statically linked dependencies. Current
simulator and device proof covers runtime, scheduler, static-package
initialization, N2C task entry, ABI return, UIKit lifecycle and safe area,
touch, frame clock, generation replay, drawable acquisition, a Metal clear
pass, and the reference product shell's scene rendering, input, IME,
accessibility and text layout. Release signing, store distribution and
long-term support remain separate work.
