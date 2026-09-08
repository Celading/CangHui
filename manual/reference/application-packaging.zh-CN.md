# 应用打包

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

资源路径必须相对于工程目录。绝对路径、`~`、包含 `..` 的路径、已声明资源树中
任意层级的符号链接以及不存在的资源都会被拒绝。递归符号链接检查可避免资源目录
在打包时引入工程外文件。图标按逻辑角色分别声明，`cuic` 不会擅自把应用图标
猜成状态栏或通知图标。应用名还必须是跨平台安全的产物名；Windows 保留字符、
设备保留名以及首尾空格或句点都会被拒绝。

## 确定性规划

```text
cuic package plan macos .
cuic package plan windows . --json
cuic package plan linux . --json
```

命令会校验 manifest，并输出身份、输入资源、预期生成文件、provider 状态和
签名门。它只生成规划，不会构建 `.app`、生成 Windows 资源、签名或发布产物。
相同 manifest、工程与目标平台会得到字段顺序稳定的同形结果。

## 无签名产物生成

```text
cuic package build macos .
cuic package build windows . --output dist/windows-input --json
cuic package build linux . --output dist/linux-input --json
```

`package build` 会生成边界明确的无签名产物，并写入采用
`canghui.packaging-artifact.v0` 结构的 `canghui-packaging-receipt.json`。
macOS 将 receipt 放在可被签名封装的 `Contents/Resources` 内，Windows 与 Linux
仍放在产物根目录。
macOS 默认输出到 `dist/<Name>.app`，Windows 与 Linux 默认输出到
`dist/<Name>`。`--output` 只接受工程内相对目录；绝对路径、越界路径和非空目录
都会被拒绝，命令不会隐式覆盖既有产物。输出目录也不能位于已声明资源目录内部，
从而避免生成中的产物递归复制到自身资源树。

在 macOS 宿主上，macOS 路由会先执行正常的锁定依赖 `cuic build`，再把真实
可执行文件复制到 `Contents/MacOS`，同时生成 `Info.plist`、`PkgInfo`、资源树和
逻辑图标角色文件。receipt 位于 `Contents/Resources`，避免下游签名时在 `.app`
根目录出现未封装文件。使用配对源码 SDK 时，打包会携带 SDK 的原生依赖、字体与
许可证；普通源码工程的原生运行时依赖仍由宿主管理。receipt 会区分这两种情况，
并记录该无签名 bundle 尚未完成启动验收，release trim/strip、发布安全审计、
发布者签名与公证均未验证。携带依赖不等于已在另一台机器通过验收。

默认情况下，Windows 与 Linux 路由可以在其他宿主上生成输入树，但不会伪装成已经跨平台编译：

- Windows 生成 executable manifest、版本资源源码、AppUserModelID、资源与图标输入。
- Linux 生成 desktop entry、`share/applications`、图标树和应用资源树。

Linux 入口保留 `application.name` 作为显示名，使用已校验的 `application.identifier`
作为启动名（例如 `dev.example.demo`）。安装时请将可执行文件或启动器以此名称放到
桌面会话的 `PATH`；输入树不负责安装。旧 Linux 安装脚本若使用显示名，需要调整
该目标名称。显示名内的空格、百分号或 `=` 不再成为命令行语法或参数占位符。
macOS 和 Windows 的产物命名保持不变。

图标字节不会被改名伪装成另一种格式。只有真实 `.icns` 或 `.ico` 使用对应原生
文件名；PNG、SVG 等输入保留扩展名，并继续作为转换或平台 Provider 门禁显示。

## 用 CUIC 组装 Linux 运行包

