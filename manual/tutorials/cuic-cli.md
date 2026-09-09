# cuic 工具链使用教程

cuic 是 CangHui 的集成生命周期 CLI。以下命令在 `tools/cuic/bin/cuic`（或安装后的 `cuic`）。

## 构建 / 测试 / 运行

```bash
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example] [--mode release|debug] [-- <app-args...>]
```

- 默认生产（release）语义。
- 项目路径支持相对路径和绝对路径。源码仓内的工具、SDL 等子包可以直接交给
  `cuic build/test`；源码仓身份按解析后的真实目录判定，不按字符串前缀判断。
  通过 `..` 或符号链接指向仓外的项目不享受源码子包豁免，声明 Git 依赖的项目仍须
  通过 commitId 与依赖锁一致性检查。安装版 SDK 不因此自动接管任意源码子包。
- 无参数时优先当前 `cjpm.toml` 项目，否则回退 `notepad` 示例。
- `run --mode debug` 构建并运行对应的 debug 产物，不回退到旧 release 文件。
- 未知参数、重复或无效的 `--mode` 在构建前报错；应用参数必须放在 `--` 后，按原值转交。
- `run` 直接继承标准输入、输出和错误流，并返回应用退出码；运行中的输出无需等到退出才能读取。
  普通运行不应用 macOS 截图专用的单处理器配置，也不自动启用调试控制通道。

## 调试渠道

`kmode` / `probe` 执行、`pview`、`shell`、`debug` 与设备截图属于特权开发面，必须使用
`cjpm build -g` 构建的 cuic。发布 cuic 会显式拒绝这些路径，只保留
`kmode diff` / `probe diff` 静态冲突检查；发布应用同样不会接受旧环境变量或
`--kmode-stdio` 注入。

调试子进程的 stdout 仍由帧协议独占。cuic 只跳过完整匹配的已知 CJPM 启动诊断（包括
空包目录的 `there is no '.cj' file ... will not be scanned as source code` 警告）；任意应用
stdout、截断警告或近似伪装文本都会在首个协议帧前明确失败，不能借通用 `Warning:` 前缀
绕过协议污染检查。

```bash
cuic debug [platform] [project] [--device <alias>] [--app <bundle>] [-- <app args...>]
```

- 显式调试渠道命令面；当前设备捕获通道为 `delivery-pending`，渲染面穿透待 Harmony 侧。

## 截图 / 设备界面获取

```bash
cuic prnt [platform] [project] [--output out.png] [--frames N] [--window <semantic-id>] [-- <app args...>]
cuic prnt [platform] [project] --device <alias> --app <bundle> --output out.jpeg
```

- 桌面：`prnt` 构建后直接启动产物，使用 `DesktopCaptureRequest`，不依赖 `cjpm run` 参数转发。
- 配对的新源码使用 SDL 内置编码器直接输出 PNG，无需 ImageMagick 或系统转换工具。
  BMP 输出继续保留；旧框架源码仍走 BMP 加外部转换工具的兼容方式。
- 原生 PNG 先写入 `<输出路径>.capture.png`，校验格式后再交付。构建或格式校验失败不会
  提前删除原有 PNG；文件交付不保证崩溃原子性。CUIC 检查 PNG 文件签名，
  不会把仅有 `.png` 文件名的 BMP 当作成功；文件签名检查不等于完整像素验收。
- 托管多窗口：通过 `--window settings` 选择 `openWindow(..., semanticWindowId: "settings")`。
  省略时在第一次应用 `step()` 选择首个存活托管窗口，不跟随系统焦点。初始化预览帧不计入
  `--frames`；目标完成采集后关闭整个应用，让 CUIC 正常返回。缺失、重名或采集中关闭的目标报错，
  不自动换窗。普通 `DesktopApp` 默认语义名称是 `main`，指定名称也必须匹配。
  `--window` 不适用于设备系统截图，且不会启用任何输入模拟通道。
  显式选窗需要运行时返回实际窗口回执；旧运行时不支持或返回名称不一致时，即使存在图片也不会报成功。
- 设备：仅调试 cuic 的 `--device <alias> --app <bundle>` 校验设备与包，当前使用系统截屏 fallback
  （输出标注为 fallback）；渲染面穿透通道待 Harmony 侧实现。

## ASCII 布局输出

```bash
cuic pview [project] <probe> [--columns <20..240>] [--rows <8..100>] [--script <file>|--events <script>]
```

- 从 recording-headless Draw IR 输出确定性 ASCII 布局，不开窗口。
- 示例：
  ```bash
  cuic pview examples/component-gallery gallery.primary-button --columns 72 --rows 20
  cuic pview coreplayer.layout --events 'press 80 35\nrelease 80 35'
  ```
- `cuic probe ascii` 是兼容别名。

## 设计硬真相导出

```bash
cuic design snapshot [project] <probe> [--version <1|2>] [--computed] [--script <file>|--events <script>]
```

