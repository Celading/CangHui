# prntx：先读界面，再看像素

`prnt` 看框架像素，`prntx` 看可重复回放的界面结构。新入口需要匹配的
源码版 debug CUIC 和支持 observation/v1 的 CangHui；旧 SDK 不会因只更换
命令名而获得新协议。安装包版本配对以其交付清单为准。

```bash
cuic prntx . settings.main
cuic prntx . settings.main --format tree
cuic prntx . settings.main --format json --limit 16
cuic prntx . settings.main --node toolbar.save
cuic prntx . settings.main --format diff --events 'key Tab'
cuic prntx . settings.main --format ascii --columns 96 --rows 32
```

- 默认摘要包含视口、输入变换版本、快照摘要、稳定节点 ID／父 ID、矩形、
  可见范围、交互状态和现有 UI 健康检查的诊断。`--node` 显示指定节点与直接子节点。
  `--format tree` 按父节点优先输出层级，缩进深度最多 64 层。
- 诊断保留 `info`／`warning`／`error`；JSON 另含 `evidenceSource` 和 `suggestion`。
  诊断总数不等于缺陷总数，例如对比度证据不足是 `info`，不是已确认的颜色错误。
- `--format json`（或 `--json`）输出 `canghui.observation/v1`，不混入构建日志。
  不附加控件原始值、事件文本、Draw IR、工作目录或原生句柄；密码角色的标签也会脱敏。
  应用自己提供的普通标签、ID、图标和动作绑定描述仍可见，不应在这些字段嵌入秘密。
- `--format diff` 输出本次 probe 初始帧与脚本后最后一帧的差分 JSON，
  复用 DesignSnapshot 的结构、几何、样式、状态、绘制五类变化。不是跨进程监视器，
  也不是 `probe diff` 的重名检查。摘要不是密码学签名。
- 摘要／JSON／差分每组默认最多 32 条，`--limit` 范围 1–128；明确报告省略数。
  文本字段最多 256 个码点，截断会标注。节点筛选目前要求不含空白的稳定 ID。
- ASCII 保留旧 `pview`／`probe ascii`，默认最多 128 个图例，超过后报告省略数；
  格内英文文本不再被语义标记覆盖。中文完整标签仍以图例／摘要为准。

## 不把“有节点”当成“能点击”

观察范围是已注册 probe／语义信息的节点，不是自动识别所有自绘像素。
缺少语义的 Canvas、图像文字或自定义组件需要补充稳定节点，不能把未列出当成不存在。

`offscreen`、`partial`、`empty` 表示不满足完整视口可见条件，不给出坐标点击建议。
浮层存在时输出 `overlay-unverified`，因为通用 Draw IR 不足以证明某个节点属于
最上层浮层。普通可见节点也只证明布局范围，不证明任意裁剪、遮挡、原生 Surface
和自定义命中逻辑；不要将 `unverified-hit-coverage` 当作通过。

执行回放仍走同一个 debug probe：鼠标、键盘、文本先进入浮层栈；Tab 服从
对话框焦点约束。浮层存在时直接 `focus id` 会拒绝，使用 `key Tab`；关闭浮层后
可聚焦当前焦点环中的 ID。`advance N` 只派发一次 N 毫秒 Frame，避免动画和计时
在测试里翻倍。摘要失败或节点不存在时命令返回非零。

`prntx` 不连接任意现有进程，不绕过 release 的控制通道限制。需要运行态语义行为，
继续使用已有 debug `shell snapshot/diff`；需要字体、材质、抗锯齿和最终观感，
继续使用 `cuic prnt`。两者都不能代替真实平台的输入／合成验收。

可回放示例：`tools/release-fixtures/overlay-motion` 的 `overlay.motion`。
更多说明见 [probe](probe.zh-CN.md) 和 [Agent UI 验收](../guide/how-to/agent-ui-review.md)。
