# Mobile Application Host

**English** | [中文](mobile-application-host.zh-CN.md)

`canghui.mobile-application-host.v0` is the common boundary between CangHui and
an iOS, Android or HarmonyOS application host. It complements the existing
lifecycle, viewport, touch, storage and native-surface contracts; it does not
replace the platform SDK or generate a store-ready package.

## Provider boundary

Each platform provider implements `MobileApplicationHostProvider` and reports:

- platform and package kind;
- current application lifecycle and lifecycle epoch;
- current native-surface generation;
- permission state for requested host capabilities, retained in the receipt;
- the highest package evidence stage actually reached.

Native callbacks carry `MobileHostCallbackContext`. A callback is accepted only
when both its lifecycle epoch and surface generation match the current receipt.
This prevents a recreated scene, Activity, Ability or native surface from
delivering an old action into the current Cangjie UI owner queue.

## Evidence stages

| Stage | Meaning | Explicit non-claim |
| --- | --- | --- |
| `contract-ready` | The provider can consume the public contract. | No package input tree exists. |
| `input-tree` | Platform metadata, assets and native inputs exist. | The result is not installable. |
| `signed-package` | A platform package has valid signing evidence. | No physical-device runtime is proven. |
| `device-proven` | The signed package passed a recorded device replay. | Store publication and production readiness remain separate. |

The public transition predicate permits only one forward step, and a Provider
must reject rollback when applying a new receipt. `MobileHostPackageReceipt`
rejects a package kind that does not match its platform, an empty input tree
after the first stage, duplicate capability permission entries, unsigned
installability claims and device claims without a passed device replay. The
JSON schema carries the same stage prerequisites; cross-item duplicate
permission checks remain runtime validation.

## Current platform state

- iOS/iPadOS has a UIKit `CAMetalLayer` native-surface adapter and historical
  simulator/device bootstrap proof. A product application package, current
  signing receipt and product-scene device replay remain separate work.
- Android has a Java/JNI/NDK `SurfaceView` bootstrap. Cangjie Android runtime
  linkage, a product APK and device replay remain open.
- HarmonyOS consumes the same contract through an independently implemented
  Ability/XComponent or OHNativeWindow provider. This repository does not ship
  an ArkTS project or HAP and therefore does not claim HarmonyOS runtime proof.

Run `cuic doctor ios`, `cuic doctor android` or `cuic doctor harmonyos` to see
the local toolchain facts together with this common provider boundary.
