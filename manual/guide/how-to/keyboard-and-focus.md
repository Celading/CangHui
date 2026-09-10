[CangHui 指南](../index.md) › 键盘与焦点

# 让鼠标、Tab 和快捷键共享业务动作

## 目标

让主要操作既可用鼠标，也能按可预测的 Tab 顺序到达并用键盘触发；应用级快捷键与按钮、菜单调用同一业务函数。焦点决定按键应交给哪个控件，当前选择仍由业务 id 保存。

## 适用场景

表单提交、列表导航、命令面板、菜单和桌面编辑器都需要。若问题发生在模态或下拉覆盖背景内容时，先读[焦点、事件与浮层](../concepts/focus-events-and-overlays.md)。

## 准备工作

列出语义动作，例如 `submit`、`deleteSelected`、`moveSelection`、`closeDialog`。每个动作写一次启用条件、状态更新和错误处理。控件回调和键盘映射只负责调用动作，不各自复制业务判断。

## 操作步骤

### 1. 按任务顺序声明可聚焦控件

表单使用输入 → 选项 → 提交的构建顺序。首要文本输入可以在声明式构建中使用 `autofocus()`；同一控件身份只请求一次，禁用控件应从遍历中合理跳过。若条件分支卸载后重新创建输入框，它会以新身份再次执行首次聚焦。

### 2. 让控件处理标准键

按钮的 Enter/Space、列表方向键、菜单导航等优先使用控件内建行为。不要在应用根重复拦截所有按键，否则文本编辑、组合键和弹层优先级容易冲突。

### 3. 只为全局动作添加 EventHandler

保存、打开命令面板等真正全局动作可以由 `EventHandler` 捕获。处理前检查模态/输入语境和动作启用条件，并调用与按钮相同的函数。

全局 Delete 快捷键只负责发起与行按钮相同的删除请求，不复制确认或修改数组的逻辑。这样鼠标与键盘经过同一检查，也会打开同一个确认对话框。

在[模态与 Toast](modal-and-toast.md)的完整程序中，找到 `app.run` 里最外层的 `ZStack { ... }`，用下面的处理器包住它，并把原根内容整体放回注释位置。补丁只使用基页已有的模型；没有项目时会返回 `false`，让事件继续传播。

```cangjie role=patch
EventHandler(onEvent: {event =>
    match (event) {
        case UiEvent.KeyDown(Key.Delete, _) =>
            // 外层处理器先收到事件；Modal 打开时必须放行且不改 pendingId。
            if (model.confirming.value) { false } else { model.requestFirstDelete() }
        case _ => false
    }
}) {
    // 此处放回 Modal 完整程序原有的整个 ZStack。
}
```

同时把基页 `requestFirstDelete()` 的首个条件保持为 `confirming.value || projects.value.size == 0`。这一动作入口守卫是第二道边界：以后即使菜单或别的根级处理器复用它，也不能在 Modal 已打开时改写待确认对象。

还可以在 Modal 完整程序的 `Label(model.status.value)` 后加入一个工具栏按钮。它与 Delete 键调用同一个 `requestFirstDelete()`，可用于比较鼠标与快捷键是否得到同一确认对话框；按钮是否可见不改变模型守卫：

```cangjie role=variation
Button("删除第一项", {=>
    let _ = model.requestFirstDelete()
}, role: ButtonRole.Danger)
```

### 4. 把选择与焦点分开

列表选中项存业务 id。焦点移动到工具栏时，选择可以保留；排序或过滤时，选择按 id 更新。不要用“当前聚焦的屏幕行号”代替模型选择。

### 5. 测试完整键盘路径

从窗口打开开始，不碰鼠标完成主要任务：Tab 到控件、输入、切换、提交、关闭弹层。再用鼠标完成同一任务，比较最终模型状态。

## 终端或编辑器需要物理 Tab 时

在**单个已可聚焦控件**上调用 `.captureKeyboard()`。不要包住整个页面；容器没有单一焦点身份时不会启用捕获。

下面的局部示例使用已有的 `State<String>` 变量 `text` 和应用自己的 `sendTerminalTab(shift)` 函数。真实终端应把修饰器加在自己的 TerminalSurface 上，而不是用 TextField 代替终端协议实现。

```cangjie role=patch
TextField(text, key: "terminal").captureKeyboard({ctx, event =>
    match (event) {
        case UiEvent.KeyDown(Key.Tab, _) =>
            sendTerminalTab(ctx.keyModifiers().shift)
            true
        case UiEvent.KeyUp(Key.Tab) => true
        case _ => false
    }
})
```

