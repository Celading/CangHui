# iOS Host Bootstrap

CangjieGUI embeds its platform-neutral host contracts into an Xcode application as a Cangjie static library. The bootstrap surface contains no C source shim: Objective-C, Objective-C++ or Swift hosts call the exported C ABI directly.

## Build

Use a Cangjie SDK that contains `ios_aarch64_cjnative` and `ios_simulator_aarch64_cjnative` targets:

```bash
export CANGJIE_HOME=/path/to/cangjie-ios-sdk
./scripts/build-ios-host-staticlibs.sh
```

The default output is ignored under `target/ios-host/`:

- `libcangjiegui_host_ios.a`
- `libcangjiegui_host_ios_simulator.a`

Pass `device` or `simulator` as the first argument to build one target. The second argument overrides the output directory.

## Xcode Link Contract

For the selected device or simulator target:

1. Add the generated CangjieGUI archive and every `.a` file from `$CANGJIE_HOME/lib/<target-runtime>/` to the application target.
2. Add `section.o`, then `cjstart.o`, then `-lc++` to Other Linker Flags in that exact order.
3. Set Dead Code Stripping to `No`.
4. With Xcode 15 or later, add `-Wl,-no_compact_unwind` when the linker reports compact-unwind overflow.
5. Include `platform/ios/include/CangjieGUIHost.h` and call `cangjiegui_ios_host_abi_version()`. ABI version `1` confirms the Cangjie host-contract package was entered successfully.

The Xcode host still owns application lifecycle delivery, safe-area and touch adapters, UIKit/native-surface integration, signing and packaging. This bootstrap does not initialize a renderer or claim complete iOS GUI support.
