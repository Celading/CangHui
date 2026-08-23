---
name: canghui-full-build
description: CangHui 全量构建与验收 skill。用于在干净 checkout 上完成 CangHui 母体（根框架 + sdl + cuic）的全量构建、测试、命令面 smoke 与公开面检查。使用本 skill 前先读仓库 AGENTS/_helper 治理，再按本 skill 执行。
---

# CangHui Full Build & Acceptance

## When To Use

- 需要验证 CangHui 全量可构建/可测试（根框架、sdl、cuic）。
- 需要发布/合流前跑公开面检查。
- 需要确认 cuic 新命令可用（`pview`、`prnt --device`、`debug`、`device list`）。

## First Reads

1. `Cangku/AGENTS.md`
2. `CangHui/README.md`
3. `CangHui/manual/index.md`
4. 当前 hot rail（按仓库内部 rails 恢复）

## Environment

- macOS 主机，已安装 Cangjie SDK（`CANGJIE_HOME`）与 Homebrew SDL3/SDL3_ttf。
- 构建/测试时建议：
  ```bash
  export DYLD_LIBRARY_PATH=/opt/homebrew/lib
  ```
- 若 `sdl/.sdl3/` 缺少 macOS dylib，从已构建副本复制：
  ```bash
  cp <已有>libSDL3.dylib <已有>libSDL3_ttf.dylib sdl/.sdl3/
  ```
- Harmony 侧需要 `DEVECO_CANGJIE_HOME` / `DEVECO_OH_NATIVE_HOME`（见 HarmonyHap 交接）。

## Full Build Steps

在 `CangHui/` 根目录（或一个 main worktree）执行：

### 1. 根框架测试

```bash
cjpm test
```

期望：`TOTAL` 全绿（当前约 521+）。包含 `chui.core/desktop/media/controls/text/...`。

### 2. sdl 包测试

```bash
cd sdl && cjpm test && cd ..
```

期望：`window_state`、`draw_ir_ascii`、`renderer` 等通过。已知环境相关 ERROR（如
`globDirectoryFiltersDirectoryEntries`）若与本次改动无关，记录为环境噪声而非回归。

### 3. cuic 构建与测试

```bash
cd tools/cuic && cjpm test && cjpm build && cd ../..
```

期望：cuic 测试全绿（当前约 49+），生成 `tools/cuic/bin/cuic`。

### 4. cuic 命令面 smoke

```bash
tools/cuic/bin/cuic version
tools/cuic/bin/cuic help          # 应包含 pview / prnt --device / debug / device list
tools/cuic/bin/cuic device list   # 应列出 hdc 目标（如有设备）
tools/cuic/bin/cuic pview <probe> # 输出 ASCII 布局
tools/cuic/bin/cuic prnt --device <alias> --app <bundle> --output out.jpeg
```

### 5. 公开面检查

- `git diff --check`
- 扫描 diff/新增文件：不得含本地绝对路径、内部治理路径/术语、内部包号。
- 大文件阈值：活跃源文件 < 4000 行；超限先拆。

### 6. Harmony 准备（如涉及）

在 HarmonyHap/CangHUI 运行：

```bash
CANGHUI_ROOT=<CangHui main worktree> bash scripts/prepare-harmony-cangjiegui.sh
```

然后按 HarmonyHap 交接文档验证。

## New cuic Features (public)

- `cuic pview [project] <probe> [--columns N] [--rows M] [--events ...]`：ASCII 布局输出（`probe ascii` 为别名）。
- `cuic prnt --device <alias> --app <bundle> [--output ...]`：设备界面获取（当前为系统截屏 fallback；渲染面穿透待 Harmony 侧）。
- `cuic debug [platform] [project] [--device ...] [--app ...]`：显式调试渠道命令面。
- `cuic device list [--json]`：列出 hdc 设备。
- `WindowSpec(frameless: true)`：桌面无边框窗口（等价 `decorated: false`）。

## Boundaries

- 本 skill 只做构建/验收；不替代成员本地 truth、不改变 root 默认、不代做 release/LTS 宣称。
- Harmony 真机/DevEco 证据缺失时如实 `delivery-pending`，不编造。
