[chui](../../index.md) › [chui.text](index.md) › TextAreaWrapMode

# TextAreaWrapMode

`chui.text` 包中的 public enum

定义 [`TextArea`](TextArea.md) 的逻辑行到视觉行布局契约。软换行只改变视觉排版、光标和命中位置，不改变绑定文本。

```cangjie
public enum TextAreaWrapMode {
    | NoWrap
    | SoftWrap
}
```

| 值 | 语义 |
|---|---|
| `NoWrap` | 一个以 `\n` 分隔的逻辑行始终对应一个视觉行；超出宽度的内容通过横向滚动访问。 |
| `SoftWrap` | 在视口宽度内按字素边界拆分视觉行；不写入隐藏换行，绑定文本中的 `\n`、选区、撤销和输入法替换范围保持原样。 |

`SoftWrap` 的视觉行可通过 `TextArea.visualLines(ctx, width)` 读取。每行提供逻辑行号、UTF-8 字节起止位置、测量宽度和硬换行标记；`visualLineForOffset` 与 `visualOffsetForPoint` 使用同一模型完成行号槽同步和命中测试。`NoWrap` 保留横向滚动行为，滚动条外观策略仍由应用单独决定。
