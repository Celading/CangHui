<!-- kind: how-to; audience: desktop-app-developer -->

# 组合多行编辑、菜单与快捷动作

## 目标

建立一个保留标准文本按键的编辑页：菜单触发保存动作，`TextArea` 自己处理选择、撤销和粘贴，全局快捷键只调用同一业务动作。完成约需 15 分钟。

## 适用场景

记事本、脚本编辑器、备注页和带长文本的表单。若只输入单行名称或搜索词，用 `TextField` 更合适。

## 准备工作

列出文件、新建、打开、保存等业务动作，先为每个动作写一次启用条件和状态变化。确认哪些按键已经由 `TextArea` 内建处理，哪些才是真正的应用级动作。若页面还使用 Modal，准备一个可查询的 `confirming` 状态，供根级快捷键在动作入口守卫。

## 操作步骤

### 1. 先写一次业务动作

保存动作应由模型提供，菜单点击、工具栏按钮和 Ctrl+S 都调用它。菜单项的 `shortcut` 是显示给用户的提示，不会自动安装应用级快捷键。

### 2. 让编辑器保留标准按键

不要在根部捕获方向键、Home/End、Ctrl+A/C/X/V/Z/Y。`TextArea` 已实现光标、选择、剪贴板与撤销；重复处理会让同一次按键执行两遍或抢走文本输入。

### 3. 运行菜单与编辑器

```cangjie verify role=complete profile=gui-visual
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("编辑器", 700, 460))
    app.run {
        let draft = rememberState<String>("draft") {"会议纪要\n\n- 待办事项"}
        let saved = rememberState<Int64>("saved") {0}
        VStack(spacing: 0.vp) {
            MenuBar(
                [
                    Menu(
                        "文件",
                        [
                            MenuItem("保存", {=> saved.value = saved.value + 1}, shortcut: "Ctrl+S"),
                            MenuItem.separator(),
                            MenuItem("退出", {=> ()}, enabled: false)
                        ]
                    ),
                    Menu("帮助", [MenuItem("关于", {=> ()})])
                ]
            )
            TextArea(draft).autofocus().flex()
            Label("字符数 ${draft.value.size} · 已保存 ${saved.value} 次").muted().padding(10.vp)
        }
    }
}
```

### 4. 只补真正全局的按键

```cangjie role=variation
EventHandler(onEvent: {event =>
    match (event) {
        case UiEvent.KeyDown(Key.S, modifiers) if (modifiers.ctrl) =>
            model.save()
            true
        case _ => false
    }
}) {
    editorPage(model)
}
```

具体修饰键字段以项目使用的 CangHui 版本为准；关键是只消费确认命中的组合键，其他事件返回 `false`。若 Modal 已打开，根级处理器还必须先检查模态状态，详见[键盘与焦点](keyboard-and-focus.md)。

## 确认结果

输入多行文字，使用 Shift+方向键选择，再撤销和重做，编辑行为应保持正常。用菜单执行“保存”，计数增加但文本和焦点不丢失。添加全局补丁后，Ctrl+S 与菜单调用同一动作；普通 `S` 仍进入编辑器。

接着测试输入法组合、Windows CRLF 粘贴和只读模式复制。若外部加载新文档并接管光标状态，光标与选区锚点要一起更新。打开菜单后按 Tab，应关闭菜单并把遍历交还全局焦点，而不是把用户困在下拉层。

## 原生输入法与组合文本

`DesktopApp` 和 `DesktopApplication` 在初始化 SDL 前，默认声明框架能绘制组合文本
（`SDL_IME_IMPLEMENTED_UI=composition`）。`TextField` / `TextArea` 接收预编辑事件，
选词提交前不应把预编辑内容写入文档。候选词列表仍由系统输入法负责；框架不默认声明
`candidates` 能力。

已有 SDL hint 或同名环境变量会被保留，包括显式的空值、`none` 和 `0`。
`DesktopApp` 的 `hints` 参数也可以覆盖此默认值。SDL hints 是进程级设置，不是每个窗口
独立的输入法开关；需要覆盖时应在首个窗口／SDL runtime 创建之前完成。

Linux 主机还需要可用的输入法服务及带相应支持的 SDL。`cuic prntx` 的文字注入只能验证
控件行为，不能证明原生输入法接线。验收时应使用真实输入法检查预编辑、提交、Esc 撤销、
焦点切换和不同缩放比例，再用 `cuic prnt` 检查框架像素。系统候选窗口的位置与读屏效果
须另行验证。

## 常见错误

- 以为菜单的快捷键文字会自动注册事件。
- 用字符下标修改 `TextArea` 光标：其光标与锚点使用 UTF-8 字节偏移。
- 外部移动光标却不同时移动锚点：下一次输入会替换意外选区。
- 捕获所有 Ctrl 组合键并返回 `true`：复制、粘贴与撤销失效。

## 相关 API

[TextArea](../../api/chui/text/TextArea.md)、[MenuBar](../../api/chui/controls/MenuBar.md)、[MenuItem](../../api/chui/controls/MenuItem.md)、[EventHandler](../../api/chui/core/EventHandler.md)。

## 下一步

接入真实打开/保存流程时继续[桌面文件与后台任务](desktop-files-and-background.md)。
