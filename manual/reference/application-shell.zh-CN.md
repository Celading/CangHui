# 应用 Shell

[English](application-shell.md) | **中文**

`chui.system` 是 CangHui 的系统级应用能力契约。应用身份、资源、Action、设置、
通知、菜单和状态项保留在同一个仓颉模型中；平台 Provider 明确报告对应能力是
native、fallback、permission-required 还是 unsupported。

```cangjie
let manifest = ApplicationManifest(
    AppIdentity("Demo", "dev.example.demo", "1.0.0"),
    actions: [AppAction("file.open", "Open")],
    applicationMenu: Some(AppMenuBar(menus: [
        AppMenu("file", "File", actionIds: ["file.open"])
    ]))
)
let shell = ApplicationShell(manifest)
let surfaces = shell.projectSystemSurfaces()
```

默认的 `HeadlessSystemShellProvider` 用于 kMode、CI 和不支持原生能力的宿主。
它提供确定性回放，但 fallback 或 queued 结果不等于真实系统能力已经完成。

## macOS 原生菜单

显式选择 `desktopApplicationShell(manifest)`，交给桌面应用管理。
原有 `ApplicationShell(manifest)` 仍使用 Headless Provider，不改变默认行为。

```cangjie
let shell = desktopApplicationShell(manifest)
shell.registerAction(AppAction("file.open", "打开", shortcut: Some("CmdOrCtrl+O")),
    { => openDocument() })
let app = DesktopApp(WindowSpec("Demo", 800, 600), applicationShell: Some(shell))
app.run { Label("使用文件菜单打开文档") }
```

macOS 下会挂载 AppKit 应用菜单、自定义动作菜单和 Window 菜单。About 使用
manifest 的应用名和版本；窗口命令交给原生响应链处理。只有声明、尚未绑定 handler
的动作会禁用；挂载后也可以绑定。原生回调只入队，应用再派发 handler，避免在
AppKit 回调中执行业务。注册、菜单更新和生命周期调用都必须在原生主线程进行。

多窗口使用 `DesktopApplication(applicationShell: Some(shell))`，各窗口共用一个
Shell。其 `pump()` / `run()` 负责挂载和派发；单独调用 `pumpOne()` 只路由一个原生
事件。单窗口 `run()` 退出和应用关闭时会卸载。自定义宿主自行调用 `attach()`、
`dispatchPendingActions(limit: 64)`、`detach()`。卸载后不能重挂同一实例；新的应用
生命周期使用新 Shell。同一进程只允许一个原生 Shell 持有菜单。

替换菜单会断开旧动作对象并清空待派发队列；卸载时，若菜单仍由本 Provider 持有，
恢复原有菜单。整个过程不替换 SDL 的 application delegate。原生队列最多容纳
256 个动作，溢出明确失败，不提供远程控制入口。

本 Provider 的 `ApplicationMenu` 和 `Badge` 报告 native；设置仍是内存 fallback。应用图标、
Dock 动作、状态项、通知以及系统 Deep Link 注册尚未通过此 Provider 接通。系统命令标签暂为
英文；其他操作系统下此工厂选择 Headless Provider。图标打包、签名和分发与原生菜单
是分别验收的能力，见[应用打包](application-packaging.zh-CN.md)。

## 应用徽标

```cangjie
shell.setBadge(Some("3")) // macOS Dock 上的系统徽标；可在 attach 前排队
shell.setBadge(Some(""))  // 清除；类型明确的 ?String 空值同样可清除
```

这是应用级状态，多窗口共用一个徽标，不是界面内的 `Badge` 组件，也不是 Dock
右键菜单或通知。字体、颜色和长文本裁切由系统决定。挂载前返回 queued，挂载后
在原生主线程设置并返回 applied；卸载后返回 failed。NUL 文本在修改前拒绝。
未调用 `setBadge` 的 Shell 不改变原徽标。首次设置时保存原值，卸载时只有当前值
仍等于最后一次设置值才恢复；其他宿主设置了不同值时保留它。相同文本的外部写入
无法区分所有者。实现不替换 Dock 图标、content view 或 SDL delegate。

旧 Provider 无需实现新方法：`SystemShellBadgeProvider` 是可选 SPI，缺少时返回
unsupported。Headless Provider 返回 queued，`capturedBadge()` 只供确定性检查，
不代表操作系统显示。其他平台尚未提供本能力的原生实现。

## 稳定 Action 标识

Action 使用 `file.open`、`app.settings`、`app.quit` 这类带分段的稳定 ID。
应用菜单、状态项、通知按钮、应用内命令和 kMode 都引用同一个 ID。重复 ID、
未知引用和同 URI 冲突路由会在进入平台 Provider 前失败。

```cangjie
shell.registerAction(AppAction("app.settings", "Settings"), { => openSettings() })
shell.invokeAction("app.settings")
```

`AppMenuBar` 与 `AppStatusItem` 只保存稳定 Action ID。
`projectSystemSurfaces()` 会通过同一 Provider 边界投影菜单和状态项，并返回
`AppSurfaceProjectionResult`。

## 通知与 Deep Link

通知权限状态包括 `not-determined`、`granted`、`denied`、`not-required` 和
`unsupported`。权限未确定时使用 `requestNotificationPermission()`；其结果会
明确表示 applied、queued、denied 或 unsupported。`notify()` 在权限不允许时
拒绝投递。Headless 回放使用 `not-required` 并记录 queued，不冒充操作系统投递。

Deep Link 使用精确 URI 匹配，不提供通配或前缀匹配：

```cangjie
let route = AppDeepLinkRoute("demo://app/settings", "app.settings")
shell.registerDeepLink(route)
shell.handleDeepLink("demo://app/settings")
```

目标 Action 必须已经声明或注册；真正处理 URI 时还必须存在运行时 handler。
通知携带的 Deep Link 也必须对应已声明或注册的路由。

## 能力状态

| 状态 | 含义 |
| --- | --- |
| `native` | 平台 Provider 已接入真实系统能力。 |
| `fallback` | CangHui 提供可见或无头替代。 |
| `permission-required` | 系统 API 存在，但需要用户授权。 |
| `unsupported` | 当前宿主或 Provider 不支持该能力。 |

公开契约见
[`canghui-application-shell-v0.json`](../../contracts/canghui-application-shell-v0.json)。
工程身份、逻辑资源、确定性规划与无签名产物见
[应用打包](application-packaging.zh-CN.md)，类型化
设置与迁移见[应用设置](application-settings.zh-CN.md)。
