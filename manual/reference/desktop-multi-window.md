# 桌面多窗口运行时

`DesktopApplication` 在一个进程级 SDL event pump 下管理多个互相隔离的原生窗口。每个托管
窗口拥有自己的 `SdlWindow`、`UiContext`、`StateStore`、`SemanticRuntime`、焦点、浮层、
指针捕获和 Scene3D 登记；SDL 原始事件的窗口身份通过 `WindowId` / `SdlEventEnvelope`
保留到路由边界。

`import chui.*` 会重新导出本页类型。

## 打开和运行

```cangjie
let app = DesktopApplication()
let mainWindow = app.openWindow(WindowSpec("Main", 900, 640), { =>
    VStack { Label("Main") }
})
let settingsWindow = app.openWindow(WindowSpec("Settings", 520, 420), { =>
    VStack { Label("Settings") }
})

let _ = app.focusWindow(settingsWindow)
app.run()
```

`openWindow` 会先创建、登记并绘制一帧，但不会进入嵌套事件循环。`run()` 是基于公开的
`pump()` + `step()` 组成的便利阻塞循环；需要接进自己的主循环时，可以分别调用：

- `pumpOne()` / `pump(limit:)`：排空有界数量的 SDL 事件并返回 `WindowDispatchReceipt`；
- `step()`：为所有仍打开的托管窗口各构建、布局、绘制并 present 一帧，返回
  `DesktopWindowStepReceipt`；
- `focusWindow`、`closeWindow`、`activeWindow`、`sessionCount` 与 `windowState`：管理窗口并读取隔离状态；
- `semanticSnapshot`、`semanticDiff` 与 `dispatchSemanticAction`：按精确 `WindowId` 读取或
  路由该窗口的 revision-bound 类型化语义动作；
- `close()`：关闭全部托管窗口与最后一份 SDL runtime lease。

所有这些调用都应留在创建 `DesktopApplication` 的原生 owner 线程。不要为每个窗口另起
`DesktopApp.run()`；多个嵌套 SDL event loop 会争用同一个进程事件队列。

## 每个窗口的后台任务

在托管窗口的构建体内调用 `app.rememberTaskScope(key)`，即可复用与 `DesktopApp`
相同的后台准备／UI 提交机制。相同的 key 在不同窗口中互不共享；默认策略是
`UiTaskPolicy.LatestOnly`，也可显式选择其他已有策略。

```cangjie
let status = State<String>("尚未加载")
let _ = app.openWindow(WindowSpec("Search", 520, 360), {=>
    let task = app.rememberTaskScope("search.load")
    VStack {
        Label(status.value)
        Button("加载", {=>
            let input = "已加载"
            let _ = task.submit({=> input}, {result=> status.value = result})
        })
    }
})
```

准备闭包只能处理独立数据；UI 状态变更放在提交闭包。`step()` 在构建该窗的新一帧前
收取结果，`run()` 会持续推进这一流程。不要在 UI 线程阻塞等待工作线程，也不要用
协程 `sleep` 暂停持有原生窗口的执行流程；它恢复时可能不在原来的原生线程。

视图成功卸载、构建失败的新状态回滚或窗口关闭都会取消对应任务。关闭窗口不会
关闭其他窗口的队列；提交回调关闭自身窗口后，本次 step 不再重建或绘制该窗口。
已开始的准备工作仍是协作式取消，不会强杀线程；过期结果不再应用。只允许在本应用
当前托管窗口的构建体内记忆作用域，其他应用或构建体外的调用会被拒绝。

English: managed windows own separate queues and remembered task scopes. Workers
prepare independent values; owner callbacks apply them before the next build.
Unmount, rollback and window closure cancel obsolete results without stopping
other windows. Preparation cancellation is cooperative, not forced termination.

## 路由规则

### 请求尺寸与确认尺寸

`setWindowSize(id, width, height)` 使用逻辑内容单位，返回 `true` 表示已经向托管
窗口提交请求，不保证窗口系统立即采用了目标尺寸。正常交互中，由后续窗口事件刷新
`windowState(id)`；不要用请求值冒充实测尺寸。

需要立即读取稳定的原生状态（例如自动化验收）时，在同一原生 UI 线程显式调用：

```cangjie
let requested = app.setWindowSize(mainWindow, 960, 640)
let synchronized = app.syncWindow(mainWindow)
let measured = app.windowState(mainWindow)
```

`syncWindow` 等待该窗口的待处理原生状态并刷新布局／输入坐标所用的实测 metrics，
不更改其他窗口。未知或已关闭的窗口返回 `false`，原生同步超时会抛出异常。
同步成功也不表示窗口系统一定接受了请求尺寸，仍应读取 `windowState`；系统可能限制
窗口大小。它可能等待系统动画，不应放进逐帧动画路径或替代正常事件循环。

English: resize is a request; `syncWindow(id)` is an explicit native-state barrier
that refreshes measured metrics. It can block and throw on timeout. Unknown or
closed windows return false. Always inspect measured state; do not synchronize
every animation frame.

### 事件归属

- 带 `WindowId` 的指针、键盘、窗口和 drop 事件只进入对应 session。
- `Quit` 请求关闭全部窗口；单窗 `WindowCloseRequested` 只关闭目标窗口。
- 进程级手柄事件路由给活动窗口，并在焦点转移、设备断开或窗口关闭时释放归属。
- `DesktopWindowSession` 是公开的宿主扩展面；registry 保持框架受保护并由
  `DesktopApplication.registerWindowSession` / `unregisterWindowSession` 控制，避免外部绕过
  托管窗口生命周期。自定义 session 仍须保证自己的窗口身份、owner 线程和资源关闭规则。

## 当前边界

托管多窗口路径已经能够绘制普通组件以及当前 SDL CPU RGBA8 的 Scene3D shared frame，并在
present 后释放 lease，并为每窗自动提交独立语义树、差分和类型化动作路由；它尚未取得单窗口
`DesktopApp` 高级 FrameGraph、renderer effects、主题/设备旋转 transition、采集和应用 Shell
活动窗口动作的完整同等能力。
macOS 已有非跳过的双原生窗口创建、绘制、聚焦与独立关闭烟测。窗口事件 envelope 解码和
精确路由矩阵目前由确定性测试分别覆盖；本轮不把测试内直接路由 envelope 改写成真实系统
输入穿过 `SdlRuntime.pollEvent()` 的端到端回执。Linux/X11 另有虚拟显示器与软件渲染下的
双窗口创建、显式尺寸同步、绘制和独立关闭验证，不替代物理输入、GPU 或系统桌面集成证明。
Windows 在本机运行回执到位前仍不声称主机级运行证明。
