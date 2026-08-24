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

- 声明式 CangHui 核心 + 组件族 + 无头验收（kMode/probe/pview）。
- 装饰性 `Surface`、单动作所有者 `InteractionSurface`，以及可按字段继承的
  容器排版环境（字族、字号、粗体、斜体与装饰线）。
- provider-neutral 的 Scene3D 封闭快照、八类低多边形语义投影、实体尺寸/旋转与帧相机；可选 bgfx4cj
  provider 已在 macOS arm64 Metal 上验证，产品模型与其他宿主仍由各自门禁负责。
- 类型化应用身份、设置、菜单、状态项与通知契约；macOS 无签名 `.app` 和
  Windows/Linux 打包输入树保持签名、安装与运行证明边界。
- 桌面 SDL 后端：macOS/Windows/Linux 构建路径，支持 `WindowSpec(frameless: true)`。
- cuic 工具链：
  - `cuic build/test/run/debug/prnt/pview/device list`
  - `cuic pview`：ASCII 布局输出
  - `cuic prnt --device --app`：设备界面获取（系统截屏 fallback；渲染面穿透待 Harmony 侧）
  - `cuic device list`：hdc 设备列表
- HarmonyOS 宿主不随本仓库交付；本仓库只提供平台无关接口与可独立核验的
  host/package receipt 契约。

公开面审计可直接运行：

```bash
python3 manual/skills/canghui-full-build/scripts/audit_public_surface.py
```

完整构建与验收顺序见[全量构建 Skill](skills/canghui-full-build/SKILL.md)。

## 版本

当前 `chui` 版本线：`0.14.0`（见 [CHANGELOG](CHANGELOG.md)）。
