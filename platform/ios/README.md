# iOS Host Bootstrap

CangHui embeds its platform-neutral host contracts into an Xcode application as a Cangjie static library. The platform host may be Objective-C, Objective-C++ or Swift; no handwritten C shim is required. Calls from native threads must still enter through the Cangjie N2C foreign-thread gate after runtime and package initialization.

## Build

Use a Cangjie SDK that contains `ios_aarch64_cjnative` and `ios_simulator_aarch64_cjnative` targets:

```bash
export CANGJIE_HOME=/path/to/cangjie-ios-sdk
./scripts/build-ios-host-staticlibs.sh
```

The default output is ignored under `target/ios-host/`:

- `libcanghui_host_ios.a`
- `libcanghui_host_ios_simulator.a`

The build also emits `libcangjiegui_host_ios*.a` compatibility aliases for existing hosts.

Pass `device` or `simulator` as the first argument to build one target. The second argument overrides the output directory.

## Xcode Link Contract

For the selected device or simulator target:

1. Add the generated CangHui archive and every `.a` file from `$CANGJIE_HOME/lib/<target-runtime>/` to the application target.
2. Add `section.o`, then `cjstart.o`, then `-lc++` to Other Linker Flags in that exact order.
3. Set Dead Code Stripping to `No`.
4. With Xcode 15 or later, add `-Wl,-no_compact_unwind` when the linker reports compact-unwind overflow.
5. Include `platform/ios/include/CangHuiHost.h`. Do not call the exported function as an ordinary C function from an arbitrary UIKit thread; initialize the Cangjie runtime, establish the fixed scheduler thread, complete static-package initialization and invoke through the N2C foreign-thread gate.

The current device probe proves runtime initialization, a fixed background UI scheduler and an N2C call into a minimal Cangjie static package. The CangHui package call is still blocked in static-package initialization, so ABI version `1` has not yet been observed on device.

## Surface Proxy

The iOS backend follows an XComponent-like proxy model:

- UIKit owns a `UIView` backed by `CAMetalLayer` or `MTKView`.
- UIKit forwards lifecycle, safe-area, touch, IME, accessibility, surface-generation and `CADisplayLink` events.
- `HostNativeSurfaceService` publishes the host-owned surface descriptor.
- `NativeSurfaceRenderer` keeps layout, state and drawing on the Cangjie side.
- Native callbacks are marshalled through N2C onto the fixed Cangjie scheduler thread.

The host still owns signing and packaging. The proxy contract does not by itself initialize the runtime, static package or renderer.

## Host Modes

- `OwnedWindow` follows SDL3's callback application model. SDL owns the iOS
  window, event pump and renderer; this is preferred for a standalone app.
- `EmbeddedSurface` keeps the UIKit `CAMetalLayer/MTKView` proxy described
  above; this is preferred when CangHui is one surface inside an existing
  application.

Both modes require a launch screen, high-pixel-density configuration, bundled
resources and correctly embedded or statically linked dependencies. The
current package-initialization blocker applies to both modes.
