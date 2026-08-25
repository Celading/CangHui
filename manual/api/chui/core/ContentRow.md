[chui](../../index.md) › [chui.core](index.md) › ContentRow

# ContentRow

`chui.core` 包中的 public class

三槽信息行：leading 与 trailing 按内容收缩，content 自动获得中间剩余宽度。默认 12/8 vp
水平/垂直内边距、8 vp 槽间距和 44 vp 最小高度，用于文件、会话、设置和状态列表中稳定表达
“图标—主内容—尾随信息”。

## 声明

```cangjie
public class ContentRow <: Widget
```

## 构造函数

```cangjie
public init(
    spacing!: Length = 8.vp,
    padding!: LengthInsets = LengthInsets(12.vp, 8.vp),
    minHeight!: Length = 44.vp,
    leading!: () -> Unit,
    content!: () -> Unit,
    trailing!: () -> Unit
)
```

- `leading`：前导图标、头像或短状态，按内容宽度收缩。
- `content`：标题/说明等主内容，通过 `Flexible` 获得剩余宽度。
- `trailing`：尾随状态或动作，按内容宽度收缩并保持在行尾。
- `spacing`、`padding`、`minHeight`：可覆盖默认节奏；长度按当前 UI context 解析。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ContentRow", 520, 240))
    app.run {
        ContentRow(
            leading: {=> Icon(IconName.OpenFolder)},
            content: {=>
                VStack(spacing: 2.vp) {
                    Label("ExplorerX").bold().maxLines(1)
                    Label("本地文件浏览").muted().fontSize(12.fp).maxLines(1)
                }.hug()
            },
            trailing: {=> Label("就绪").muted()}
        ).fillWidth()
    }
}
```

`ContentRow` 是布局配方，不自带选择或点击。整行只有一个动作时可在外层组合 `Button` 或
`InteractionSurface`；若 trailing 中存在独立按钮，不要再让外层拥有同一个点击动作。

## 布局行为

- 水平方向可跟随父级铺满，纵向保持本征高度。
- leading/trailing 先测量，content 获得扣除 padding、间距和两端后的宽度。
- 三槽沿交叉轴居中；焦点与交互 owner 从三个子树继续向上传递。
- 显式 `.height(...)`/`.fillHeight()` 仍可覆盖本征高度。

另见：[Agent UI 评审](../../../guide/how-to/agent-ui-review.md)、[`HStack`](HStack.md)、
[`Flexible`](Flexible.md)、[`InteractionSurface`](InteractionSurface.md)。
