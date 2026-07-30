# CangHui CLI

`cuic` is the integrated, Cangjie-built lifecycle CLI for CangHui framework development and generated applications.
It lives under `tools/cuic`; the former standalone layout remains a compatibility source only.

```bash
cjpm build
./bin/cuic doctor macos
```

`bin/cuic` and `bin\\cuic.ps1` are thin launchers. Command parsing and lifecycle orchestration live in
the compiled Cangjie executable under `src/`.

## Commands

```text
cuic init <directory> [--name <package>] [--platform <platform>] [--canghui-path <path>]
cuic doctor [platform]
cuic bootstrap [platform]
cuic font <status|install> [platform]
cuic kmode diff [project]
cuic kmode list [project]
cuic kmode describe [project] <endpoint>
cuic kmode call [project] <endpoint> [payload]
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example]
cuic prnt [platform] [project|example] [--output <file.bmp|file.png>]
cuic clean [project]
cuic examples
cuic version
```

On macOS and Linux use `bin/cuic`. On Windows use `bin\\cuic.cmd` or `bin\\cuic.ps1`.

## Framework Resolution

`cuic` resolves CangHui in this order:

1. the repository that owns the integrated `tools/cuic` command
2. the target project's local `cui = { path = "..." }` dependency
3. `CANGHUI_FRAMEWORK_ROOT`, then the legacy `CANGUI_FRAMEWORK_ROOT`
4. a sibling `CangHui/`, then the legacy `CangjieGUI/` alias

## Initialization

`init` creates a minimal executable Cangjie application with a local CUI dependency, source entrypoint,
Git ignore file, and target-platform handoff commands.

```bash
./bin/cuic init ../HelloCangHui --name hello_canghui --platform macos
./bin/cuic build macos ../HelloCangHui
./bin/cuic run macos ../HelloCangHui
```

The generated path dependency is suitable for local development. A hosted dependency or vendored CUI
copy should replace it before publishing the generated application independently.

## kMode Headless Control

`cuic kmode` invokes CangHui functions without opening a window or traversing the layout tree. Applications
register a top-level `(String) -> String` function with `@KModeLink["stable.endpoint"]` and call
`runKModeStdioIfRequested()` before constructing `DesktopApp`.

```bash
./bin/cuic kmode diff component-gallery
./bin/cuic kmode list component-gallery
./bin/cuic kmode describe component-gallery gallery.viewport.class
./bin/cuic kmode call component-gallery gallery.viewport.class 800
```

`diff` scans the project and recursive local path dependencies. `build`, `test`, and `run` execute the same
preflight automatically. Duplicate names report every source location; the macro-generated symbol and runtime
registry remain additional fail-closed layers.

The CLI sets `CANGHUI_KMODE=1` and `CANGHUI_KMODE_TRANSPORT=stdio` only for the supervised child process.
It does not provide arbitrary shell execution. Optional SoonLink Channel persistence belongs in an external
`KModeChannelModule` implementation; URLs, claim tokens and sessions are not CLI configuration.

## Platform Matrix

| Platform | doctor | bootstrap | build/test/run | Current boundary |
|---|---:|---:|---:|---|
| macOS | yes | Cangjie-managed Homebrew SDL copy | native host | current arm64 host proven |
| Windows | yes | bundled DLL check | native host | structural preservation; run on Windows for runtime proof |
| Linux | yes | Cangjie-managed pkg-config SDL copy | native host | implementation present; Linux host proof pending |
| Android | diagnostic | no | no | backend, NDK bridge, APK packaging and runner not implemented |

The CLI intentionally rejects unconfigured cross-host builds and unsupported Android execution.

## Fonts

CangHui owns the unmodified HarmonyOS Sans asset and license. `font install` remains an optional compatibility
command; normal rendering uses the framework-owned bundled fallback without requiring host installation.

Recommended macOS installation:

```bash
./bin/cuic font status macos
./bin/cuic font install macos
./bin/cuic font status macos
```

`install` copies the framework-owned font to `~/Library/Fonts/HarmonyOS_Sans_SC.ttf`. Restart running CangHui
applications after installation. Users may instead open the TTF with Font Book or copy it into `~/Library/Fonts/`.

The CLI-owned font is distributed unmodified under the
[HarmonyOS Sans Fonts License Agreement](../../assets/fonts/HARMONYOS_SANS_LICENSE.txt). Its upstream package source is:

```text
https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyManage/011/111/111/0000000000011111111.20260627152129.89276966309836366526585265125586:50001231000000:2800:A0161E048334FE0271F9F5ECBBD5070D17381C7846125F4D7109DBC7B532C715.zip?needInitFileName=true
```

## Window Capture

`prnt` exposes CangHui's renderer-level snapshot instrumentation. The application renders 48 frames,
reads the resolved SDL renderer pixels, writes a BMP, and exits. The CLI can retain BMP or convert it
to PNG with ImageMagick, macOS `sips`, or Windows System.Drawing.

```bash
./bin/cuic prnt macos notepad --output snapshots/notepad.png
./bin/cuic prnt macos ../HelloCangHui -o snapshots/hello.bmp
```

This captures the application render surface rather than the surrounding desktop and does not require
the operating system's screen-recording permission.
