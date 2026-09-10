# 运行时语义交互

`SemanticRuntime` 把库存控件已经发布的 `ControlSemantics` 收集为一棵有界、带修订号的
进程内语义树。它供原生无障碍适配器、可信语音入口、应用内 Agent 和无图检查读取同一份
组件身份与动作事实；它不是坐标点击器，也不会创建 IPC、socket、进程附加或命令执行入口。

`import chui.*` 会重新导出本页类型。

## `DesktopApp` 自动接线

`DesktopApp` 的普通构建/布局/绘制帧会自动收集库存控件的 `ControlSemantics`。应用可为窗口
指定稳定身份、限制、来源策略与类型化动作 fallback 处理器。库存可聚焦控件会先通过框架的
普通焦点/键盘事件路径实际执行；只有内建路由拒绝时才调用 fallback：

```cangjie
let app = DesktopApp(
    WindowSpec("Semantic example", 720, 480),
    semanticWindowId: "main",
    semanticPolicy: SemanticInteractionPolicy(agent: true),
    onSemanticAction: { request =>
        // 自定义、非库存动作的受控 fallback。
        request.nodeId == "toolbar.save" &&
            semanticActionName(request.action) == "activate"
    }
)

let before = app.semanticSnapshot()
let changed = app.semanticDiff(before)
let receipt = app.dispatchSemanticAction(SemanticActionRequest(
    "main",
    app.semanticSnapshot().revision,
    "toolbar.save",
    SemanticActionKind.Activate,
    SemanticActionSource.Agent
))
```

动作必须同时匹配 `windowId`、`expectedRevision`、`nodeId`、控件声明的 action 与来源策略。
旧 revision、错误窗口、禁用控件、未声明动作和未授权来源都会得到拒绝回执。
只读节点保留其已声明的 `Focus`，但拒绝其他动作；只读不等于禁用，也不会凭空增加聚焦能力。
只读 `TextField` 可通过键盘与无障碍入口聚焦，保留选择和普通文本复制；输入和删除仍被禁止，密码复制限制不变。
只读 `TextArea` 同样保留 Tab／无障碍聚焦、选择与复制，禁用或隐藏的控件仍被排除。
两类文本控件切换到只读后，直接调用 `undo()`／`redo()` 也不会修改内容或消耗历史；恢复可编辑后才可继续撤销／重做。
`Voice` 与 `Agent` 默认关闭；`Accessibility`、`Keyboard` 与 `Gamepad` 默认允许，但真正的
宿主入口仍由应用或平台适配器持有。类型化动作不会转换为坐标、命令字符串或外部控制通道。

## 树、差分和上限

- `SemanticTreeSnapshot` 是一个窗口的一次已提交树；`SemanticTreeDiff` 按稳定 ID 报告
  `added`、`removed` 与 `changed`。构造与运行时查询都会深拷贝数组，因此调用方只能修改
  自己持有的副本，不会反向污染已提交树。
- `SemanticNode` 保存父子身份、声明顺序、逻辑矩形、role、label/value/placeholder、状态与
  类型化动作。`role == "password"` 的 value 在进入树之前强制清空。
- `TextField` 与 `TextArea` 从既有编辑状态发布 UTF-8 字节位置：`selectionStart`／
  `selectionEnd` 是排序后的选区，`selectionFocus` 是光标实际所在端点。后者为 `None`
  表示方向未知，不能默认光标位于末端。空选区三个位置相同；密码清除这三个位置。
  这些事实随快照、语义差分、probe 与设计快照传递，不创建第二套编辑状态。
- 使用带 `UiContext` 的 `recordControlSemantics` 时，已注册控件缺省的 `focused` 会从
  当前焦点状态补齐；焦点切换也会出现在语义差分中。控件显式声明的值保持不变，
  未注册节点和不带上下文的旧接口不会凭空获得焦点状态。
- 默认上限为 2048 节点、32 层、256 KiB 文本；编译期硬上限分别为 4096、64 与 1 MiB。
  重复 ID、未平衡父栈或越界帧会整体失败，不提交半棵树。
- 自定义宿主可直接使用 `SemanticRuntime.beginFrame`、`record`、`commitFrame` / `cancelFrame`；
  运行中控件的自动收集只由框架受保护的帧作用域启用。

## 原生适配器的组件身份

### 可选的文本字形坐标

启用原生文本布局后，`TextField` 和不换行的 `TextArea` 可发布 `textGeometry`。
它由不可变的 `SemanticTextLayout` 和当前绘制原点组成：`SemanticTextGlyph` 保存一个
编辑字素的 UTF-8 起止位置、硬行号、相对逻辑矩形和实际解析出的文字方向。
坐标来自正在绘制的原生文本行，不按字符数平分控件宽度。相对布局可复用；滚动和光标跟随
只更新原点，字体或布局环境变化会重新生成。快照和差分保留这些事实，目标连续性检查也
会考虑字形或原点变化。`sameContent(..., includeGeometry: false)` 才会显式忽略它们。

