# Multiplatform Doctor

**English** | [中文](doctor.zh-CN.md)

`cuic doctor` reports CangHui development readiness without implying that every
listed platform is implemented or validated on the current host.

```bash
./tools/cuic/bin/cuic doctor
./tools/cuic/bin/cuic doctor macos --verbose
./tools/cuic/bin/cuic doctor ios --json
```

The optional target accepts `macos`, `windows`, `linux`, `ios`, `harmonyos`, or
`android`. When omitted, it defaults to the current host platform. Every report
still includes all platform groups so missing cross-platform work remains
visible.

## Status Model

| Status | Meaning |
|---|---|
| `ready` | The check is available and passed on this host. |
| `degraded` | The capability remains usable or inspectable, but a non-blocking part is incomplete. |
| `blocked` | The requested target cannot proceed until the reported requirement is repaired. |
| `unsupported` | This CangHui version or the current host cannot perform the capability. |

Repair actions are classified as `automatic`, `manual`, `unsupported`, or
`none`. Human output shows the action next to each affected check.

## Exit Status

The process returns a nonzero status only when a global check or the explicitly
requested target contains `blocked` or `unsupported` checks. A limitation in an
unrequested platform remains visible but does not fail an otherwise usable
host workflow. `degraded` never fails the command by itself.

This makes the following pattern suitable for CI:

```bash
./tools/cuic/bin/cuic doctor macos --json > doctor.json
```

The JSON document follows
[`canghui.doctor.v0`](../contracts/canghui-doctor-v0.schema.json). Without
`--verbose`, every `evidence` field is an empty string. Verbose mode may include
tool versions and filesystem locations, but signing identities and connected
device identities are summarized rather than emitted.

## Check Groups

The report covers:

- Cangjie compiler and package-manager availability;
- repository, package, and integrated CLI alignment;
- macOS, Windows, Linux, iOS, HarmonyOS/OpenHarmony, and Android readiness;
- SDL runtime or development-library availability where applicable;
- bundled HarmonyOS Sans and its license receipt;
- Symbol core, optional providers, and on-demand generation;
- kMode and `cui.probe.v0` duplicate-registry health.

Signing and connected-device commands run only when `ios` or `harmonyos` is
explicitly requested. This keeps the default desktop diagnosis bounded and
predictable.

The iOS group deliberately separates the proven static-package bootstrap from
the open GUI backend. The build script, Objective-C bootstrap helper, replay
script and dual-target proof receipt report independently; the
`CAMetalLayer/MTKView` native-surface renderer remains a blocking check for an
iOS application target until its own device acceptance lands.

Set `CANGHUI_IOS_HOME` or `CANGJIE_IOS_HOME` when the iOS SDK is installed outside
the default `/Library/Frameworks/Cangjie/1.3.0-alpha-ios` location.