- `true` 表示已消费；`false` 继续普通路由。未启用或拒绝捕获时，Tab／Shift+Tab 仍执行焦点遍历。
- 一旦 Tab 的 KeyDown 已被捕获，其 repeat／KeyUp 即使返回 `false` 也不会重新触发遍历或转交别的控件。普通 Tab 遍历后的 KeyUp 同样不会落到新焦点的捕获回调。
- **Ctrl+Tab／Ctrl+Shift+Tab 退出捕获**，分别移到下一个／上一个焦点；只有一个控件时清除焦点。这个组合键先于回调处理，不能被吞掉。macOS 上也是 Ctrl，不是 Command；Ctrl+Alt（AltGr）不当作退出组合键。界面应显示这项提示。
- 只派发当前活动窗口、当前有效焦点的 `KeyDown`／`KeyUp`。普通树分发不会再次调用捕获回调。已捕获 Tab 的 repeat 仍交给同一身份的最新回调；若焦点离开、窗口失焦、控件移除或弹层激活，旧 Tab 的 repeat／key-up 不会落到其他控件。必须松键重新按下才能开始下一次捕获。
- 稳定 key 在重建后继续代表同一控件，但只使用新树的回调。相同 key 被多个捕获控件占用时拒绝捕获。`.visible(false)`、`.enabled(false)`、未布局或完全位于窗口视口外的控件不启用捕获。滚动裁切不等于从焦点环卸载；需要暂停终端输入时应显式禁用或移除焦点。
- 弹层先收到事件，背景捕获暂停。该修饰器不为弹层建立另一套焦点系统。
- 使用 `ctx.keyModifiers()` 读取**该事件**的修饰键快照，不在处理时查询全局键盘状态。Ctrl+C、方向键和剪贴板快捷键的策略由应用决定。
- `TextInput` 和 IME composition 不进入该回调。不要把字母的 KeyDown 再转换成文本，否则 AltGr／输入法可能重复输入；提交文本仍由原控件处理。剪贴板也不会被自动读取或发送。

`DesktopApp`、`DesktopApplication` 与 probe 使用相同的焦点路由。共同宿主源码可供 Harmony 投影消费；这不替代具体 Harmony 宿主版本及真机键盘验收。自定义宿主应调用 `UiContext.dispatchKeyboardEvent(root, event)`，保留既有事件修饰键作用域，并在窗口焦点变化时调用 `setKeyboardWindowActive(active)`；其他事件沿用原路由。

自动化验收先用 `focus terminal` 明确前置焦点：TextField 的首次 autofocus 在 `Frame` 事件处理，首条 debug 脚本可能先于它执行。probe 的 `key` 保留现有单次 KeyDown 语义；debug shell 的 `key` 发送 KeyDown 和 KeyUp，验证时应区分这两类记录。

## 确认结果

Tab 顺序与视觉阅读一致，焦点样式可见；Enter/Space 触发正确动作；文本框中的普通按键不会被全局处理器抢走。专门回放：用行按钮为 `beta` 打开 Modal，按 Delete 后处理器返回 `false`、`pendingId` 仍为 `beta`，确认后删除的仍是 `beta`；这证明外层处理器没有越过模态边界。鼠标和键盘应得到同一成功/错误提示。排序列表后，选择仍指向同一 id。

## 常见错误

- 条件分支不断改变控件身份，导致 autofocus 被当作“首次出现”反复执行。
- 在根部拦截方向键，导致文本光标和列表导航冲突。
- 快捷键绕过按钮的禁用条件，执行本不允许的动作。
- 把焦点位置当业务选择，离开列表后详情清空。
- 只测试鼠标点击，焦点环、Tab 顺序和 Esc 关闭从未验证。
- 弹层关闭后焦点落到已不存在的控件。

## 相关 API

- [`EventHandler`](../../api/chui/core/EventHandler.md) — 应用级键盘处理。
- [`Button`](../../api/chui/core/Button.md) 与 [`TextField`](../../api/chui/text/TextField.md) — 标准焦点/键盘行为。
- [`ListView`](../../api/chui/controls/ListView.md) — 选择与方向键导航。
- [`Modal`](../../api/chui/controls/Modal.md) — 焦点和背景交互边界。

## 下一步

把共享动作与[模态确认和 Toast](modal-and-toast.md)组合，继续[文本编辑与菜单](text-editing-and-menus.md)，或到[常见问题](../troubleshooting/common-problems.md)排查焦点丢失、快捷键冲突和背景误响应。
