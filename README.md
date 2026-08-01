<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-CangHui-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie" />
  <img src="https://img.shields.io/badge/version-0.9.2-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.9.2" />
  <img src="https://img.shields.io/badge/package-cui-2f855a?style=for-the-badge&labelColor=1f2430" alt="Package cui" />
  <img src="https://img.shields.io/badge/output-static-805ad5?style=for-the-badge&labelColor=1f2430" alt="Static Output" />
  <img src="https://img.shields.io/badge/focus-multiplatform%20GUI-1f9d55?style=for-the-badge&labelColor=1f2430" alt="Multiplatform GUI" />
  <img src="https://img.shields.io/badge/license-MIT-d69e2e?style=for-the-badge&labelColor=1f2430" alt="MIT License" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">CangHui / CUI</span><br/>
<span style="font-weight:100;font-size:24px">Cangjie Multiplatform Declarative GUI Mother Framework</span>
<p align="center">
  <strong>Self-rendered, declarative, and platform-contract driven UI for Cangjie applications</strong><br/>
  <sub>Widgets · State · Layout · Text · Media · Animation · Tooling · Native host contracts</sub>
</p>
</div>

**English** | [中文](README.zh-CN.md)

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## What is CangHui

CangHui is a self-rendered, declarative GUI mother framework written in the
[Cangjie programming language](https://cangjie-lang.cn/). It evolved from
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI) and
retains its upstream attribution and MIT license. The declarative core (`cui`)
and the safe SDL3 wrapper (`sdl`) live in this repository, together with the
integrated `cuic` toolchain, component-package contracts, responsive layout
primitives, and native host contracts.

The framework is designed to be platform-neutral at the source level: common
widgets and product components depend only on typed host capabilities and
viewport facts, while each platform adapter owns lifecycle, native surfaces,
IME, accessibility, packaging, and signing. The HarmonyOS/HarmonyPC platform
implementation is maintained by the HarmonyHap/CangHUI provider; this
repository is the mother framework it consumes.

## Platform Status

Platform claims below are intentionally conservative. Desktop layout previews
do not prove a mobile runtime, and a bootstrap proof is not a renderer.

| Platform | Status | Notes |
| --- | --- | --- |
| macOS desktop | Available | Build, the full framework/SDL/CLI test suites, the interactive gallery, and deterministic snapshots pass on this host. |
| iOS | Bootstrap proven, renderer open | Device/simulator static-package bootstrap and ABI return are proven; the UIKit native-surface renderer, lifecycle, IME and accessibility adapters are not implemented yet. |
| HarmonyOS / HarmonyPC | Provider-side device proven | The native OHNativeWindow/Vulkan/EGL adapter lives in the HarmonyHap/CangHUI platform provider; the mother framework does not ship an ArkTS/HAP host. |
| Windows / Linux | Code paths present | `cuic` contains bootstrap, doctor and build code paths; this repository does not claim host-verified runtime proof for either platform. |
| Android | Not implemented | No renderer backend, SDL activity bridge, NDK packaging, or APK runner exists yet. |

## Quick Start

The easiest way to create, build, and run a CangHui application is through the
integrated `cuic` CLI. Installing `cuic` only sparse-fetches and builds
`tools/cuic`; it does not keep a full framework checkout next to your project.

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

Create and run a blank project:

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic doctor macos
cuic build macos
cuic run macos
```

Generated applications depend on the public CangHui Git repository pinned by
commit, pin a `cjpm.lock`, and resolve through the CJPM cache instead of copying
the framework into every project.

A minimal window in `src/main.cj`:

```cangjie
import cui.*