密码与正在显示输入法预编辑文本的控件不发布该坐标，避免泄露明文或把临时布局配给正式值。
未启用原生布局、不支持的文本／样式或无法用连续矩形表达的字素仍可保留普通文本语义，
`None` 不等于所有字符都在 `(0, 0)`。空文本／末尾换行保留一个零字节、零宽的末行位置。
自定义控件提供此数据时，必须匹配完整值及现有字素边界；构造器复制数组并拒绝不一致数据。

Linux AccessKit 可选适配器将此数据投影为字符范围和位置命中。它仍要求可信的配套桥库、
实测 X11 窗口坐标，不代表默认 SDK、Wayland、其他平台读屏或原生编辑协议已经完成。

### 会话与身份

`SemanticNativeSession` 为一个原生适配器实例管理一个窗口的节点 ID。UI 主线程把已提交的
`SemanticTreeSnapshot` 交给 `publish`，原生回调读取 `snapshot()` 的独立副本。
语义事实仍来自 `SemanticRuntime`；这一层只管理映射和生命周期，不实现平台读屏协议。

- 原生 ID `1` 留给窗口根节点，其余 ID 在会话内递增。重排、改变父节点不会更换组件身份；
  组件在已提交帧中消失后重新出现，或 role/widgetType 改变，会分配新 ID，避免旧动作误投。
- `postAction` 通过现有 `UiOwnerQueue` 排队，并在主线程执行时重新检查帧修订号、组件身份、
  动作声明和关闭状态。返回 ticket 不代表动作已生效，必须检查队列完成回执。
- 原生事件可能跨越没有内容变化的绘制帧，可显式使用 `postUnchangedAction`：只有观察版本
  至执行版本之间每一帧都已发布，且整棵有序语义树持续相同时，才生成当前版本的请求。
  任意中间变化（即使随后恢复）、漏帧、移除重建、禁用或关闭均不能借此放行。
  默认 `postAction` 不变；节点 ID 必须持续代表同一用户意图，不能暗中改绑业务含义。
- 若只是无关控件正在做位置／尺寸动画，可显式使用 `postUnchangedTargetAction`。
  每一帧的完整有序树仍须保持全部非几何信息不变，目标及其所有祖先的矩形也须连续不变。
  例如另一个按钮的悬停位移，不应丢弃固定只读输入框的聚焦请求。目标移动、弹层增删、
  文本／状态／动作变化、漏帧或变化后恢复仍会拒绝；这不是任意旧版本兼容。
  桌面原生适配接口使用这一受限方式，两个原有接口保持原来的校验范围。
- 处理器仍须调用窗口的 `dispatchSemanticAction`，由原来的来源策略和动作路由完成最终校验。
  不要直接调用业务回调，也不要把旧动作改绑到最新修订号。
- `publish` 和 `close` 由 UI 主线程调用；`close` 不可撤销。每个窗口/原生适配器实例使用独立
  session，关闭适配器时必须关闭 session。它不会自动安装系统无障碍库或注销原生回调。

## 桌面原生适配接口

`DesktopApp` 和 `DesktopApplication` 都接受可选的 `accessibility` 工厂：
`DesktopAccessibilityFactory = (String, String) -> DesktopAccessibilityAdapter`。
两个参数是窗口语义 ID 和标题；每次必须返回一个全新的适配器实例，不能跨窗口复用。
不传此参数时保持原有构建与运行方式，不自动下载或加载原生库。

适配器实现 `publish`、`setWindowFocused`、`poll` 以及 `Resource.close/isClosed`。
宿主在每次语义提交后提供完整的 `SemanticNativeSnapshot`，在已有事件循环中轮询原生动作，
并从 SDL 实测 `inputFocus` 传递窗口焦点；逻辑控件焦点仍在语义树内。每轮最多取 128 个动作，
通过该窗口原有的 UI 队列、上述目标连续性检查和最终动作策略执行，单窗口空闲时也会轮询。
`poll` 必须非阻塞；原生回调线程只能写入有界收件箱，不能直接执行组件或业务回调。

窗口关闭或适配器发布/轮询失败时，宿主先撤销语义会话再注销原生适配器，已排队动作不能
投递到已关闭或替换的窗口。某一适配器注销失败不会阻止应用关闭其他托管窗口。
工厂抛错会中止该窗口创建；已经分配但尚未返回的原生资源由工厂自行释放。

