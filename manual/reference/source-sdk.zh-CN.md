# 离线源码 SDK 候选包

这条交付路径把框架当成不可变依赖，而不是应用需要修改的仓库。当前导出器仅覆盖
**macOS arm64、Cangjie 1.1.3**；最低 macOS 版本取实际 Mach-O 依赖的最高要求，
不能把编译器默认目标版本当成兼容证明。此分支提供候选构建工具，不代表已有公开发布。

## 消费方式

从可信来源核对归档 SHA-256，再解包到固定目录。包内校验值用于检查完整性，不能代替
发布者认证。编译器需另行安装；SDK 内不要创建应用、编辑源码或运行原地构建。

```bash
/path/to/sdk/bin/cuic version
/path/to/sdk/bin/cuic init Hello --canghui-path /path/to/sdk/framework
/path/to/sdk/bin/cuic build macos Hello
/path/to/sdk/bin/cuic-debug prntx Hello welcome.main
/path/to/sdk/bin/cuic-debug prntx Hello welcome.main --events 'key Tab' --format diff
/path/to/sdk/bin/cuic-debug prnt macos Hello --output preview.png
/path/to/sdk/bin/cuic package build macos Hello
```

SDK 新模板采用 `WindowScaleSettings()`：跟随系统显示缩放，UI zoom 默认 1，绘制和输入
共享坐标变换。程序可通过既有窗口缩放接口切换 zoom，见[坐标与 DPI](input-coordinates-and-dpi.zh-CN.md)。
旧 Git 默认模板仍与它锁定的公开 SDK 配对，不会暗中引用该提交没有的接口。

`cuic` 是 release 工具，拒绝模拟和观察入口；`cuic-debug` 是明确分开的开发工具。
不要将后者或 debug 应用作为产品分发。`prntx` 的协议范围见[无图观察](prntx.zh-CN.md)。
运行真实窗口的一次性 `cuic-debug shell` 同样使用已验证的原生缓存，不要求在只读
SDK 内创建 `sdl/.sdl3`，也不需要使用者手动设置动态库路径。

需要 Kit 时，在同一应用增加可选依赖，两个路径必须指向同一 SDK：

```toml
[dependencies]
chui = { path = "/path/to/sdk/framework" }
canghui_kit = { path = "/path/to/sdk/framework/packages/kit" }
```

Kit 的界面组合在应用内修改，不修改依赖，见[设计套件](canghui-kit.md)。这仍是源码编译，
不是预编译 Cangjie 模块或任意编译器 ABI 之间可互换的二进制 SDK。

## 实际包含什么

- 同一 Git 提交导出的 `chui`、SDL 包、可选 Kit、公共文档与字体许可证；不包含治理资料、Git 或构建缓存。
- 同一提交重新构建并嵌入来源信息的 release/debug CUIC；当前静态链接仓颉运行时，裸运行不依赖工具链动态库路径。
- SDL 及其传递动态依赖，重定位到包内引用；实际最低系统版本、依赖版本、许可证和来源记录。
- 框架 `LICENSE`、`NOTICE`、`THIRD_PARTY_NOTICES.md` 原文同时保留在框架目录和
  `licenses/canghui/`，随 SDK 应用打包携带；该提交含 Unicode 许可证时也一并保留。
- 完整文件校验账本。启动构建时核对提交、工具版本、编译器、目标、系统要求及文件覆盖；
  拒绝错误配对、未登记文件、符号链接和校验失败，不在消费者缓存内修补框架。

导出时，SDL 的 FFI 路径明确投影到包内 `native/`，这一差异记录在清单中。普通源码不变；
SDK 的框架源码归属仍指向原提交，投影后的文件由独立校验账本绑定。

SDK 构建采用 CJPM 单任务依赖扫描，避免在此工具链版本中复现的大型并发扫描管道等待。
这是构建可靠性适配，不是 UI 线程或应用运行时的并发限制。

SDK 模板使用静态仓颉运行时。它的 macOS `.app` 打包会验证动态依赖、携带原生闭包和
许可证，使用应用内相对搜索路径，并写入真实最低系统版本。附加未知动态库会拒绝打包，
不会伪报闭包完整。非 SDK 消费仍保留原有宿主管理运行时的路径。
SDK 模板通过 `ApplicationPaths.basePath()` 定位应用包内 `canghui-sdk/fonts/`，不依赖启动目录。
已有应用沿用自己的字体策略；若使用此默认字体，也需从该路径登记 `Fonts.registerBundledFallback`。
产物不是发布者签名、公证完成态；ad-hoc 可执行签名仅用于本地加载，公开分发另行验收。

## 校验与升级前比较

新版 CUIC 提供两个只读命令；普通 release 工具即可使用，不会执行候选包里的程序：

```bash
cuic sdk verify /path/to/sdk/framework --json
cuic sdk compare /path/to/current/framework /path/to/candidate/framework --json
```

它们检查整个文件账本、框架与 Kit 的包名/版本，并报告候选包的声明版本、最低系统要求、
当前宿主前置条件及是否与正在运行的 CUIC 配对。校验账本要求普通文件且不超过 4 MiB，
SDK 清单不超过 16 KiB，包清单不超过 64 KiB。v1 仅接受三段数字的稳定包版本和上述
macOS arm64 / Cangjie 1.1.3 组合；编译器版本和目标必须精确匹配。

账本中的每个载荷都必须是普通文件；目录、命名管道、socket 和符号链接会在哈希前
被拒绝，避免校验因读取特殊文件而等待。校验不保证另一个同权限进程同时替换文件时的原子性。

`ok: true` 表示完整性和包身份检查通过，**不是认证发布者、验证原生二进制可运行或批准升级**。
同时检查 `hostPrerequisites` 和 `pairedWithThisCuic`。`higher/lower/equal` 只比较声明的包版本；
不同 Git 提交返回 `different-commit-order-unknown`，不会假定候选提交一定更新。
相同源码提交也可能重新构建，`samePayloadLedger` 单独比较文件账本。

升级时保留旧 SDK，将候选放在新目录，用候选自带的 CUIC 在应用分支中构建、测试和回放，
再修改应用依赖。失败时还原该分支的依赖与 lock，继续用旧 SDK；不要覆盖旧包或编辑它的缓存。
命令不会修改依赖、下载新版或访问发布目录。目前没有官方更新索引可供自动发现“最新版本”，
因此候选位置仍由使用者明确提供。

## 维护者导出

先提交需要交付的源码，再从该精确提交导出到一个不存在的新目录：

```bash
python3 scripts/build-source-sdk.py --revision <commit> --output /tmp/chui-sdk-candidate
```

导出器要求本机已具备编译器、Homebrew 原生依赖及其许可证，过程不下载或安装依赖。
会同时生成目录与 `.tar.gz`，输出归档校验值。需要实际完成新目录消费、无图/像素回放、
只读 SDK、禁网/禁 Homebrew 测试和应用搬迁测试后，才能提升交付状态。
