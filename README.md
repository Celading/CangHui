<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-CangHui-c96b2c?style=for-the-badge&labelColor=1f2430" alt="Cangjie" />
  <img src="https://img.shields.io/badge/version-0.10.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="Version 0.10.0" />
  <img src="https://img.shields.io/badge/package-cui-2f855a?style=for-the-badge&labelColor=1f2430" alt="Package cui" />
  <img src="https://img.shields.io/badge/output-static-805ad5?style=for-the-badge&labelColor=1f2430" alt="Static Output" />
  <img src="https://img.shields.io/badge/focus-multiplatform%20GUI-1f9d55?style=for-the-badge&labelColor=1f2430" alt="Multiplatform GUI" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache License 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">CangHui / CUI</span><br/>
<span style="font-weight:100;font-size:24px">Cangjie Multiplatform Declarative GUI Framework</span>
<p align="center">
  <strong>A GUI runtime for turning Cangjie intent into native pixels</strong><br/>
  <sub>Declarative semantics · deterministic probes · self-rendered surfaces · native host contracts</sub>
</p>
</div>

**English** | [中文](README.zh-CN.md)

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## What is CangHui

CangHui is a self-rendered, declarative GUI framework written in the
[Cangjie programming language](https://cangjie-lang.cn/). It evolved from
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI) and
retains its upstream attribution and MIT notice. CangHui and its original
contributions are distributed under Apache License 2.0; the upstream MIT terms
remain preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The
declarative core (`cui`) and the safe SDL3 wrapper (`sdl`) live in this
repository, together with the integrated `cuic` toolchain, component-package
contracts, responsive layout primitives, and native host contracts.

The framework is designed to be platform-neutral at the source level: common
widgets and product components depend only on typed host capabilities and
viewport facts, while each platform adapter owns lifecycle, native surfaces,
IME, accessibility, packaging, and signing. Platform-specific hosts can be
implemented independently without changing common widgets or application
state.

> CangHui is not a screenshot layer and not a bag of widgets. It is a small
> language-facing runtime: application intent enters as Cangjie composition,
> passes through layout, state, motion, symbols and host capabilities, and
> leaves as a frame that can be rendered, inspected or replayed.

## The CangHui Stack

```text
Application code
        |
        v
cuic project lifecycle  ----  kMode / probe / Draw IR / prnt
        |
        v
CUI declarative core  ----  state, identity, layout, controls, overlays
        |                    theme, motion, typography, Symbol providers
        v
Host capability contracts  --  window, input, IME, files, clipboard, time
        |
        v
Native surface adapters  ----  SDL3 desktop | UIKit/Metal slice | mobile bootstrap
        |
        v
Platform runtime and GPU backend
```

The stack is deliberately layered. A component should be able to describe its
behavior without importing a platform host; a host should be able to expose a
surface without knowing the application's business state; and `cuic` should be
able to exercise the same public functions without opening a window.

## Platform Status

Platform claims below are intentionally conservative. Desktop layout previews
do not prove a mobile runtime, and a native-surface probe is not product-level
scene rendering or application acceptance.

| Platform | Status | Notes |
| --- | --- | --- |
| macOS desktop | Available | Build, the full framework/SDL/CLI test suites, the interactive gallery, and deterministic snapshots pass on this host. |
| iOS | Native-surface adapter proven | Simulator and physical-device proof covers static-package bootstrap, a UIKit `CAMetalLayer`, lifecycle, safe area, touch, `CADisplayLink`, detach/reattach generation replay and a Metal clear pass. Full CUI scene rendering, IME, accessibility and product application acceptance remain open. |
| HarmonyOS / HarmonyPC | Host integration not shipped here | The shared contracts cover native surfaces and host capabilities, but this repository does not include an ArkTS/HAP application host or claim standalone device acceptance. |
| Windows / Linux | Code paths present | `cuic` contains bootstrap, doctor and build code paths; this repository does not claim host-verified runtime proof for either platform. |
| Android | Native-surface bootstrap only | A minimal Activity owns the generation-safe `SurfaceView` to JNI to `ANativeWindow` lifecycle, and the slice builds for `arm64-v8a` and `x86_64`. The Cangjie Android SDK, renderer bridge, input/IME, APK packaging and device runtime proof remain open. |

## Capability Map

