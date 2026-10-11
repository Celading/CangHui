[chui](../../index.md) › [chui.text](index.md) › TextAreaVisualLine

# TextAreaVisualLine

`TextArea` 软换行测量返回的 public struct。

```cangjie
public struct TextAreaVisualLine {
    public let logicalLine: Int64
    public let startByte: Int64
    public let endByte: Int64
    public let width: Float32
    public let hardBreak: Bool
}
```

- `logicalLine`：原始文档逻辑行号，从零开始。
- `startByte`、`endByte`：显示文本中的 UTF-8 半开字节范围。
- `width`：当前字体和渲染环境下的测量宽度。
- `hardBreak`：该视觉行是否到达一个原始硬换行边界。

该结构只描述视觉投影；读取它不会插入、删除或改写绑定文本中的换行。
