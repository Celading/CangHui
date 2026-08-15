# Android Native Surface First Slice

This directory contains the Android-specific CangHui host bootstrap. It owns a
minimal Activity lifecycle plus the `SurfaceView` to JNI to `ANativeWindow`
boundary. It does not contain APK packaging, SDL integration, a renderer, or a
Cangjie runtime bridge.

## Contract

`CangHuiNativeSurfaceHost` registers as a `SurfaceHolder.Callback2` and keeps
the native window behind an opaque handle. Every successful attach and detach
advances a monotonic generation. A detach callback must present the generation
returned by its attach; a stale callback cannot release a newer native window.

The native side owns each `ANativeWindow_fromSurface` reference until it is
replaced, detached, or destroyed. Width and height queries are synchronized
with the same owner state.

`CangHuiSurfaceActivity` creates the host and `SurfaceView` in `onCreate`, binds
callbacks in `onStart`, detaches in `onStop`, and closes the native owner in
`onDestroy`. Applications may subclass it and use the protected accessors, but
they still own manifest declaration, packaging, theme, input, IME and renderer
integration.

## Static Proof

The proof uses an independent output directory and does not start an emulator
or use a connected device:

```bash
./scripts/build-android-native-surface.sh /private/tmp/canghui-android-surface
./scripts/verify-android-toolchain.sh
```

`verify-android-toolchain.sh --require-cangjie` additionally requires a
Cangjie Android cross-compilation SDK. A normal macOS Cangjie SDK is not
sufficient: the Android SDK must provide
`modules/linux_android_aarch64_cjnative` and matching Android runtime
libraries.

## Open Work

- Freeze the shared Cangjie-to-Android host ABI in a separate integration change.
- Cross-compile the CangHui Cangjie package with the Android Cangjie SDK.
- Bind the generation-safe native surface to SDL or another renderer owner.
- Add input, IME, accessibility, APK packaging, signing, install, launch, and
  device proof.

This slice proves only Android NDK and Java compilation plus bytecode-level
Activity lifecycle ownership of the native-surface boundary. It is not Android
runtime support.
