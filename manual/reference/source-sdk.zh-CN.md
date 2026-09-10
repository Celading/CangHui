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
若 Release 工具拒绝 `shell`、`prntx` 或 probe，请切换到**同一 SDK 内**的
`bin/cuic-debug`，不要修改只读 SDK 或从其他提交复制一个调试工具进来。
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

### Linux/glibc 源码 SDK

同一 `sdk verify`／`sdk compare` 入口现在也能只读检查 Linux 的 v2 候选清单。
v2 使用 `target=linux-arm64` 或 `linux-x86_64`，并以 `libc=glibc`、
`minimumLibc=<版本>` 单独记录 C 库要求，不复用 macOS 的 `minimumOS`。
库列表同时要求 SDL 的链接名和运行时加载名；载荷仍须是逐文件校验的普通文件，
不接受符号链接或混入 glibc 系统基础库。Linux 宿主使用 `sha256sum` 校验账本。

预检核对编译器的完整版本／目标，以及 `getconf GNU_LIBC_VERSION` 返回的 glibc
版本；这不验证所有符号版本、CPU／内核要求或原生库能否加载。同一源码提交、同一
CUIC 版本但目标平台不同，也不会显示为 `pairedWithThisCuic: true`。

当前配对工具支持 Linux SDK 初始化、同宿主构建及运行包组装。旧候选的工具可能仍返回
`targetExecutionImplemented: false`；请升级整套配对候选，不要改清单绕过校验。
上一节的 macOS v1 SDK 消费方式保持不变。
目标实现、工具配对和宿主前置条件是三个独立检查；目标已实现不代表另外两项已通过。
普通 Linux 源码工程仍可使用[显式运行包组装](application-packaging.zh-CN.md#用-cuic-组装-linux-运行包)。

```bash
/path/to/sdk/bin/cuic init Hello --platform linux --canghui-path /path/to/sdk/framework
/path/to/sdk/bin/cuic build linux Hello
/path/to/sdk/bin/cuic-debug prntx Hello welcome.main
/path/to/sdk/bin/cuic-debug prnt linux Hello --output preview.png
/path/to/sdk/bin/cuic package build linux Hello --output dist/runtime
```

本地 SDK 路径依赖会自动使用已校验的 SDK 原生清单，不要求使用者重新寻找 SDL
或复制清单。打包从应用 ELF 出发选取已声明的传递依赖，缺少依赖时失败，不搜索
宿主补库。显式 `--runtime-manifest` 仍使用项目内清单及原有严格校验，可用于额外
原生依赖；动态 `dlopen` 插件不在静态依赖选择证明内。
构建仍需要单独的 Cangjie1.1.3，打包还需要 Python3、GNU readelf 和 patchelf；
应用图形运行需要相应桌面／显示服务。未完成实际安装验收不能宣称桌面分发完成。

升级时保留旧 SDK，将候选放在新目录，用候选自带的 CUIC 在应用分支中构建、测试和回放，
再修改应用依赖。失败时还原该分支的依赖与 lock，继续用旧 SDK；不要覆盖旧包或编辑它的缓存。
命令不会修改依赖、下载新版或访问发布目录。若已有可信发布方提供的索引，可先发现候选，
再取得归档并使用上述完整校验与比较流程；不能把索引声明当成已验证的候选载荷。

### 从显式发布索引发现候选

```bash
cuic sdk updates /path/to/current/framework \
  --index /path/to/releases.index --sha256 <externally-trusted-index-sha256> \
  --channel stable --json
```

该只读命令先核对索引哈希，再验证当前 SDK 的完整账本和包身份；普通 release CUIC 也可使用。
省略渠道时为 `stable`，`preview` 必须显式选择。只匹配当前 SDK 的精确目标，不因运行宿主不同
而推荐另一个架构。不同提交不推断时间先后；任一组件版本下降或编译器变化都会要求人工审查。
即使源码与版本相同，也不会声称两个归档相同。最低系统／glibc 要求随候选报告，须自行核对，
随后用取得的候选执行 `sdk verify` 和应用回归。

索引是 UTF-8、LF 换行的制表符分隔文件（不是 TOML 或 CSV）。第一行固定为
`canghui.sdk-release-index/v1`；第二行按下表顺序使用字段名，以实际 TAB 分隔。
后续每行一个候选，允许最后一个 LF，不允许空白行、引号转义、注释或额外字段。

| 字段顺序 | 含义 |
|---|---|
| `channel`, `target` | stable/preview；macos-arm64、linux-arm64 或 linux-x86_64 |
| `frameworkVersion`, `kitVersion`, `cuicVersion`, `compilerVersion` | 各自的三段数字版本，不能用 Git 顺序替代 |
| `sourceCommit` | 完整 40 位 Git 提交 |
| `archiveSha256`, `archiveUrl` | 归档的 64 位小写十六进制摘要和 HTTPS 地址；仅返回、不访问 |
| `minimumOS`, `minimumLibc` | macOS 只填前者，Linux/glibc 只填后者；另一列保留为空 |

文件上限 256 KiB、64 个候选；同一渠道／目标只能有一条声明。拒绝未知目标、重复项、
目录、符号链接和特殊文件。URL 不接受用户信息、端口、片段或空白字符。
与现有 SDK 文件验证一样，读取过程不保证抵御同权限进程并发替换文件；请使用自己控制的本地文件。

`indexDigestVerified: true` 只证明与调用者提供的摘要一致。摘要应从已验证来源独立取得，
不能仅对未知索引现场算一个摘要便视为信任。`publisherAuthenticated`、`candidatePayloadVerified`
始终为 false；命令不证明索引新鲜度、发布者签名或全网“最新版本”，也不自动安装。
目前仍无默认官方更新服务；自建渠道可以使用此协议，公开发布索引和认证分发须独立完成。

## 维护者导出

先提交需要交付的源码，再从该精确提交导出到一个不存在的新目录：

```bash
python3 scripts/build-source-sdk.py --revision <commit> --output /tmp/chui-sdk-candidate
```

已有可用 CUIC 时，可追加 `--cuic /absolute/path/to/cuic`，让 release/debug 工具构建
都经过 CUIC。导出器为它准备同一提交的临时源码环境，不改安装版工具、全局环境或原仓库。
指定 CUIC 失败即停止，不会悄悄退回 CJPM；未指定时保留首次引导用的直接 CJPM 构建方式。
Linux 导出器也支持相同参数。

导出器要求本机已具备编译器、Homebrew 原生依赖及其许可证，过程不下载或安装依赖。
会同时生成目录与 `.tar.gz`，输出归档校验值。需要实际完成新目录消费、无图/像素回放、
只读 SDK、禁网/禁 Homebrew 测试和应用搬迁测试后，才能提升交付状态。

### Linux 候选导出（开发中）

在对应架构的 Linux/glibc 宿主上，准备 Cangjie 1.1.3、GNU readelf、patchelf，以及
[显式原生输入清单](application-packaging.zh-CN.md#用-cuic-组装-linux-运行包)，再运行：

```bash
python3 scripts/build-linux-source-sdk.py --revision <commit> \
  --runtime-manifest /path/to/native-input.json --output /tmp/chui-linux-sdk-candidate
```

输入清单须声明 SDL 两个加载名 `libSDL3.so.0`／`libSDL3_ttf.so.0`，不声明其链接名；
导出器会生成内容相同的普通文件链接副本。所有依赖都必须显式提供哈希与许可文件，
默认字体须与选定源码提交一致；不自动搜索宿主库，也不复制 glibc 基础库。
支持导出策略的目标为 Linux arm64/x86_64；某个架构的运行验证不能代替另一个架构的验证。

候选携带同一提交的 release/debug CUIC、框架与 Kit 源码、原生库、字体、许可记录和
完整 SHA256SUMS。ELF 审计逐项检查 SDK 声明库及其传递依赖，glibc 下限来自这些文件
的符号需求，不是兼容性承诺。`runtime/native-input.json` 中的资产路径可随候选搬迁，
配对 CUIC 会按应用实际依赖选取运行库，不能将整个 SDK 库集合无条件当作应用运行包。

导出成功状态是 `exported-not-consumer-verified`，仍须实际运行消费流程才能提升验收状态。
候选不是安装器、预编译框架、已签名发行包，也不证明桌面安装、动态插件和分发许可合规。
