# CUIC UI Health Audit

UI Health 在既有 DesignSnapshot、语义、布局与 Draw IR 上给出确定性诊断，不依赖系统截图，也不自动改写应用。

```bash
cuic ui audit . gallery.primary-button --fail-on warning
```

结果协议为 canghui.ui-health/v1，包含稳定 code、severity、componentId、rectangle、evidenceSource 与公开组件建议。当前检查小/异常拉伸交互目标、无 label 的 icon action、兄弟交互重叠、内容越出 owner、重复 action owner、精确相邻边框接缝，以及前后快照的几何变化。

过高阈值只用于标准紧凑控件（Button、IconButton、Switch、Checkbox、RadioButton），
不把 InteractionSurface 文件卡片、集合或编辑器的正常高度当成按钮拉伸。
人工复核可按 `ControlDensity` 的命中高检查尺寸意图：`Compact` 为 32 vp、`Comfortable` 为 38 vp、
`Touch` 为 44 vp。当前 `cuic ui audit` 不会替控件推断密度；发现过小或异常拉伸时，先回到原型选择密度，再检查 `contentPadding`、
`minControlSize`、`iconSize` 与父布局；不要用 `.fillHeight()` 掩盖控件规格问题。IconButton 的图形尺寸
与命中区域分开检查，已有 Symbol 应通过 `SymbolName` 解析，不把一次性手绘图形当作修复。
焦点顺序冲突要求显式 `focusOrder` 证据；节点的结构序号不等于焦点顺序。
没有这项证据时不判断焦点冲突，也不表示完整焦点流程已通过。

标准控件的显式 probe 会保留同一控件的自动语义作为缺省值，避免加了 probe 后
标签、动作和焦点序号反而消失。自定义绘制仍需自行提供语义；诊断没有列出问题，
不等于未标注区域也已检查。

对前景与背景无法同时证明的原生/图片内容，contrast 必须报告 unknown，不能猜测。--fail-on 支持 info、warning、error；达到阈值时命令返回非零。该命令复用 compiler-debug probe 通道，不开放发布态输入隧道。
