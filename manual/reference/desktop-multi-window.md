# 桌面多窗口运行时

`DesktopApplication` 在一个进程级 SDL event pump 下管理多个互相隔离的原生窗口。每个托管
窗口拥有自己的 `SdlWindow`、`UiContext`、`StateStore`、`SemanticRuntime`、焦点、浮层、
指针捕获和 Scene3D 登记；SDL 原始事件的窗口身份通过 `WindowId` / `SdlEventEnvelope`
保留到路由边界。

`import chui.*` 会重新导出本页类型。

## 原生文字输入会话

`DesktopApplication` 与 `DesktopApp` 创建窗口时不会立即启用原生文字输入。
窗口绘制出聚焦的可编辑控件后，宿主启动该窗口的文字输入；焦点转到按钮、
只读文本或不再有编辑请求时停止。只读光标、选区和快捷键复制不依赖文字输入会话。
会话请求与 IME 锚点分开，光标滚出编辑器视口不会让会话意外中断。

自定义编辑器参见 [`UiContext.requestTextInput()`](../api/chui/core/UiContext.md#requesttextinput--hastextinputrequest)。
直接使用 `SdlWindow(spec)` 的调用者仍保持旧默认：创建时启用文字输入。
如需自己管理，使用 `SdlWindow(spec, textInput: false)`，随后在窗口原生 UI
线程调用 `setTextInputEnabled(true/false)`；调用失败会抛出异常，不缓存为成功。
不要通过借用的指针绕过窗口的会话状态管理。

这控制原生文字事件和 IME 启停，不代表所有系统的候选窗、软键盘布局、密码键盘
类型或物理设备输入已经验收。已提交文字不会因为会话停止而回滚。

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

## 用 CUIC 采集指定窗口

为需要稳定定位的窗口传入唯一的 `semanticWindowId`，不要用操作系统分配的数字 ID 或标题作为
跨次运行的标识：

```bash
cuic prnt linux . --window settings --frames 24 --output settings.png
```

该命令通过现有 `DesktopCaptureRequest` 请求对应渲染器的像素。`DesktopApplication` 默认接收
CUIC 的请求，也可在构造时传入显式 `capture: Some(DesktopCaptureRequest(..., windowId: "settings"))`。
未指定名称时，第一次应用级 `step()` 选定首个存活托管窗口；不根据活动焦点切换目标。
`openWindow` 的初始化绘制不采集，避免创建第二个窗口之前就退出。选中后的渲染帧计入
`settleFrames`，写入发生在目标帧提交前，成功后统一关闭应用及其余窗口。

首个应用级采集步骤必须能找到目标；不存在或有重名时明确失败。选中窗口在完成前关闭也会失败，
不会把输出改成兄弟窗口。外部登记但不由框架管理渲染器的会话不能成为采集目标。
该路径只采集框架渲染内容，不包含系统菜单、输入法候选窗或原生子 Surface 的外部合成内容。
显式选窗时，运行时写入实际采集的语义名称，CUIC 在清理临时回执前核对它；没有回执或名称不匹配
都会失败，避免旧运行时忽略选择器、却把主窗口图片误报为目标窗口。

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

窗口失焦事件先送到该窗口的浮层，再由未消费事件落到主树；不会改派给另一个窗口。
因此 Modal 内的 TextField/TextArea 也能清理预编辑，保留返回窗口时的逻辑焦点。
这不会回滚输入法在失焦前已经提交的文字；失焦提交策略仍由原生输入法决定。

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

### 组合键使用事件快照

SDL 键盘事件的 `modifierMask` 随 `SdlEventEnvelope` 保留，单窗口缓冲和多窗口路由
不会用稍后查询到的键盘状态覆盖它。因此，即使 Shift 已在队列排空前松开，先前的
Shift+方向键、Shift+Tab 和组合快捷键仍按按下时的状态处理。

在自定义组件的 `handle(ctx, event)` 中，使用 `ctx.keyModifiers()` 判断修饰键。
`Keyboard.modifiers()` 仍是设备当前状态的轮询接口，不代表正在处理的历史事件。
`Some(0)` 表示事件明确没有修饰键；`None` 表示未提供快照，兼容原来的当前状态查询。
当前 SDL 原生快照覆盖 KeyDown/KeyUp，不声称鼠标、触摸或任意旧事件都携带历史状态。

自定义 `DesktopWindowSession` 可同时实现 `DesktopWindowInputSession`，接收
`dispatchInput(event: UiEvent, modifierMask: ?UInt16): Bool`。派发给自己的组件时，
用 `ctx.withEventModifiers(modifierMask, {=> widget.handle(ctx, event) })` 包围现有调用。
作用域仅属于该窗口上下文，嵌套调用和异常退出后恢复原值，不修改 SDL 全局键盘状态。
未实现伴随接口的旧 session 继续收到原来的 `dispatch(event)`，但无法取得此快照。
这些是应用内宿主事件数据，不新增外部注入入口；调试模拟事件仍受原有 Debug 限制。

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
