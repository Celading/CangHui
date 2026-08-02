# CangHui CLI

`cuic` is the integrated, Cangjie-built lifecycle CLI for CangHui framework development and generated applications.
It lives under `tools/cuic`; the former standalone layout remains a compatibility source only.

Install only the CLI with a sparse Git fetch:

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Framework contributors can still build and run the integrated command from this checkout:

```bash
cd tools/cuic
cjpm build
./bin/cuic doctor macos --verbose
```

The repository launchers rebuild the integrated binary when `src/` or `cjpm.toml` is newer than the current
binary. An installed `cuic` remains a fixed compiled artifact until it is explicitly reinstalled or upgraded.

`bin/cuic` and `bin\\cuic.ps1` are thin launchers. Command parsing and lifecycle orchestration live in
the compiled Cangjie executable under `src/`.

## Commands

```text
cuic init <directory> [--name <package>] [--platform <platform>]
    [--canghui-path <path> | --canghui-git <url> --canghui-commit <commit>]
cuic doctor [target] [--project <directory>] [--json] [--verbose]
cuic bootstrap [platform]
cuic font <status|install> [platform]
cuic kmode diff [project]
cuic kmode list [project]
cuic kmode describe [project] <endpoint>
cuic kmode call [project] <endpoint> [payload]
cuic probe diff [project]
cuic probe list [project] [--json]
cuic probe describe [project] <probe> [--json]
cuic probe run [project] <probe> [--script <file>|--events <script>] [--json]
cuic scripts init|list [project]
cuic scripts run <name> [project]
cuic symbol list|discover [material|ant|arco] [--json]
cuic symbol generate <provider:name[@export]>... --output <file.cj> [--package <name>]
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example]
cuic prnt [platform] [project|example] [--output <file.bmp|file.png>] [-- <app args...>]
cuic clean [project]
cuic examples
cuic version
```

## Project Scripts

`cuic` automatically discovers named lifecycle pipelines from `canghui.toml` in the application project.
`cuic init` writes a portable starting set:

```toml
[scripts]
check = ["doctor", "test", "build"]
dev = ["run"]
snapshot-ui = ["prnt --output dist/preview.png"]
```

Run the scripts with either the explicit or shorthand surface:

```bash
cuic scripts list
cuic scripts run check
cuic check
```

Each array item is parsed as an existing `cuic` lifecycle action. The runner injects the owning project and
uses the host platform when a platform is omitted. It does not invoke a shell, so the same manifest works on
macOS, Linux, and Windows and cannot silently become an arbitrary command-execution surface. Current portable
steps are `doctor`, `build`, `test`, `run`, `prnt`, and `clean`.

Existing projects can add the default manifest once with `cuic scripts init`. Runtime application state is a
separate concern: `State`, `rememberState`, and `StateStore` are reactive/in-memory facilities, while
`HostApplicationStorage` only supplies host directories. CangHui does not currently expose an
`AppStorage.init()` persistent global key-value implementation, and project script discovery deliberately does
not depend on the application having built or started.

On macOS and Linux use `bin/cuic`. On Windows use `bin\\cuic.cmd` or `bin\\cuic.ps1`.

## Framework Resolution

`cuic` resolves CangHui in this order:

1. the repository that owns the integrated `tools/cuic` command
2. `CANGHUI_FRAMEWORK_ROOT`, then the legacy `CANGUI_FRAMEWORK_ROOT`, as explicit development overrides
3. the target project's local path dependency or Git dependency resolved through `cjpm.lock`
4. the CJPM Git cache, normally `$HOME/.cjpm/git/cui/<commit>`
5. a sibling `CangHui/`, then the legacy `CangjieGUI/` alias

The application does not contain a framework copy. CJPM downloads the pinned source once into its user cache,
and `cuic` prepares the target host's SDL runtime in that resolved cache before build, test, run, kMode, probe,
or snapshot commands.

## Initialization

