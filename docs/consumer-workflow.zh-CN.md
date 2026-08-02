# 轻量消费工作流

[English](consumer-workflow.md) | **中文**

CangHui 应用不需要在旁边保留框架源码仓库，也不需要把框架复制进每个工程。整个流程包含三个可以独立固定版本的部分：

- `cuic`：由 `tools/cuic` 构建并可单独安装的命令；
- 应用：普通的 CJPM 可执行模块；
- `cui`：通过 `commitId` 固定、再由 `cjpm.lock` 锁定的公开 Git 依赖。

## 安装 cuic

安装器只会稀疏获取 `tools/cuic`，编译命令，并默认安装到 `$HOME/.cjpm/bin`：

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

需要固定到经过检查的标签、分支或提交时：

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | \
  bash -s -- --ref <reviewed-branch-or-commit>
```

## 创建并运行应用

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic doctor macos
cuic build macos
cuic run macos
```

`cuic init` 还会创建 `canghui.toml`。其中的 `[scripts]` 表会被自动发现，工程可以用有名称、无 shell 的生命周期流水线替代各平台单独维护的包装脚本：

```bash
cuic check
cuic dev
cuic snapshot-ui
```

流水线中的每一步仍是普通 `cuic` 命令。除非某一步显式指定支持的平台，否则平台选择跟随当前宿主。脚本发现只读取静态工程元数据，因此即使应用尚未构建或初始化运行时状态，也可以列出和检查这些脚本。

生成工程中的依赖形态如下：

```toml
[dependencies]
cui = { git = "https://github.com/Celading/CangHui.git", commitId = "<reviewed-commit>" }
```

首次构建会在需要时让 CJPM 解析依赖。Git 源码保存在 CJPM 配置的用户缓存中，通常是 `$HOME/.cjpm/git`，解析结果写入 `cjpm.lock`。后续构建复用同一缓存。应用应提交 `cjpm.lock`；只有在明确升级依赖解析结果时才运行 `cjpm update`。

在 macOS 上，`cuic` 会在编译前把已安装的 Homebrew SDL3 与 SDL3_ttf 动态库复制到解析后的 CangHui 缓存，并在应用运行时提供匹配的动态库搜索路径和随包 HarmonyOS Sans 路径。Linux 使用 `pkg-config`，Windows 使用框架声明的 DLL 接口。适配尚未完成时，以平台 doctor 输出为准。

## 本地开发框架

只有在修改 CangHui 本身，或离线使用已经准备好的源码目录时，才传入显式路径：

```bash
cuic init HelloCangHuiDev --canghui-path ../CangHui
```

`CANGHUI_FRAMEWORK_ROOT` 也可以作为单次命令的显式覆盖。旧名称 `CANGUI_FRAMEWORK_ROOT` 仅为兼容保留。

## 范围

通过 Git 消费框架不等于已经发布到中央包仓。用户缓存按解析提交复用源码，应用工程保持小而可移植。桌面宿主验证也不代表 iOS、HarmonyOS、Android、Windows 或 Linux 的应用打包已经完成。
