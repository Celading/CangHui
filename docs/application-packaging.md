# Application Packaging Plan

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

Asset paths are project-relative. Absolute paths, `~`, `..` traversal and
missing declared files are rejected. Logical asset roles are declared once;
`cuic` does not guess a status or notification icon from the application icon.

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

## Platform boundary

- macOS plans `Info.plist`, an `.icns` resource location and the application
  resource tree. Signing and notarization remain gated.
- Windows plans version-resource, `.ico`, manifest and AppUserModelID inputs.
  Signing and MSIX publication remain gated.
- Linux plans a desktop entry, icon installation tree and shared resources.
  Tray and notification behavior depends on an installed host provider.

`cuic doctor` reports whether the declaration and all referenced assets are
ready, but readiness is not runtime or release proof.