`init` creates a minimal executable Cangjie application with a public Git dependency pinned by `commitId`,
source entrypoint, runtime-rpath configuration, Git ignore file, and target-platform handoff commands.

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic build macos
cuic run macos
```

The first build creates `cjpm.lock`; commit that file with the application to preserve the exact resolved source.
Framework development can opt into a local checkout without changing the default consumer model:

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

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

`diff` scans the project, recursive local path dependencies, and the resolved CangHui Git cache. `build`, `test`, and `run` execute the same
preflight automatically. Duplicate names report every source location; the macro-generated symbol and runtime
registry remain additional fail-closed layers.

The CLI sets `CANGHUI_KMODE=1` and `CANGHUI_KMODE_TRANSPORT=stdio` only for the supervised child process.
It does not provide arbitrary shell execution. Optional SoonLink Channel persistence belongs in an external
`KModeChannelModule` implementation; URLs, claim tokens and sessions are not CLI configuration.

## No-Image Probes

`cuic probe` runs explicit function and component probes through the same supervised child process while keeping
the public `cui.probe.v0` data model independent from kMode transport. Component probes can assert stable trees,
rectangles, semantic state, event routes, callback activation, logical-time animation samples, and Draw IR without
opening a window.

```bash
./bin/cuic probe diff component-gallery
./bin/cuic probe list component-gallery --json
./bin/cuic probe describe component-gallery gallery.primary-button --json
./bin/cuic probe run component-gallery gallery.primary-button \
  --events $'move-in 80 35\npress 80 35\nrelease 80 35\nassert activation primary-button.click 1' \
  --json
```

The scanner follows recursive local path dependencies plus the resolved framework cache and reports every duplicate source location before the
child build. Macro-generated symbols and the runtime registry remain fail-closed backstops. See
[`docs/probe.md`](../../docs/probe.md) for annotation, scripting, assertion, and report details.

## Platform Matrix

| Platform | doctor | bootstrap | build/test/run | Current boundary |
|---|---:|---:|---:|---|
| macOS | yes | Cangjie-managed Homebrew SDL copy | native host | current arm64 host proven |
| Windows | yes | bundled DLL check | native host | structural preservation; run on Windows for runtime proof |
| Linux | yes | Cangjie-managed pkg-config SDL copy | native host | implementation present; Linux host proof pending |
| iOS | grouped diagnostic | no | static host contracts only | package initialization, signing and renderer return remain blocked |
| HarmonyOS/OpenHarmony | grouped diagnostic | no | adapter-owned | mother framework does not ship an ArkTS/HAP host |
| Android | grouped diagnostic | no | no | backend, NDK bridge, APK packaging and runner not implemented |

The CLI intentionally rejects unconfigured cross-host builds and unsupported Android execution.
`doctor` always displays every platform group, while its exit status considers only global checks and the
requested target. See [`docs/doctor.md`](../../docs/doctor.md) for status, JSON schema, privacy, and CI behavior.

## Fonts

CangHui owns the unmodified HarmonyOS Sans asset and license. Git-based applications use the font from the
resolved framework cache while supervised build/run commands expose it to the renderer, so each project does not
carry another font copy. Local-path initialization retains the project asset copy for framework-development
compatibility. `font install` remains optional; normal supervised rendering does not require host installation.

Recommended macOS installation:

```bash
./bin/cuic font status macos
./bin/cuic font install macos
./bin/cuic font status macos
```

`install` copies the framework-owned font to `~/Library/Fonts/HarmonyOS_Sans_SC.ttf`. Restart running CangHui
applications after installation. Users may instead open the TTF with Font Book or copy it into `~/Library/Fonts/`.

Component, Theme, application, bundled, and system fallback behavior is documented in
[`docs/fonts.md`](../../docs/fonts.md).

## Symbols

`symbol list` reports the adapted provider inventory, frozen upstream revision,
license, aliases, variants, and source paths. `symbol generate` validates those
catalogs and writes a declared-subset registry for an application:

```bash
./bin/cuic symbol list --json
./bin/cuic symbol generate material:add@primary_add ant:check arco:right \
  --output ../../packages/gallery-components/src/gallery_symbols.cj \
  --package canghui_gallery_components
```

Generated export names must be unique across providers. Alias-equivalent
canonical duplicates are rejected. Provider packages remain optional and the
complete upstream icon collections are not bundled. See
[`docs/symbols.md`](../../docs/symbols.md) for registration and fallback rules.

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
./bin/cuic prnt macos component-gallery --output snapshots/symbols.png \
  -- --preview desktop --section symbols
```

This captures the application render surface rather than the surrounding desktop and does not require
the operating system's screen-recording permission.
