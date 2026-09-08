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

标准控件挂上 `.probe()` 后，框架会把缺失的标签、角色、动作说明等补入同一个节点，
不会再生成重复的自动子节点。显式业务角色、标签和动作说明优先；真实动作归属、
控件提供的状态和焦点序号以控件为准。禁用时移除动作，密码角色不能被降为普通文本，
也不会导出密码值。这里的动作说明只用于观察，不会创建或替换事件回调。

`offscreen`、`partial`、`empty` 表示不满足完整视口可见条件，不给出坐标点击建议。
浮层存在时输出 `overlay-unverified`，因为通用 Draw IR 不足以证明某个节点属于
最上层浮层。普通可见节点也只证明布局范围，不证明任意裁剪、遮挡、原生 Surface
和自定义命中逻辑；不要将 `unverified-hit-coverage` 当作通过。

执行回放仍走同一个 debug probe：鼠标、键盘、文本先进入浮层栈；Tab 服从
对话框焦点约束。浮层存在时直接 `focus id` 会拒绝，使用 `key Tab`；关闭浮层后
可用当前焦点环中的控件 key，或单个控件的 `.probe("id", ...)` ID 聚焦。
后者由框架读取真实控件焦点归属，不从 `actionOwner` 等描述字段推断；禁用、失效、
无单一焦点归属的容器及与另一控件 key 同名的歧义 ID 都会拒绝。
`advance N` 只派发一次 N 毫秒 Frame，避免动画和计时
在测试里翻倍。摘要失败或节点不存在时命令返回非零。

## 按动作选择回放提示

ASCII 对明确声明语义动作的标准控件给出 `probe.focus`、`probe.activate`、
`probe.increment`、`probe.decrement`、`probe.dismiss`，只列当前状态支持的动作。
例如滑块增减数值，而不是点击中心；排序握点先激活抓取，再增减预览位置，最后激活提交
或取消退出。每一步之后重新观察，不要把旧帧的动作列表当作永久权限。

```text
probe.increment="focus volume\nkey Right"
```

引号内是转义文本：将 `\n` 解码为真实换行，作为已有 probe 的 `--events` 输入。
例如：

```bash
cuic prntx . settings.main --format ascii --events 'focus volume
key Right'
```

这些提示来自控件的类型化动作和当前焦点归属，不从 `action`、`shortcut` 或
`actionOwner` 描述中拼装指令。禁用、视口不完整、浮层未验证或焦点歧义时不生成动作提示；
焦点 ID 含 ASCII 空白／控制字符、分号、双引号、反斜杠或超过 224 个码点时也不生成，避免
指令无法解析或被图例截断。自绘区域未提供类型化契约时，原有中心坐标候选提示仍保留，
不能据此推断排序、调整数值等行为已经支持。回放后仍须检查实际值或回调，不只检查派发成功。

`prntx` 不连接任意现有进程，不绕过 release 的控制通道限制。需要运行态语义行为，
继续使用已有 debug `shell snapshot/diff`；需要字体、材质、抗锯齿和最终观感，
继续使用 `cuic prnt`。两者都不能代替真实平台的输入／合成验收。

可回放示例：`tools/release-fixtures/overlay-motion` 的 `overlay.motion`。
更多说明见 [probe](probe.zh-CN.md) 和 [Agent UI 验收](../guide/how-to/agent-ui-review.md)。