Linux `application-icon` 接受 PNG 或 SVG。SVG 原样放入 `scalable/apps`；
正方形 PNG 按 IHDR 尺寸放入对应 hicolor 目录，支持
16、22、24、32、36、48、64、72、96、128、192、256、512px。
CUIC 不自动缩放或转换图标；ICO、ICNS、JPEG、非正方形或其他尺寸请先导出为
上述 PNG，或使用 SVG。PNG 头部检查不是完整解码验证，仍需在目标桌面验收。
安装器应把 `share/icons` 合入目标数据目录，保留系统的 `hicolor/index.theme`，
不要用应用私有索引覆盖它。SVG 依赖桌面的 SVG 解码支持，PNG 更适合广泛分发。
目录与格式约定参见 [freedesktop 图标主题规范](https://specifications.freedesktop.org/icon-theme/latest/)。

使用已配对的本地 Linux 源码 SDK 时，`cuic package build linux` 自动校验 SDK 并从
其原生清单选取应用需要的依赖、字体及许可记录，无需另传 `--runtime-manifest`。
其他源码工程保持原来的输入树默认行为；以下显式清单可用于自定义运行依赖。

在 Linux 构建宿主上，通过显式输入清单启用运行包组装：

```text
cuic package build linux . --runtime-manifest packaging/runtime.json \
  --output dist/linux-runtime --json
```

命令先走正常 CUIC 构建流程，再复制声明的库、字体和许可说明。构建宿主需要
Python 3.11+、GNU `readelf` 和 `patchelf`。它不会下载依赖，也不会自动搜集
宿主上的库。不传 `--runtime-manifest` 时仍只生成上面的输入树；该选项不提供交叉编译。

按 [`canghui-linux-runtime-input-v0.schema.json`](../../contracts/canghui-linux-runtime-input-v0.schema.json)
准备清单：

| 字段 | 必填内容 |
| --- | --- |
| `schema` | `canghui.linux-runtime-input.v0` |
| `machine` | `AArch64` 或 `Advanced Micro Devices X86-64` |
| `libraries` | 全部非系统运行库；每项包含加载器所需的 `name`、`source`、小写 `sha256` 和非空 `licenses` |
| `font` | 一份可用于启动的字体，包含 `source`、`sha256` 和非空 `licenses` |
| `notices` | 非空的应用／框架许可说明列表 |
| `systemDirectories` | 目标 glibc 基础库的显式目录；只检查，不复制这些系统库 |

每条许可说明包含 `source` 和 `sha256`。文件来源可以是绝对路径或相对于该清单
的路径，便于选择工程外的 SDK；清单文件本身必须位于工程内。只使用可信输入：
工具只复制你明确声明的内容，不会搬走整个 SDK。库名应匹配 ELF 的 `DT_NEEDED`，
不能随意重命名，也不能把 `libc.so.6` 等系统基础库放进 `libraries`。

运行包在原有桌面入口／资源树外，增加 `bin/<identifier>` 启动器、
`bin/<identifier>.bin` 可执行文件、`lib/`、`runtime/fonts/`、`runtime/licenses/`、
`runtime/receipt.json` 和 `run.sh`。复制后的 ELF 使用包内 `$ORIGIN` 搜索路径，
不修改原始构建文件。启动器选择随包启动字体并原样转交参数，不要求设置
`LD_LIBRARY_PATH`。可执行 `./dist/linux-runtime/run.sh`，或将包的 `bin` 目录加入
`PATH`，使用 desktop entry 中的 identifier 启动。安装仍由安装器负责；不支持
在包外创建指向启动器的符号链接来代替上述入口。

Linux 启动器将清单中的 `application.identifier` 传给 SDL 的应用身份，
使 X11 窗口类与 `.desktop` 的 `StartupWMClass` 对齐。`cuic run`、`prnt` 和
调试启动也使用这个声明；没有应用声明的旧工程保留 SDL 默认行为。
不要在应用中另设冲突的 `SdlHint.AppId`。直接运行构建出的裸二进制不经过 CUIC
或打包启动器时，应自行通过已有 `ApplicationMetadata`／`AppMetadata.identifier`
设置身份。该映射不等于已验证所有桌面环境的归组、通知、菜单或 Wayland 行为。

成功组装后，产物类型为 `linux-unsigned-runtime-bundle`，`executableIncluded`
为 `true`；运行包 receipt 仍写 `assembled-not-launched`。哈希与 ELF 依赖检查
不代表已验证启动、动态插件、许可合规、签名或桌面集成。许可原文会随包保留并与
输入关联，再分发仍需审核。组装失败不会签发完整打包 receipt，但可能留下未完成的
桌面入口／资源树；检查失败输出后，重试时使用新的输出目录。

## Linux 桌面安装布局与原生验收

运行包可放在安装器管理的私有目录，并保留完整相对布局。在桌面会话的可执行
搜索目录中放置一个转发到包内 `bin/<identifier>` 的启动脚本；不要把包内启动器
直接做成包外符号链接。将 `share/applications` 和 `share/icons` 合入相应 XDG
数据目录，且不要覆盖系统 `hicolor/index.theme`。仅在终端设置 PATH 不代表
桌面启动器也能找到程序；应从桌面的应用注册表按 identifier 验收。

框架维护者可在隔离 Linux/X11 会话中，对使用 SVG 应用图标的真实 CUIC 运行包执行：

```bash
python3 scripts/verify-linux-desktop-install.py \
  --bundle dist/linux-runtime --output /tmp/chui-desktop-acceptance-new
```

输出目录必须不存在；脚本只创建私有测试前缀，验证 GIO 注册发现／启动、
图标多尺寸解码、窗口身份与关闭请求，以及可恢复移除／恢复后的新进程查询。
需要已有窗口管理器、Gtk3/GIO Python introspection、hicolor/SVG 解码器、
xdotool、xprop 和 libX11；不会替你安装依赖。它是可选验收工具，不是生产安装器，
也不证明进程退出码、持久化、系统菜单视觉、其他桌面环境或发行签名。
正式安装／卸载仍需由安装器管理文件归属，不能递归清空用户共享的数据目录。

目录约定参见 [XDG 基础目录规范](https://specifications.freedesktop.org/basedir/latest/)。

## Linux 运行包元数据预检

框架与打包维护者可以检查独立组装的 Linux 运行包，而不执行其中的程序：

```bash
python3 scripts/audit-linux-runtime.py dist/MyApp --executable bin/main \
  --system-dir /lib/aarch64-linux-gnu
```

该维护脚本需要 Python 3.11+ 和 GNU `readelf`，不负责组装运行包；上面的可选
CUIC 运行包流程在重定位后调用该检查。可执行文件须位于运行包内，
动态库放在 `lib/`。显式指定目标系统库目录；检查不使用 `ldd` 或环境变量中的
加载路径。审计宿主有合适的 `readelf` 时，也可以提供目标 sysroot 内的库目录。

退出码 0 表示依赖元数据检查通过，1 表示发现待修复项，2 表示未能完成审计。
报告包含文件哈希、架构、依赖闭包、不安全搜索路径和要求的 glibc 版本标签。
目前仅支持小端 ELF64 AArch64/x86-64 与常规 glibc 加载器。系统基础库须来自
显式系统目录，不能混入运行包；搜索路径须基于 `$ORIGIN` 且不越出包边界。

数值 glibc 下限只是随包文件声明的要求，不是操作系统兼容证明；非数值标签也
必须保留。系统符号版本、动态插件、许可、字体、实际启动、CPU／内核要求和
桌面安装仍需独立验证。启动脚本可能让残留 SDK 绝对 RUNPATH 的程序正常运行，
本检查仍会报告该路径，不会用“能启动”代替正确打包。JSON 可能含本地路径，
发布前请审查。

## macOS 图标：安装身份与运行时更新

Finder、Dock 和 About 的默认图标应随 `.app` 提供。在 `[assets]` 中将
`application-icon` 指向真实 `.icns`，然后运行 `cuic package build macos .`。
直接分发裸可执行文件不能替代 bundle 身份；PNG 输入也不会自动转换成 ICNS。

运行时可以使用已有的 `DesktopApp.setWindowIcon`。在应用 UI 线程执行，例如在
按钮回调中调用；成功返回后可以释放输入 Surface：

```cangjie
let icon = SdlSurface.create(64, 64)
try {
    icon.clear(Color.rgb(40, 130, 210))
    app.setWindowIcon(icon)
} finally {
    icon.close()
}
```

macOS 的窗口图标更新作用于应用图标，不是每个窗口独立的标题栏图标。需要恢复时，
用独立保留的原始图像数据重新设置；不要把原生 `NSImage` 对象地址当作不可变快照。
系统可以原地更新对象并重新采样尺寸，验收应检查图像内容，而非对象地址或固定像素
尺寸。这项能力不包含 Dock 菜单、徽标或通知。原生图标须通过系统 API 或系统界面
验收，`cuic prnt` 的应用内容截图不包含 Dock。

## 平台边界

- macOS 可生成本地无签名 `.app`；签名、公证、自包含运行时闭合和启动验收仍是独立门。
- Windows 生成资源编译输入；PE 可执行文件、资源编译、签名和 MSIX 发布仍未完成。
- Linux 普通源码工程默认生成桌面打包输入树；配对本地 SDK 或显式提供同宿主运行清单时，可组装无签名运行包。
  真实桌面启动、安装、托盘和通知行为仍需分别验收。

`cuic doctor` 会报告声明、引用资源和两份打包 schema 是否就绪，但就绪状态不等于
运行时或发布证明。

发布编译契约、特权通道负回放、Developer ID/Hardened Runtime 签名与公证门见
[安全边界与发布来源证明](security-and-release.zh-CN.md)。无签名
`package build` receipt 绝不是发布者或商店证据。

移动宿主使用独立的分阶段 receipt，因为平台输入树、已签名安装包和真机回放是
三类不同事实。参见[移动应用宿主](mobile-application-host.zh-CN.md)与
`canghui-mobile-host-package-v0.schema.json`。
