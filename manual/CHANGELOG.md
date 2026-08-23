# CangHui Changelog

本 changelog 只记录开发者可观察的公开变化。

## 0.12.0 (2026-08-24)

### 新增

- `chui.scene3d` 新增带稳定实体类型的 provider-neutral 封闭快照：`Floor`、
  `Route`、`Vehicle` 与 `UserMarker` 可投影为 slab、ribbon、box 与 marker
  四类有界调试几何，同时保留实体身份、位置与可见性。
- 可选 `packages/scene3d-bgfx` provider 增加语义顶点资源、Metal 实帧捕获与
  外部原生归档供应门禁；普通 `chui` 构建不会下载或链接 bgfx 原生库。

### 修复与集成

- macOS SDL/Metal 预览宿主会消费 quit event 并公开只读 `shouldClose()`，使正常
  预览可在关闭请求后 detach；确定性截图模式仍保持有界退出。
- `cuic package build macos` 把生成 receipt 放在
  `Contents/Resources/canghui-packaging-receipt.json`，避免 `.app` 根目录的未封装内容
  破坏严格代码签名校验；Windows/Linux receipt 路径不变。
- PineEase 0.2.0 作为外部消费者证明了产品语义映射、Canvas 2.5D fallback、
  macOS arm64 Metal 伴随预览、SDL 退出/detach 与同宿主上架候选包。消费者证明不
  扩大框架自身的跨平台或产品模型声明。
- 全量构建 skill 新增条件式 Scene3D 原生门禁，明确区分通用 provider 捕获与产品
  消费者证明。

### 仍未声称

- 语义调试几何不是产品网格、数字孪生、材质/模型导入、拾取或嵌入式 Scene3D
  视图；其他宿主运行时、发布者签名、公证、商店发布、生产与 LTS 仍需独立证明。

## 0.11.0 (2026-08-23)

### 新增

- 正式统一 **CangHui（仓绘）**、**CangHui Multiplatform** 与根包 `chui`；
  `cui.probe.v0`、`CUI_*`、`cuic`、`--cui-path` 等既有兼容标识保持不变。
- 新增类型化应用身份、普通/安全设置 provider、应用菜单、状态项、通知权限与
  deep-link 路由契约。
- 新增 macOS 无签名 `.app` 生成，以及 Windows/Linux 的确定性打包输入树与 receipt；
  签名、安装、商店发布和跨宿主运行仍是独立门禁。
- 新增 iOS、Android、HarmonyOS 的平台中立 host/package receipt 与移动生命周期、
  安全区、触摸、文件选择、存储、主题、通知和后台任务契约；这些 receipt 不代表
  完整产品宿主已经随框架交付。
- 新增装饰性 `Surface`、单动作所有者 `InteractionSurface`、组件级样式/语义与
  嵌套交互所有者的确定性诊断。
- 新增容器排版环境；`Label`、`RichText` 与 `RichSpan` 可逐字段继承字族、字号、
  粗体、斜体、下划线和删除线，并允许显式清除继承样式。
- `TextField` 增加 placeholder 契约；`RichText` 增加对齐与行距能力。

### 修复与集成

- 应用打包会递归拒绝已声明资源树中的符号链接，避免嵌套链接把工程外文件带入产物。
- 公开 manual、参考链接、版本镜像与仓库内构建 skill 纳入同一审计门禁；SDL 测试在
  release CI 中不再被降级为非阻断警告。
- `.bold()` 使用真实字体变体解析；找不到真实粗体时才保留兼容回退。容器字体设置会
  同时影响测量、布局、绘制、输入几何与延迟浮层。

### 仍未声称

- 本版本不声称 HarmonyOS 产品宿主、任意路径 Surface、Liquid Glass、平台 blur、
  原生无障碍适配、签名/商店发布或 Windows/Linux 真实宿主运行已经完成。

## 0.10.0 (2026-08-15)

### 新增

- **cuic `pview`**：把当前 CangHui 布局输出为确定性 ASCII 图（`probe ascii` 保留为别名）。
- **cuic `prnt --device/--app`**：设备界面获取命令面；当前为系统截屏 fallback，
  渲染面穿透通道待 Harmony 侧实现。
- **cuic `debug`**：显式调试渠道命令面（生产构建保持默认）。
- **cuic `device list [--json]`**：列出 hdc 设备。
- **`WindowSpec(frameless: true)`**：桌面无边框窗口（等价 `decorated: false`）。
- **`ExternalFramePlane`**：平台无关外部帧平面接口。
- **`PointerInputBridge` / `BoundedMailbox<T>`**：线程安全输入桥与有界队列。

### 变更

- 版本线 `0.9.2 -> 0.10.0`。
- 桌面 `cuic prnt` 不再依赖 `cjpm run` 参数转发（使用 `DesktopCaptureRequest`）。

### 修复 / 内部

- sdl 归属记录（`UPSTREAM`/`LICENSE`/`NOTICE`）与 Windows DLL SHA-256。
- 已闭环特性合入 main（真实桌面捕获、无头 ASCII、设备截图、调试命令面等）。

### 待办（公开）

- Harmony 渲染面穿透 capture service。
- Harmony onTouch -> PointerInputBridge 薄适配（OHOS 构建验证）。
- CangHui CI 门禁。
