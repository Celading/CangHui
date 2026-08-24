# cuic 工具链使用教程

cuic 是 CangHui 的集成生命周期 CLI。以下命令在 `tools/cuic/bin/cuic`（或安装后的 `cuic`）。

## 构建 / 测试 / 运行

```bash
cuic build [platform] [project]
cuic test [platform] [project]
cuic run [platform] [project|example]
```

- 默认生产（release）语义。
- 无参数时优先当前 `cjpm.toml` 项目，否则回退 `notepad` 示例。

## 调试渠道

`kmode` / `probe` 执行、`pview`、`debug` 与设备截图属于特权开发面，必须使用
`cjpm build -g` 构建的 cuic。发布 cuic 会显式拒绝这些路径，只保留
`kmode diff` / `probe diff` 静态冲突检查；发布应用同样不会接受旧环境变量或
`--kmode-stdio` 注入。

```bash
cuic debug [platform] [project] [--device <alias>] [--app <bundle>] [-- <app args...>]
```

- 显式调试渠道命令面；当前设备捕获通道为 `delivery-pending`，渲染面穿透待 Harmony 侧。

## 截图 / 设备界面获取

```bash
cuic prnt [platform] [project] [--output out.png] [--frames N] [-- <app args...>]
cuic prnt [platform] [project] --device <alias> --app <bundle> --output out.jpeg
```

- 桌面：`prnt` 构建后直接启动产物，使用 `DesktopCaptureRequest`，不依赖 `cjpm run` 参数转发。
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
  公证门见 `docs/security-and-release.zh-CN.md`。
