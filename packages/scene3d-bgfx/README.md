# CangHui Scene3D bgfx4cj Provider

Optional `Scene3DDriver` implementation backed by
[`bgfx4cj`](https://gitcode.com/Cangjie-TPC/bgfx4cj).

The package keeps bgfx handles and CFFI objects outside application code. A
platform host supplies the native window pointer and its matching serializable
surface identity when constructing `Bgfx4cjDriver`; applications use CangHui
`Scene3DProvider` contracts. The driver rejects an attach when that identity
does not match `Scene3DHostSurface.opaqueHandle`.

Current scope includes provider lifecycle, immutable backend-bound shader and
indexed-geometry resources, perspective/depth state, and a bounded semantic
debug scene. `Scene3DEntityKind` maps floor, route, vehicle and user-marker
snapshots onto slab, ribbon, box and marker families with stable provider-owned
colors. Identity, position and visibility stay in the sealed frame snapshot;
product models and styling do not enter this package. Model/texture ingestion,
picking and platform runtime certification remain separate work.

On macOS, `MacOSSdlMetalHost` owns an SDL3 Metal window and extracts its native
`NSWindow` for the provider. `Bgfx4cjDriver` selects bgfx single-thread mode
before Metal initialization, avoiding a main-runloop initialization deadlock.
The `scene3d-bgfx-metal-capture` example accepts `DesktopCaptureRequest` from
`cuic prnt`, uploads semantic vertex buffers plus one shared index topology and
Metal shader program, renders the four generic entity classes, requests a
renderer backbuffer screenshot, and converts bgfx's 32-bit TGA output to the
BMP capture contract before `cuic` emits PNG. Verification checks both native
API receipts and bounded non-background pixels, so an accepted but uniform
frame is rejected.

The bounded macOS verification expects external source and archive locations:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/native-archives \
./scripts/verify-scene3d-bgfx-metal-capture.sh \
  /tmp/scene3d-metal.png \
  /tmp/scene3d-native-supply.json
```

The archive directory must contain `libbgfx.a`, `libbimg.a` and `libbx.a` built
for the frozen macOS arm64 Metal/Noop contract. Before linking, the verifier
checks the exact bgfx4cj revision, archive SHA-256 digests, architecture,
deployment metadata and renderer symbols. It emits a path-free
`canghui.scene3d-bgfx-native-supply-receipt.v1` receipt.

All source and CJPM link settings are staged in a disposable directory. The
verification does not rewrite CangHui or bgfx4cj manifests and lock files. The
frozen receipt is current-host evidence, not a portable binary release or a
complete macOS 12 application-runtime claim.

To reproduce the current-host archives from the pinned source checkout, use a
new empty output directory:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
./scripts/build-scene3d-bgfx-native-supply.sh \
  /tmp/canghui-bgfx-native
```

The build recipe freezes arm64, macOS 12, Metal plus Noop, the required ASTC
sources and Objective-C message-send setting. A build is accepted only when its
archives pass the same contract and receipt verifier; a different toolchain or
source result is rejected rather than silently promoted.

This package is Apache-2.0. Its `bgfx4cj` dependency is MIT-licensed and retains
its own upstream notices and dependency obligations.
