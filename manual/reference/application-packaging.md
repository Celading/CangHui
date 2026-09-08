# Application Packaging

**English** | [中文](application-packaging.zh-CN.md)

`canghui.toml` is the project-side declaration for application identity, logical
assets and system-surface policy. The declaration is consumed by `cuic` and is
kept separate from platform-specific providers.

## Minimal declaration

```toml
[application]
name = "Demo"
identifier = "dev.example.demo"
version = "1.0.0"
publisher = "Celading"

[assets]
application-icon = "assets/app.png"
resources = ["assets/data", "assets/i18n"]

[system]
single-instance = true
status-item = true
notifications = true
settings = true
```

Asset paths are project-relative. Absolute paths, `~`, `..` traversal,
symbolic links anywhere in a declared asset tree, and missing declared files
are rejected. The recursive symbolic-link check prevents a resource directory
from importing files outside the project during packaging. Logical asset roles are declared once;
`cuic` does not guess a status or notification icon from the application icon.
The application name must also be a portable artifact name: Windows-reserved
characters, device names and leading or trailing spaces/dots are rejected.

## Deterministic plan

Run:

```text
cuic package plan macos .
cuic package plan windows . --json
cuic package plan linux . --json
```

The command validates the manifest and prints a stable plan containing identity,
input assets, intended generated files, provider state and signing gates. It is
a plan-only operation: it does not build an application bundle, generate a
Windows resource, sign an artifact or publish a package. Those operations remain
later provider and release stages.

The same manifest and target produce the same plan fields. `project` is included
in JSON as evidence of the resolved input project; consumers should treat paths
inside the plan as project-relative unless a tool explicitly documents otherwise.

## Unsigned artifact generation

```text
cuic package build macos .
cuic package build windows . --output dist/windows-input --json
cuic package build linux . --output dist/linux-input --json
```

`package build` writes a bounded unsigned artifact and a
`canghui-packaging-receipt.json` using the
`canghui.packaging-artifact.v0` schema. On macOS the receipt is sealed inside
`Contents/Resources`; Windows and Linux keep it at the artifact root. The default destination is
`dist/<Name>.app` on macOS and `dist/<Name>` on Windows or Linux. `--output`
accepts one project-relative directory. Traversal, absolute destinations and
non-empty output directories are rejected, so the command never replaces an
existing artifact implicitly. The output may not be nested inside a declared
resource directory, which prevents a generated artifact from recursively
copying itself into its own resource tree.

On a macOS host, the macOS route first runs the normal locked `cuic build`
pipeline and copies the resulting executable into `Contents/MacOS`. The bundle
also contains `Info.plist`, `PkgInfo`, declared resources and logical icon-role
assets. Keeping the receipt under `Contents/Resources` avoids adding unsealed
files to the `.app` root when a downstream release gate signs the bundle. A paired
source SDK contributes its native dependencies, fonts and licenses; ordinary
source projects still have host-managed native runtime dependencies. The receipt
distinguishes these cases and records that the unsigned bundle has not been
launched. Release trim/strip, the release security audit and publisher
signing/notarization remain unverified. Carried dependencies alone do not prove
that the app works on another machine.

Windows and Linux routes are cross-host-safe input generators. They do not
pretend to cross-compile an executable:

- Windows receives an executable manifest, version-resource source,
  AppUserModelID, declared assets and resources.
- Linux receives a desktop entry, `share/applications`, an icon tree and
  application resource tree.

The Linux entry keeps `application.name` for display, but uses the validated
`application.identifier` as its executable name (for example `dev.example.demo`).
Install the executable or a launcher with that exact name in the desktop session's
`PATH`; the input tree does not install it. Existing Linux install scripts that
used the display name must update that destination. Display names with spaces,
percent signs or `=` no longer become command-line syntax or field codes. macOS
and Windows artifact naming is unchanged.

Icon bytes are never relabelled as another format. A real `.icns` or `.ico`
uses the native destination name; PNG, SVG and other inputs keep their original
extension and remain visible as a conversion or provider gate.

## Linux runtime metadata preflight

Framework/package maintainers can inspect a separately assembled Linux bundle
without executing its contents:

```bash
python3 scripts/audit-linux-runtime.py dist/MyApp --executable bin/main \
  --system-dir /lib/aarch64-linux-gnu
```

This maintenance script requires Python 3.11+ and GNU `readelf`. It does not
assemble the bundle or change the current metadata-only Linux `cuic package build`
route. Application binaries belong under the bundle root and shared libraries
under `lib/`. Pass target-system library directories explicitly; the auditor does
not use `ldd` or ambient loader search paths. A target sysroot can supply those
directories when the auditing host has the appropriate `readelf`.

Exit 0 means `dependency-metadata-ready`; 1 means findings require repair; 2
means the audit could not finish. The report includes file hashes, architecture,
dependency closure, unsafe search paths and required glibc version tags. Only
little-endian ELF64 AArch64/x86-64 with the usual glibc interpreter is supported.
System-baseline libraries must come from the explicit system directories, not
be copied into the bundle. Search paths must use `$ORIGIN` and stay inside it.

The numeric glibc floor is a lower bound from the carried files' requirements,
not an OS compatibility certificate. Keep nonnumeric version tags as well.
Symbol-version availability, dynamically loaded plugins, licenses, fonts, actual
launch, CPU/kernel requirements and desktop installation require separate proof.
For example, a wrapper can make a program with an SDK-absolute RUNPATH launch;
this audit still reports the nonrelocatable path instead of treating launch as
clean packaging. The JSON may contain local paths; review it before publishing.

## macOS icons: bundle identity and runtime updates

Provide the default Finder, Dock and About icon through the `.app`. Set
`[assets].application-icon` to a real `.icns` and run `cuic package build macos .`.
A bare executable is not a replacement for bundle identity, and PNG inputs are
not automatically converted to ICNS.

Use the existing `DesktopApp.setWindowIcon` for runtime updates on the UI thread,
for example inside a button callback. After a successful call, the input Surface
can be released:

```cangjie
let icon = SdlSurface.create(64, 64)
try {
    icon.clear(Color.rgb(40, 130, 210))
    app.setWindowIcon(icon)
} finally {
    icon.close()
}
```

On macOS this updates the application icon, not an independent title-bar icon for
each window. To restore it, supply independently retained original image data;
do not treat a native `NSImage` address as an immutable snapshot. The system may
update that object in place and resample its dimensions. Verify image content,
not pointer replacement or a fixed pixel size. This does not provide Dock menus,
badges or notifications. Verify native icons through system APIs or the system
UI; `cuic prnt` captures application content, not the Dock.

## Platform boundary

- macOS can generate an unsigned local `.app`; signing, notarization,
  self-contained runtime closure and launch acceptance remain gated.
- Windows generates resource/compiler inputs; a PE executable, compiled
  resources, signing and MSIX publication remain gated.
- Linux generates a desktop/package input tree; native-host executable replay,
  system installation, tray and notification behavior remain gated.

`cuic doctor` reports whether the declaration and all referenced assets are
ready and whether both packaging schemas are present, but readiness is not
runtime or release proof.

For the release compiler contract, privileged-channel negative replay,
Developer ID/Hardened Runtime signing and notarization gates, see
[Security And Release Provenance](security-and-release.md). An unsigned
`package build` receipt is never publisher or store evidence.

Mobile hosts use a separate staged receipt because a platform input tree,
signed package and device replay are different facts. See
[Mobile Application Host](mobile-application-host.md) and
`canghui-mobile-host-package-v0.schema.json`.
