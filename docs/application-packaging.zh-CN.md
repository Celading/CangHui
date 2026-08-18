# 应用打包规划

[English](application-packaging.md) | **中文**

`canghui.toml` 是工程侧的应用身份、逻辑资源与系统能力策略声明。`cuic`
读取这份声明，但平台原生 provider 仍保持独立。

## 最小声明

```toml
[application]
name = "Demo"
identifier = "dev.example.demo"
version = "1.0.0"
publisher = "Celading"

[assets]
application-icon = "assets/app.png"
resources = ["assets/data", "assets/i18n"]

[system]
single-instance = true
status-item = true
notifications = true
settings = true
```

资源路径必须相对于工程目录。绝对路径、`~`、包含 `..` 的路径以及不存在的
已声明资源都会被拒绝。图标按逻辑角色分别声明，`cuic` 不会擅自把应用图标
猜成状态栏或通知图标。

## 确定性规划

```text
cuic package plan macos .
cuic package plan windows . --json
cuic package plan linux . --json
```

命令会校验 manifest，并输出身份、输入资源、预期生成文件、provider 状态和
签名门。它只生成规划，不会构建 `.app`、生成 Windows 资源、签名或发布产物。
相同 manifest、工程与目标平台会得到字段顺序稳定的同形结果。

## 平台边界

- macOS 规划 `Info.plist`、`.icns` 位置和资源树，签名与公证仍是后续门。
- Windows 规划版本资源、`.ico`、manifest 和 AppUserModelID，签名与 MSIX 发布仍是后续门。
- Linux 规划 desktop entry、图标安装树和共享资源；托盘与通知取决于宿主 provider。

`cuic doctor` 会报告声明与所引用资源是否就绪，但就绪状态不等于运行时或发布证明。
