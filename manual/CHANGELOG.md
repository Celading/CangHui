# CangHui Changelog

本 changelog 是公开面版本记录；内部治理细节见 Cangku `_helper/changelog`。

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
