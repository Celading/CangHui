# 移动应用宿主

[English](mobile-application-host.md) | **中文**

`canghui.mobile-application-host.v0` 是 CangHui 与 iOS、Android、HarmonyOS
应用宿主之间的公共边界。它补充现有生命周期、视口、触摸、存储和原生 Surface
契约，但不替代平台 SDK，也不会凭空生成可上架安装包。

## Provider 边界

每个平台 Provider 实现 `MobileApplicationHostProvider`，并报告：

- 平台与安装包类型；
- 当前应用生命周期及 lifecycle epoch；
- 当前原生 Surface generation；
- 所请求宿主能力的权限状态，并写入 receipt；
- 已有证据真正达到的最高打包阶段。

原生回调携带 `MobileHostCallbackContext`。只有 lifecycle epoch 与 Surface
generation 同时匹配当前 receipt，回调才可进入 Cangjie UI owner queue。这样可
避免旧 Scene、Activity、Ability 或已销毁 Surface 把过期动作送入当前界面。

## 证据阶段

| 阶段 | 含义 | 明确不代表 |
| --- | --- | --- |
| `contract-ready` | Provider 能消费公共契约。 | 尚无平台输入树。 |
| `input-tree` | 平台元数据、资源和原生输入已具备。 | 结果不可宣称可安装。 |
| `signed-package` | 平台安装包已有有效签名证据。 | 尚无真机运行证明。 |
| `device-proven` | 已签名安装包通过有记录的真机回放。 | 不等于商店发布或生产就绪。 |

公共 transition predicate 只允许单步向前推进，Provider 在应用新 receipt 时必须
拒绝回退。`MobileHostPackageReceipt` 会拒绝平台与安装包类型不匹配、输入树阶段
后仍为空、同一 capability 出现重复权限项、未签名却声称可安装，以及没有通过
真机回放却声称 `device-proven` 的 receipt。JSON schema 同步表达阶段前置条件；
跨项的重复权限检查仍由运行时完成。

## 当前平台状态

- iOS/iPadOS 已有 UIKit `CAMetalLayer` 原生 Surface 适配器，以及历史模拟器、
  真机 bootstrap 证明；产品应用包、当前签名 receipt 和产品场景真机回放仍是独立工作。
- Android 已有 Java/JNI/NDK `SurfaceView` bootstrap；Cangjie Android runtime
  链接、产品 APK 和真机回放仍未完成。
- HarmonyOS 通过独立实现的 Ability/XComponent 或 OHNativeWindow Provider 消费
  同一契约。本仓不携带 ArkTS 工程或 HAP，因此不宣称 HarmonyOS 运行证明。

运行 `cuic doctor ios`、`cuic doctor android` 或 `cuic doctor harmonyos`，可把
本机工具链事实与这份公共 Provider 边界一起查看。

## 无头语义回放

`canghui.mobile-host-replay.v0` 可在不打开窗口的情况下展示阶段化 receipt，
并判断回调是否仍属于当前宿主代际。`mobileHostReplayHandler` 接受零行或多行
`actionId|lifecycleEpoch|surfaceGeneration`，逐项返回 `current`、
`stale-lifecycle`、`stale-surface` 或 `stale-lifecycle-and-surface`，同时保留
receipt 中真实的未签名、签名与真机证明状态。

消费者应在自己的 `@KModeLink` 函数中调用该 handler。这样 endpoint 仍归应用
所有，`cuic kmode diff` 也能在依赖图中提前拒绝重名。
`examples/mobile-host-replay` 展示了这一模式，并携带 iOS、Android、HarmonyOS
三份未签名 input-tree fixture。它不会生成 IPA、APK 或 HAP，无头回放也不等于
真机证明。
