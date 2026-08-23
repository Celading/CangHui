---
name: canghui-full-build
description: Build and validate CangHui Multiplatform from a clean checkout, including chui, sdl, cuic, public docs, version mirrors, and a generated external consumer. Use for release-branch, integration, or full-regression acceptance without claiming platform or device proof that was not replayed.
---

# CangHui Full Build

Use this skill for a release candidate or integration packet that must prove the
public CangHui repository as one unit. Run it from the repository root. Preserve
unrelated user changes and report every skipped platform gate as a gap.

## Preflight

Record the checkout and toolchain before changing or testing anything:

```bash
git status --short --branch
cjc --version
cjpm --version
```

Confirm that `cjpm.toml` declares the root package as `chui`. Read
`README.md`, `manual/index.md`, and the documents directly related to the
change. Do not infer a successful platform runtime from a common-source build.

On macOS, prepare missing SDL dependencies with the checked-in bootstrap:

```bash
bash scripts/bootstrap-macos.sh
export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-/opt/homebrew/lib}"
```

Do not copy an unverified dynamic library from an arbitrary build tree.

## Required Gate

Run every command below. Any non-zero exit is a release-candidate failure:

```bash
cjpm build
cjpm test
(cd sdl && cjpm test)
(cd tools/cuic && cjpm test && cjpm build)
bash tools/cuic/scripts/test-cli.sh
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py
git diff --check
```

Record the actual `TOTAL` and `PASSED` counts from each suite; never copy a
historical count into the receipt.

The CLI smoke creates a disposable application using a local
`[dependencies].chui` path and `import chui.*`. If that step is not available,
create an equivalent disposable consumer outside the repository, build it, and
remove or retain it only according to the caller's cleanup policy.

## Conditional Scene3D Native Gate

This gate is required when the change or public claim touches `src/scene3d`,
`packages/scene3d-bgfx`, the native host, shader/geometry resources, or native
3D behavior. It is not part of an ordinary framework build because bgfx4cj
source and native archives remain external optional inputs.

Use an exact bgfx4cj Git checkout and an archive directory accepted by the
checked-in contract. Do not copy archives from an arbitrary build tree or edit
CJPM manifests to make the proof pass. Record both external revisions and run:

```bash
BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/verify-scene3d-bgfx-native-supply.sh \
  /tmp/canghui-scene3d-native-supply.json

BGFX4CJ_ROOT=/path/to/bgfx4cj \
BGFX_NATIVE_ROOT=/path/to/accepted-native-archives \
./scripts/verify-scene3d-bgfx-metal-capture.sh \
  /tmp/canghui-scene3d-metal.png \
  /tmp/canghui-scene3d-native-supply.json
```

For close-lifecycle changes, also replay a normal non-capture loop through an
SDL quit request and require clean detach. A fixed-frame capture is not a
substitute for the normal close path.

When entity scale/rotation or `Scene3DCameraSnapshot` changes, the native capture
must include at least one non-default transform and a non-default camera. A core
unit test alone proves contract shaping, not that the optional driver consumes
the frame values.

Generic provider capture proves the CangHui provider only. A product-level 3D
claim additionally requires a consumer-owned mapping, user entry, fallback,
normal lifecycle, current-session transfer (when a companion window is used),
final artifact launch, and product visual review. Record the consumer revision
and keep product types, meshes and policy out of CangHui.

## Optional Platform Evidence

Only run platform or device steps when they are explicitly in scope and the
required host is available. `cuic device list` is discovery; commands that
install, launch, debug, or capture a device require the caller's authority.

`cuic prnt --device` currently represents the documented system-screenshot
fallback. It does not prove CangHui scene rendering, a complete HarmonyOS host,
store packaging, signing, installation, or LTS readiness. Record those facts as
separate gates.

## Public Surface Review

The bundled audit script checks Markdown links, internal-path leakage, skill
metadata, the `chui` public roots, and version mirrors in the manifest, README
badges, manual, capability matrices, and built-in Symbol provider. Review its
result together with the actual diff; automated text checks do not replace API
or platform-boundary judgment.

Before closeout, also confirm that active Cangjie source files remain below the
repository's 4000-line guard and that compatibility identifiers such as
`cui.probe.v0`, `CUI_*`, `cuic`, and `--cui-path` were not renamed merely for
branding consistency.

## Receipt

Return a compact receipt containing:

- branch and exact commit;
- `cjc` and `cjpm` versions plus host target;
- build and suite results with actual counts;
- public-audit and CLI-smoke results;
- conditional Scene3D native supply, Metal capture and consumer evidence when
  the packet touches native 3D;
- platform/device steps replayed or explicitly not replayed;
- remaining release, signing, runtime, or consumer gaps.

Do not create a tag, merge a hosted branch, change dependencies, or publish a
release unless the caller separately authorized that action.