- 复用已有 `ComponentProbe`，从最终采样帧导出 `canghui.design-snapshot/v1` 规范 JSON。
- 输出对齐稳定组件 ID、层级、布局、语义状态和 scoped Draw IR；相同输入的字节与 digest 稳定。
- 敏感属性入场脱敏，且命令仍受 debug 门保护；它不读取系统截图，也不开放发布态输入隧道。
- `--version 2` 在完整 v1 之上输出 typed 组件/函数跳转、声明式交互和跨端多 DPI 场景；
  省略版本时保持 v1，不会悄然改变既有 CI 字节。
- `--version 2 --computed` 额外输出 node 级最终 frame、解析后的布局/样式/排版/资源事实，
  并把 exact scoped Draw IR 按稳定 ID 归组；默认 v2 不带该字段。
- `.probe("id")` 应放在 modifier 链尾。图片可用
  `ImageView.fromResource(resources.resolve("logical-name"))` 保留逻辑身份而不暴露绝对路径。

## 一次性界面事件与无图观察

```bash
cuic shell snapshot [project]
cuic shell click [project] <x> <y>       # touch 是别名
cuic shell focus [project] <component-id>
cuic shell run [project] --events 'snapshot
click 120 48
diff'
cuic shell run [project] --window settings --events 'focus search
key CmdOrCtrl+A
text query
snapshot'
```

- `shell` 只构建并启动一个 debug 子进程；不连接任意现有 PID，不开放 socket、listener、
  stdin 控制管道，也不执行 shell 文本。白名单脚本完成后应用自动退出。
- 支持 `click/touch`、`down/press`、`move`、`up/release`、`focus`、`key`、`text`、
  `snapshot`、`diff`；最多 128 条、64 KiB。坐标事件经过正常 CangHui 命中测试，不能
  直接调用应用函数。
- `snapshot` 返回 viewport、当前焦点、可聚焦节点和交互所有者；`diff` 返回相邻渲染帧
  的新增/移除节点与焦点变化。先用它确认真实运行态，再用 `pview` 查几何、`prnt` 查像素。
- release cuic 会拒绝 `shell`，release 应用也不会保留脚本 opt-in 与结果协议标记。
- `shell run --window` 按 `semanticWindowId` 选择窗口，不使用系统当前焦点。托管
  应用有多个窗口时必须明确选择；缺失、重名或中途关闭的目标会失败，不自动转向其他窗口。
  脚本在全部窗口的初始创建完成、进入应用 `step/run` 后执行，结束或失败时关闭这次
  测试应用拥有的全部窗口。坐标以目标窗口的 UI 逻辑坐标为准，不再次应用系统缩放。
  原始 `DesktopApp` 也会校验窗口名称。显式选窗需要支持该能力的配对框架源码和
  运行时选窗回执；不能仅凭启动参数宣称选窗成功。当前只支持托管框架窗口，不操作外部自定义窗口会话。
  浮层打开时禁止按 ID 强制聚焦背景控件，请用 `key Tab`／`key Shift+Tab` 通过正常焦点路由。
- Debug `key` 支持 `Ctrl+A`、`Shift+Tab`、`CmdOrCtrl+Z` 等组合键，名称不区分
  ASCII 大小写。修饰键为 Shift、Ctrl/Control、Alt/Option、Cmd/Command/Meta；
  `CmdOrCtrl` 在 macOS 使用 Command，其他平台使用 Ctrl。重复、未知或空键会报错。
  每条命令独立携带修饰键，无前缀表示无修饰键，不读宿主键盘当时的状态。
  `a` 与 `A` 都按 SDL 的物理字母键码派发；输入大小写文字应使用 `text`，不是 `key`。
  Debug probe 复用同一语法并支持 Shift+Tab 反向遍历；发布构建的离线 probe 不新增组合键执行。

## UI 健康审计

```bash
cuic ui audit [project] <probe> [--script <file>|--events <script>] \
  [--fail-on <info|warning|error>]
```

- 输出 canghui.ui-health/v1 规范 JSON；达到 fail-on 阈值时退出码非零。
- 诊断来自语义、布局和 Draw IR 硬证据；无法证明的对比度会明确标为 unknown。
- 它不打开系统截图、不自动改源码，适合放在 pview 之后、prnt 之前。

## 生成 HarmonyOS 投影

```bash
cuic prepare harmony [project] [--json]
```

- 读取 canghui.toml 的 [harmony] 段，只写项目内声明的 generated output。
- 相同输入二次执行无写入；源、资源、框架模板或生成树漂移会失败，不覆盖人工内容。
- 生成结果提供 Cangjie source、Ability/XComponent/IME host 模板、native header 和 rawfile staging；产品身份、权限、签名仍由消费端拥有。

## 设备列表

```bash
cuic device list
cuic device list --json
```

- 通过 hdc 列出已连接设备（如 `192.168.0.108:5555`）。

## 更多

- `cuic help` 提供完整用法与 pview 教程。
- `cuic doctor [target]` 检查各平台工具链就绪度。
- 发布前运行 `scripts/verify-privileged-release-exclusion.sh`；macOS 来源、签名与
  公证门见 [`manual/reference/security-and-release.zh-CN.md`](../reference/security-and-release.zh-CN.md)。