平台适配器负责库装载、原生注册、空闲时的读屏激活、坐标换算、线程和动态库生命周期。
快照矩形仍为窗口内逻辑坐标。需要几何信息的适配器另实现
`DesktopAccessibilityGeometryAdapter.setWindowGeometry`：宿主提供已有的 `WindowMetrics`、
实际 SDL video driver，以及可选的 `DesktopAccessibilityScreenBounds`（客户区 inner / 含装饰 outer）。
`DesktopAccessibilityGeometry.logicalToPixels` 复用窗口坐标变换，不计入渲染超采样。
`screen=None` 表示没有可信的屏幕原点，不表示 `(0,0)`。包装适配器时也必须转发这个伴随接口。
动作回执为 UI owner 的执行结果，不等于读屏发声证明。

## 可选 Linux AccessKit 适配器（预览）

Linux 构建可使用 `linuxAccessKitAccessibility`，把下面工厂传给任一桌面宿主：

```cangjie
let nativeAccessibility = linuxAccessKitAccessibility(
    "/opt/my-app/native/libaccesskit.so",
    "/opt/my-app/native/libchui_accesskit_bridge.so")
let app = DesktopApp(WindowSpec("My app", 720, 480),
    accessibility: Some(nativeAccessibility))
```

需要应用自己提供可信、相互匹配的 AccessKit C 0.23.0 库和本仓的 C 桥。这里只接受明确的
本地绝对路径，拒绝内嵌 NUL；不下载或自动安装。桥 ABI 及必需符号检查只检查调用契约，
不能鉴别发布者或替代哈希、许可证及依赖核验。底层 ELF 依赖解析仍遵循系统加载器规则。

适配器会缓存当前完整树。读屏服务在界面空闲之后才激活时，重放同一份树，不驱动持续
重绘、不虚增语义修订号；停用或重新激活与重放重叠时保留正确的待处理状态。
原生动作仍经过已有窗口队列和策略；发布构建也可显式启用平台无障碍，但不会开放
`cuic shell` 或任意命令/文本注入通道。

原生注销是异步的，因此库引用保留到进程退出，不能在关闭窗口时卸载动态库。
当前工厂只接受有实测屏幕坐标的 X11 后端；未知原点、Wayland 或不支持的像素密度会明确失败，
不会静默发布错误坐标。它以窗口现有 renderScale 投影节点，并提供实测客户区与装饰边界。
窗口移动更新屏幕原点；缩放或尺寸改变必须等到对应的新布局提交，空闲重放仍使用已提交布局的变换。
单行普通 `TextField` 已提供原生 Text 读取：字素边界复用编辑器索引，AT-SPI 对外使用
Unicode 标量偏移，而不是 UTF-8 字节偏移。空文本可读取；密码不投影文本子节点。
同一文本框的光标和正反向选区也映射到原生读取接口；只有精确的字素边界且方向已知才投影，
不会把字节内部位置取整或猜成光标。需要配套重建包含 `chui_ak_tree_text` 与
`chui_ak_tree_selection` 的 C 桥，旧桥缺符号会明确失败。
无软换行的 `TextArea` 也提供原生 Text 读取：LF／CRLF 保留在前一行，末尾换行后的空行不会丢失；
跨行正向／反向选区与光标映射到对应的行内位置。桥需额外提供 `chui_ak_tree_multiline`，
缺少这个符号的旧桥会在创建适配器前被拒绝，请与框架一起重建。
单行字段中的换行、多行值中的孤立 CR、超过原生 255 字节限制的单个字素仍只保留原有语义元数据。
每次原生树更新最多生成 4096 个文本行节点；超限拒绝整次更新，不截断文档伪装成功。
选择数据对应已提交文本，不包含 IME 预编辑显示区间；没有伪造字符坐标或新增原生文本修改动作。
跨显示器系统 DPI、软换行／字形坐标、原生修改选区、IME、读屏发声与 SDK 原生依赖交付尚未完成。其他平台不会
导出这个 Linux 专用工厂；不传 `accessibility` 的默认路径没有额外原生依赖。

## 当前边界

可选的 [AccessKit C 树投影桥](../../platform/accesskit/README.md) 可把已有原生 ID、父子关系、
角色与状态转成有界原生树，并拒绝无效的整树更新。另有 Linux 原生适配器的注册、
令牌撤销和有界动作收件箱源码，现可通过上述可选 Linux 工厂接入桌面宿主。
它还不是只引用依赖即可交付的完整读屏 SDK；直接使用 C 桥时仍须由调用方完成坐标投影。

这套运行时提供跨宿主的语义事实和安全动作模型，不等于 macOS AX、Windows UIA、Linux
AT-SPI 或 HarmonyOS 原生无障碍 provider 已完整实现并全部验证。`DesktopApp` 与 `DesktopApplication`
托管窗口均已自动接线，并保持独立窗口身份与 revision。调试用 `cuic shell` 仍是单独的 debug-only、
一次性回放通道，不能用语义运行时绕过发布构建的控制面隔离。
