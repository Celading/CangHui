[cui](../../index.md) › [cui.core](index.md) › ControlSemantics

# ControlSemantics

`ControlSemantics` 描述组合控件的唯一外层语义动作。

```cangjie
public struct ControlSemantics
```

字段包括 `role`、`label`、`value`、`action`、`shortcut`、`actionOwner`，以及可选的 `selected`、
`expanded`。`recordControlSemantics(frame, widgetType, semantics)` 在 ComponentProbe 活跃时记录一个
interactive semantic region，并把后代标记为 `decorative`。

Button、Chip、Checkbox、Dropdown 闭合面、Accordion header、IconButton、Switch、RadioButton、Slider、Picker、
Stepper，以及 Rating、Breadcrumb、Pagination、StepIndicator 已自动记录，无需为每个内置控件手写
`.probe(...)`。JSON 保留完整属性；ASCII 图例展示 role/label/action/value/state 与可执行的坐标探针。

该契约用于无图验证和未来平台 adapter 输入；它不声称当前已完成 macOS、iOS、Android 或 HarmonyOS
原生 accessibility tree 映射。