main() {
    let message = State<String>("Hello, CUI")
    let app = DesktopApp(WindowSpec("CUI Example", 640, 420))

    app.run {
        VStack {
            Panel {
                Label(message.value)
            }.flexible(false)
            Button("Update", {=> message.value = "State updated"})
                .role(ButtonRole.Primary)
                .width(160.vp)
        }.spacing(12.vp).padding(20.vp)
    }
}
```

See [consumer workflow](docs/consumer-workflow.md) for cache, lock, and local
override rules.

## Core Capabilities

- Self-rendered GUI engine on SDL3 with GPU geometry, supersampled anti-aliasing,
  rounded corners, strokes, icons, shadows, and gradient fills.
- Declarative UI built on Cangjie trailing lambdas, `extend`, and `prop`.
- Layout containers: `VStack`, `HStack`, `ZStack`, `Grid`, `Panel`, `FlowRow`,
  `ScrollView`, `SplitView`, `Accordion`, animated `Reveal`, and viewport-focused
  lazy containers `LazyColumn`, `LazyRow`, `LazyList`, and `LazyGrid`.
- Controls: buttons, text fields, switches, checkboxes, radio buttons, pickers,
  steppers, sliders, progress bars, rating, badges, chips, step indicators,
  pagination, breadcrumbs, lists, data tables, tree views, date/time pickers,
  reorderable lists, segmented controls, tabs, dropdowns, and combo boxes.
- Overlays: dropdowns, context menus, menu bars, pickers, tooltips,
  notifications, and modal dialogs with a stack that supports nesting.
- Order-sensitive chained modifiers for size, constraints, padding, surface,
  radius, border, shadow, gradient, flex, visibility, and enabled state, with
  `.px`, `.vp`, and `.fp` units.
- State management: read/write split `Observable`/`Bindable`, writable
  `State<T>`, cached `DerivedState` (`derive`/`map`), and two-way `Binding`
  (`project`).
- Thread-safe `UiOwnerQueue` and `DesktopApp.postToUi`: workers prepare
  immutable results, and the single UI owner commits them in ticket order before
  the next declarative build, with epoch/native-surface-generation gates,
  cancellation, close receipts, and bounded draining. `State` itself remains
  UI-owner-only.
- Stable widget identity via `Keyed`, `rememberState`, and `ForEach`; focus,
  hover, cursor, and click identity follow deterministic per-frame build order.
- Animation primitives: `Spring`, duration/easing `Animator`, repeating `Pulse`,
  render-loop-as-clock with dirty-frame continuation, and `AnimationSpec` scaled
  by theme `MotionLevel`.
- Design tokens: `Spacing`, `Radii`, `Motion`, color `Theme`, `FontSizes`, and
  `Shadow.elevation`.
- Pointer-origin light/dark theme reveal and semantic-color InkWell feedback
  clipped to real rounded geometry, with release-inside activation and permanent
  move-out cancellation.
- Text editing: UTF-8 cursor/selection, double-click word selection, triple-click
  line selection, clipboard best-effort, undo/redo grouping, and IME anchor
  reporting.
- Platform capability SPI: file dialogs, message boxes, clipboard, cursor,
  displays, filesystem, time, and system information.
- Provider-neutral `Symbol` with built-in icon compatibility and optional
  Material, Ant Design, and Arco provider packages; `cuic symbol generate`
  emits declared subsets with duplicate/collision rejection.
- Bundled HarmonyOS Sans with explicit component, theme, application, bundled,
  and system resolution tiers plus license/source notices.

## Integrated Toolchain (`cuic`)

`tools/cuic` is the framework-owned CLI:

- `cuic init` / `build` / `test` / `run` with per-platform preparation
- `cuic doctor` for grouped Cangjie, repository, SDL, macOS, Windows, Linux,
  iOS, HarmonyOS, Android, font, Symbol, kMode, and probe readiness
- `cuic kmode` for debug/supervised headless invocation without opening a window
- `cuic probe` for deterministic component/function/event/animation and Draw IR
  reports without a window
- `cuic symbol` for declared provider subsets and generation
- `cuic font` for font preparation and registration
- `cuic prnt` for deterministic settled-frame screenshots
- `cuic check` / `dev` / `snapshot-ui` lifecycle aliases declared in
  `canghui.toml` (bounded to existing cuic actions)

Doctor status model and JSON contract:
[`docs/doctor.md`](docs/doctor.md).

## Components, Gallery, and Packages

Common component packages are normal CJPM source dependencies. They expose a
typed `ComponentPackageDescriptor`, receive a `ComponentContext` with
`HostProfile` and `ViewportSpec`, and may branch on `Compact`, `Medium`, and
`Expanded` layout classes without importing a platform host.

- Reference package: `packages/gallery-components`
- Desktop gallery: `examples/component-gallery`
- Responsive preview matrix: `src/testkit/preview_matrix.cj`
- Component-package schema: `contracts/canghui-component-package-v0.schema.json`
- Symbol providers: `packages/symbol-material`, `packages/symbol-ant`,
  `packages/symbol-arco`

## Documentation

- [Examples](examples/)
- [Getting started](docs/guide/index.md)
- [API reference](docs/api/index.md)
- [Architecture](docs/architecture.md)
- [Symbols and providers](docs/symbols.md)
- [Fonts](docs/fonts.md)
- [Probe and kMode](docs/probe.md)
- [Modern GUI insights](docs/modern-GUI-insights-and-analysis.md)

## License

This project is released under the [MIT License](LICENSE). The SDL3 and SDL3_ttf
run-time libraries use the Zlib license; see the respective upstream projects.
The upstream source attribution remains
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI).

> [!IMPORTANT]
> When distributing desktop software built with CUI, ensure the SDL and SDL_ttf
> dynamic libraries are placed beside the Cangjie executable or on the target
> platform's dynamic-library search path.
