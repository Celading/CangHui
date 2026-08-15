# CangHui Manual

CangHui 是 Cangjie 多平台声明式 GUI 框架。本手册是公开面入口，面向开发者与
自动化宿主（agent），与仓库 `docs/` 互补：

- `docs/`：API、架构、主题、探针、doctor 等主题文档。
- `manual/`：操作手册、构建 skill、新特性教程、实拍截图、公开 changelog。

## 目录

- [全量构建 Skill](skills/canghui-full-build/SKILL.md)
- [教程](tutorials/index.md)
- [实拍截图](screenshots/index.md)
- [公开 Changelog](CHANGELOG.md)
- [参考](reference/index.md)

## 当前公开能力速览

- 声明式 CUI 核心 + 组件族 + 无头验收（kMode/probe/pview）。
- 桌面 SDL 后端：macOS/Windows/Linux 构建路径，支持 `WindowSpec(frameless: true)`。
- cuic 工具链：
  - `cuic build/test/run/debug/prnt/pview/device list`
  - `cuic pview`：ASCII 布局输出
  - `cuic prnt --device --app`：设备界面获取（系统截屏 fallback；渲染面穿透待 Harmony 侧）
  - `cuic device list`：hdc 设备列表
- Harmony 平台根由 `HarmonyHap/CangHUI` 承接；本母体提供平台无关接口
  （`ExternalFramePlane`、`PointerInputBridge`、`BoundedMailbox<T>`）。

## 版本

当前 `cui` 版本线：`0.10.0`（见 [CHANGELOG](CHANGELOG.md)）。