| Layer | In the public tree | Boundary |
| --- | --- | --- |
| CUI core | Declarative composition, identity, state, layout, controls, overlays and text editing | Platform-neutral source API |
| Rendering | SDL3-backed desktop renderer, geometry, text, symbols, shadows and gradients | The renderer is a dependency-backed implementation, not a claim about every GPU backend |
| Interaction | Pointer capture, hover/click cancellation, focus, keyboard routing, smooth scrolling and motion levels | Native IME and accessibility remain host responsibilities where not proven |
| Inspection | `kMode`, `cuic probe`, component/function/event reports, Draw IR and deterministic `prnt` | Headless reports prove semantics and geometry, not a full device UI acceptance |
| Packaging | `cuic init`, dependency cache/lock discipline, doctor and platform preparation | Signing, application identity and store packaging are outside the framework |
| Mobile bridge | iOS native-surface lifecycle slice and Android surface bootstrap | Full product rendering and consumer acceptance are still platform-specific work |

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
cuic dependency update
cuic doctor macos
cuic build macos
cuic run macos
```

Generated applications depend on the public CangHui Git repository pinned by
commit. `cuic dependency update` is the explicit lock/cache mutation step;
build-like commands require a matching `cjpm.lock` and never update it
implicitly. The framework resolves through the CJPM cache instead of being
copied into every project.

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

The intended consumer shape is small: depend on `cui`, install `cuic`, and let
the tool create the project skeleton. A framework checkout is useful for
framework development, but it is not the normal application layout.

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
- Device-paced desktop rendering uses renderer VSync without adding a second
  fixed delay. `FramePacing.Fixed(fps)` and `FramePacing.Unbounded` are explicit
  alternatives; kMode selects unbounded rendered frames unless the application
  chooses another policy.
- Scrollable views use browser-like retained wheel easing by default. A shared
  `ScrollOptions` policy configures immediate or smooth behavior, logical-pixel
  wheel step, duration, and easing across views, lazy lists, tables, trees,
  text areas, dropdowns, and combo boxes.
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

## A Public Contract, Not a Platform Costume

CangHui uses a strict vocabulary for capability claims:

- **Implemented** means the source, tests and the named host proof agree.
- **Experimental** means the adapter or protocol is usable for bounded work,
  while broader runtime or consumer proof is still open.
- **Contract** means CangHui defines the interface and invariants, but a host
  project still owns the platform implementation.
- **Planned** means the direction is documented, not shipped.

This distinction is part of the product. It keeps a desktop snapshot from being
mistaken for an iPad runtime, and keeps a native-surface bootstrap from being
mistaken for a complete application host.

## Technical Lineage and Ecosystem

The following map is intentionally layered. It shows what CangHui uses, what it
exposes, and what it studies; it does not fold upstream project capabilities
into the CangHui implementation claim.

| Role | Project or surface | Relationship to CangHui |
| --- | --- | --- |
| Language | [Cangjie](https://cangjie-lang.cn/) | Primary implementation and application language |
| Declarative runtime | CUI (`cui`) | Framework-owned composition, state, layout and component surface |
| Desktop substrate | [SDL3](https://www.libsdl.org/) / SDL3_ttf | Upstream runtime dependency wrapped by the public `sdl` package |
| Native surface | UIKit, Metal, Android `SurfaceView` and `ANativeWindow` | Adapter targets and bounded bootstrap surfaces; platform proof is explicit in the matrix |
| Design language | HarmonyOS Sans, Theme, Motion and Symbol contracts | Bundled fallback plus provider-neutral public APIs |
| Tooling | `cuic`, kMode, probe, Draw IR, doctor and `prnt` | Framework-owned project, inspection and verification entry points |
| Component references | ArkUI-oriented component matrix and mature GUI conventions | Compatibility and design references, not bundled platform implementations |
| Graphics references | SDL, GPU geometry and native-surface literature | Engineering inputs for the renderer boundary, not a claim of owning every backend |

The useful mental model is a **semantic bridge**: CangHui carries Cangjie
meaning across hosts, while each host remains accountable for its lifecycle,
surface, input, text system, accessibility and packaging truth.

## Where This Is Going

The next architectural frontier is not adding a longer widget catalogue. It is
making the same application inspectable at three resolutions:

1. **Semantic**: invoke a public function or event through kMode.
2. **Geometric**: inspect layout bounds, hit regions and Draw IR without a
   window.
3. **Visual**: render the settled frame and capture it when pixels are the
   question.

That gives automated tools, CI and developers a shared vocabulary for debugging UI without
forcing every question through a screenshot. Screenshots remain valuable for
visual acceptance; they simply stop carrying the entire testing burden.

## Documentation

- [Examples](examples/)
- [Getting started](docs/guide/index.md)
- [API reference](docs/api/index.md)
- [Architecture](docs/architecture.md)
- [Consumer workflow](docs/consumer-workflow.md)
- [Multiplatform doctor](docs/doctor.md)
- [Symbols and providers](docs/symbols.md)
- [Fonts](docs/fonts.md)
- [Probe and kMode](docs/probe.md)
- [SDL3 Apple host notes](docs/sdl3-apple-host.md)
- [Modern GUI insights](docs/modern-GUI-insights-and-analysis.md)

## License

This project is released under the
[Apache License 2.0](LICENSE). See [NOTICE](NOTICE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for retained upstream and
third-party attribution. The SDL3 and SDL3_ttf run-time libraries use the Zlib
license; see the respective upstream projects. The upstream source attribution
remains [`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI).

> [!IMPORTANT]
> When distributing desktop software built with CUI, ensure the SDL and SDL_ttf
> dynamic libraries are placed beside the Cangjie executable or on the target
> platform's dynamic-library search path.
