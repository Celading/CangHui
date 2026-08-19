<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-CangHui-c96b2c?style=for-the-badge&labelColor=1f2430" alt="仓颉" />
  <img src="https://img.shields.io/badge/version-0.10.0-3182ce?style=for-the-badge&labelColor=1f2430" alt="版本 0.10.0" />
  <img src="https://img.shields.io/badge/package-cui-2f855a?style=for-the-badge&labelColor=1f2430" alt="包名 cui" />
  <img src="https://img.shields.io/badge/output-static-805ad5?style=for-the-badge&labelColor=1f2430" alt="静态产物" />
  <img src="https://img.shields.io/badge/focus-multiplatform%20GUI-1f9d55?style=for-the-badge&labelColor=1f2430" alt="多平台 GUI" />
  <img src="https://img.shields.io/badge/license-Apache--2.0-d69e2e?style=for-the-badge&labelColor=1f2430" alt="Apache 2.0 许可证" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">CangHui / CUI</span><br/>
<span style="font-weight:100;font-size:24px">仓颉多平台声明式 GUI 框架</span>
<p align="center">
  <strong>让仓颉意图抵达原生像素的 GUI 运行时</strong><br/>
  <sub>声明式语义 · 确定性探针 · 自渲染表面 · 原生宿主契约</sub>
</p>
</div>

[English](README.md) | **中文**

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## 这是什么

CangHui 是用[仓颉编程语言](https://cangjie-lang.cn/)实现的自渲染、声明式 GUI 框架。项目从
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI) 演进而来，
持续保留其上游归属与 MIT 许可告知。CangHui 及其原创贡献以 Apache 2.0
许可证发布，上游 MIT 条款完整保留在
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。声明式核心 `cui`、安全的
SDL3 封装 `sdl`、集成工具链 `cuic`、组件包契约、响应式布局原语与原生宿主契约都维护在本仓库。

框架在源码层保持平台中立：公共组件只依赖类型化的宿主能力（`HostCapability`）与
视口事实（`ViewportSpec`），各平台适配层负责生命周期、原生 surface、IME、无障碍、
打包与签名。平台宿主可以独立实现，不需要修改公共组件或应用状态。

> CangHui 不是截图层，也不是一袋组件。它是面向语言的轻量运行时：
> 应用意图以仓颉组合进入，经过布局、状态、动效、Symbol 与宿主能力，
> 最终变成可渲染、可检查、可回放的帧。

## CangHui 分层

```text
应用代码
        |
        v
cuic 工程生命周期  ----  kMode / probe / Draw IR / prnt
        |
        v
CUI 声明式核心  ----  状态、身份、布局、控件、覆盖层
        |               主题、动效、字体、Symbol provider
        v
宿主能力契约  ----  窗口、输入、IME、文件、剪贴板、时间
        |
        v
原生表面适配器  ----  SDL3 桌面 | UIKit/Metal 切片 | 移动端启动边界
        |
        v
平台运行时与 GPU 后端
```

这套分层是刻意设计的：组件可以描述行为而不导入平台宿主；宿主可以
提供渲染表面而不理解业务状态；`cuic` 则可以在不打开窗口的情况下调用
同一套公开函数。

## 平台状态

以下平台声明刻意保守：桌面布局预览不代表移动端运行时，native-surface 探针也不等于
产品级场景渲染或应用验收。

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS 桌面 | 可用 | 本机通过构建、框架/SDL/CLI 全量测试套件、交互式 Gallery 与确定性截图。 |
| iOS | native-surface 适配器已证明 | 模拟器与真机证明覆盖静态包 bootstrap、UIKit `CAMetalLayer`、生命周期、安全区、触摸、`CADisplayLink`、detach/reattach generation 回放与 Metal clear pass。完整 CUI 场景渲染、IME、无障碍和产品应用验收仍未完成。 |
| HarmonyOS / HarmonyPC | 本仓库未提供应用宿主 | 公共契约覆盖原生 surface 与宿主能力，但本仓库不包含 ArkTS/HAP 应用宿主，也不声明独立的设备运行验收。 |
| Windows / Linux | 仅有代码路径 | `cuic` 提供 bootstrap、doctor 与构建代码路径；本仓库不声称这两个平台的主机级运行时证明。 |
| Android | 仅 native-surface bootstrap | 最小 Activity 已经管理 generation-safe 的 `SurfaceView` 到 JNI 再到 `ANativeWindow` 生命周期，并通过 `arm64-v8a` 与 `x86_64` 构建。仓颉 Android SDK、渲染器桥、输入/IME、APK 打包和真机运行证明仍未完成。 |

## 能力地图

| 层 | 公开代码中已有 | 边界 |
| --- | --- | --- |
| CUI 核心 | 声明式组合、身份、状态、布局、控件、覆盖层与文本编辑 | 平台无关的源代码 API |
| 渲染 | 基于 SDL3 的桌面渲染器、几何、文本、Symbol、阴影与渐变 | 这是依赖上游底座的实现，不代表所有 GPU 后端都已完成 |
| 交互 | 指针捕获、hover/click 取消、焦点、键盘路由、缓动滚动与动效力度 | 未证明的平台仍由原生宿主负责 IME 与无障碍 |
| 检查 | `kMode`、`cuic probe`、组件/函数/事件报告、Draw IR 与确定性 `prnt` | 无头报告证明语义与几何，不等于完整设备 UI 验收 |
| 工具链 | `cuic init`、应用清单、依赖缓存/锁、doctor 与平台准备 | 平台签名、商店发布和未证明的原生运行时仍由平台门禁负责 |
| 移动桥接 | iOS 原生表面生命周期切片、Android 表面启动边界、阶段化 package receipt、无秘密信息的外部签名器准备/receipt 绑定与 kMode 回放 | receipt 绑定不处理凭据、不验证签名字节，也不声称安装包已签名或可安装；完整产品渲染、签名、真机回放与消费者验收仍按平台分别推进 |

## 快速开始

通过集成工具链 `cuic` 可以最快地创建、构建并运行 CangHui 应用。安装 `cuic` 只会稀疏获取并编译
`tools/cuic`，不会在工程旁保留一份完整框架仓库。

```bash
curl -fsSL https://raw.githubusercontent.com/Celading/CangHui/main/scripts/install-cuic.sh | bash
cuic version
```

创建并运行空白工程：

```bash
cuic init HelloCangHui --name hello_canghui --platform macos
cd HelloCangHui
cuic dependency update
cuic doctor macos
cuic build macos
cuic run macos
```

生成工程通过公开 CangHui Git 依赖按 commit 固定版本。`cuic dependency update` 是唯一显式修改
lock/缓存的步骤；构建类命令要求 `cjpm.lock` 与 manifest 一致，且不会隐式更新。框架经由 CJPM
缓存解析，不会被复制进每个应用。

`src/main.cj` 中的最小窗口：

```cangjie
import cui.*

main() {
    let message = State<String>("你好，CUI")
    let app = DesktopApp(WindowSpec("CUI 示例", 640, 420))

    app.run {
        VStack {
            Panel {
                Label(message.value)
            }.flexible(false)
            Button("更新文本", {=> message.value = "状态已更新"})
                .role(ButtonRole.Primary)
                .width(160.vp)
        }.spacing(12.vp).padding(20.vp)
    }
}
```

完整的缓存、锁定与本地覆盖规则见[轻量消费工作流](docs/consumer-workflow.zh-CN.md)。

对应用开发者而言，理想形态很小：依赖 `cui`、安装 `cuic`，再由工具生成
工程骨架。完整框架 checkout 适合框架开发，但不应成为普通应用的目录结构。

## 核心能力

- 基于 SDL3 的自渲染 GUI 引擎，使用 GPU 几何图元与超采样渲染圆角、描边、图标、阴影与渐变。
- 基于仓颉尾随 lambda、`extend`、`prop` 的声明式 UI 编码范式。
- 布局容器：`VStack`、`HStack`、`ZStack`、`Grid`、`Panel`、`FlowRow`、`ScrollView`、
  `SplitView`、`Accordion`、动画折叠容器 `Reveal`，以及视口聚焦的懒加载容器
  `LazyColumn`、`LazyRow`、`LazyList`、`LazyGrid`。
- 控件：按钮、文本框、开关、复选框、单选、选择器、步进器、滑块、进度条、环形进度、评分、
  徽标、过滤标签、步骤条、分页、面包屑、列表、数据表格、树视图、日期/时间选择器、
  拖动重排列表、分段控件、标签页、下拉与组合框。
- 浮层：下拉、右键菜单、应用菜单栏、选择器、提示、通知与模态对话框；浮层按栈管理、可嵌套。
- 有顺序语义的链式修饰器：尺寸、约束、内边距、表面、圆角、边框、阴影、渐变、弹性、
  可见性与可用性，支持 `.px`、`.vp`、`.fp` 尺寸单位。
- 状态管理：读写分离的 `Observable`/`Bindable`、可写 `State<T>`、带缓存的派生只读
  `DerivedState`（`derive`/`map`）、双向投影 `Binding`（`project`）。
- 线程安全的 `UiOwnerQueue` 与 `DesktopApp.postToUi`：worker 准备不可变结果，
  单一 UI owner 在下一次声明式构建前按 ticket 顺序提交；支持 epoch/native-surface-generation
  门、取消、关闭回执与有界排水。`State` 本身只允许 UI owner 修改。
- 用 `Keyed`、`rememberState`、`ForEach` 稳定控件身份；焦点、悬停、光标与点击身份
  按每帧确定的构建顺序派生。
- 动画原语：`Spring`、时长/缓动 `Animator`、重复时间线 `Pulse`，渲染循环充当动画时钟，
  脏帧下自动续帧；`AnimationSpec` 可随主题 `MotionLevel` 缩放。
- 桌面默认跟随渲染器 VSync，不再额外叠加固定等待；也可显式选择
  `FramePacing.Fixed(fps)` 或 `FramePacing.Unbounded`。kMode 未显式配置时仅对实际渲染帧
  采用不封顶节奏。
- 可滚动组件默认采用类似 Web 的保留式滚轮缓动；共享 `ScrollOptions` 可统一配置即时/平滑模式、
  逻辑像素步长、播放时长与曲线，覆盖视口、懒列表、表格、树、文本区、下拉与组合框。
- 设计令牌：`Spacing`、`Radii`、`Motion`、颜色 `Theme`、`FontSizes` 与 `Shadow.elevation`。
- 指针起点明暗主题 reveal 与按真实圆角裁切的语义色 InkWell 反馈，统一 release-inside
  激活与移出永久取消。
- 文本编辑：UTF-8 光标/选区、双击选词、三击选行、剪贴板最佳努力、撤销/重做分组与 IME
  锚点上报。
- 平台能力 SPI：文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间与系统信息。
- provider-neutral `Symbol`：内建图标保持兼容，Material、Ant Design、Arco 作为独立可选包；
  `cuic symbol generate` 生成声明的注册子集并拒绝重复/冲突。
- 随包 HarmonyOS Sans：组件、Theme、应用、随包与系统五级解析，并附带许可证与来源说明。

## 集成工具链（`cuic`）

`tools/cuic` 是框架自带的 CLI：

- `cuic init` / `build` / `test` / `run`，按目标平台准备依赖
- `cuic doctor`：分组报告 Cangjie、仓库、SDL、macOS、Windows、Linux、iOS、HarmonyOS、
  Android、字体、Symbol、kMode 与 probe 就绪度
- `cuic kmode`：不创建窗口的调试/受监管无头调用
- `cuic probe`：无窗口输出组件/函数/事件/动画与 Draw IR 报告
- `cuic symbol`：声明式 provider 子集与生成
- `cuic font`：字体准备与注册
- `cuic prnt`：确定性稳态帧截图
- `cuic check` / `dev` / `snapshot-ui`：由 `canghui.toml` 声明的生命周期别名
  （限定在既有 cuic 动作内）

doctor 状态模型与 JSON 契约见
[`docs/doctor.zh-CN.md`](docs/doctor.zh-CN.md)。

## 组件、Gallery 与包

公共组件包是普通 CJPM 源码依赖：它们暴露类型化 `ComponentPackageDescriptor`，
接收包含 `HostProfile` 与 `ViewportSpec` 的 `ComponentContext`，可按 `Compact`、
`Medium`、`Expanded` 分级布局，而不 import 任何平台宿主。

- 参考组件包：`packages/gallery-components`
- 桌面 Gallery：`examples/component-gallery`
- 响应式预览矩阵：`src/testkit/preview_matrix.cj`
- 组件包 schema：`contracts/canghui-component-package-v0.schema.json`
- Symbol provider：`packages/symbol-material`、`packages/symbol-ant`、`packages/symbol-arco`

## 公开契约，而不是平台伪装

CangHui 使用分级词汇表达能力边界：

- **已实现**：源代码、测试与指定宿主证据一致。
- **实验性**：适合有边界的开发工作，但更广泛的运行时或消费者证据仍未闭合。
- **契约**：CangHui 定义了接口与不变量，平台实现仍由宿主项目负责。
- **计划中**：已经记录方向，但尚未作为功能交付。

这不是文案细节，而是产品契约。它避免桌面截图被误读成 iPad 运行时，
也避免原生表面启动切片被误读成完整应用宿主。

## 技术谱系与生态

下面的地图按层展示 CangHui 使用什么、暴露什么、研究什么；它不会把
上游项目的能力折算成 CangHui 自己已经实现的能力。

| 角色 | 项目或表面 | 与 CangHui 的关系 |
| --- | --- | --- |
| 语言 | [仓颉](https://cangjie-lang.cn/) | 主实现语言与应用语言 |
| 声明式运行时 | CUI（`cui`） | 框架自有的组合、状态、布局与组件表面 |
| 桌面底座 | [SDL3](https://www.libsdl.org/) / SDL3_ttf | 由公开 `sdl` 包封装的上游运行时依赖 |
| 原生表面 | UIKit、Metal、Android `SurfaceView` 与 `ANativeWindow` | 适配目标与有边界的启动切片；平台证据以能力矩阵为准 |
| 设计语言 | HarmonyOS Sans、Theme、Motion 与 Symbol 契约 | 自带兜底资源与 provider-neutral 公共 API |
| 工具链 | `cuic`、kMode、probe、Draw IR、doctor 与 `prnt` | 框架自有的工程、检查与验证入口 |
| 组件参考 | ArkUI 方向的组件矩阵与成熟 GUI 约定 | 兼容性与设计参考，不是捆绑的平台实现 |
| 图形参考 | SDL、GPU 几何与原生表面工程资料 | 渲染边界的输入，不代表拥有所有图形后端 |

可以把 CangHui 理解为一座**语义桥**：它负责让仓颉语义跨越宿主，
而宿主仍须对生命周期、表面、输入、文字系统、无障碍与打包事实负责。

### SDL 的生产谱系

SDL3 是这条运行时谱系的当前代际；在它之前，SDL 已经进入游戏、模拟器、
媒体软件与 Valve 产品目录。下面的图片墙用于展示更广泛的 SDL 生产生态。
它们**不是 CangHui 应用**，每个产品实际使用的 SDL 代际与图形后端也可能不同。

<table>
  <tr>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/265630/">
        <img src="https://www.libsdl.org/steam_images/265630.jpg" width="100%" alt="Fistful of Frags" /><br/>
        <sub>Fistful of Frags · SDL 官方展示</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/355180/">
        <img src="https://www.libsdl.org/steam_images/355180.jpg" width="100%" alt="Codename CURE" /><br/>
        <sub>Codename CURE · SDL 官方展示</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/570/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/570/header.jpg" width="100%" alt="Dota 2" /><br/>
        <sub>Dota 2 · Valve 产品目录</sub>
      </a>
    </td>
  </tr>
  <tr>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/730/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/730/header.jpg" width="100%" alt="Counter-Strike 2" /><br/>
        <sub>Counter-Strike 2 · Valve 产品目录</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/620/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/620/header.jpg" width="100%" alt="Portal 2" /><br/>
        <sub>Portal 2 · Valve 产品目录</sub>
      </a>
    </td>
    <td width="33%" align="center">
      <a href="https://store.steampowered.com/app/550/">
        <img src="https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/550/header.jpg" width="100%" alt="Left 4 Dead 2" /><br/>
        <sub>Left 4 Dead 2 · Valve 产品目录</sub>
      </a>
    </td>
  </tr>
</table>

SDL 官网将 Valve 的获奖产品目录和大量 Humble Bundle 游戏列为生产用户。
产品名称与美术资产归各自权利人所有；上述远程图片链接回来源页面，并未随
CangHui 仓库分发。它们展示的是上游底座的覆盖范围，不构成兼容性、背书或
CangHui 运行时能力声明。

## 下一段路

下一阶段的重点不是继续堆更长的组件目录，而是让同一个应用可以被三种
分辨率检查：

1. **语义层**：通过 kMode 调用公开函数或事件。
2. **几何层**：无窗口检查布局边界、命中区域与 Draw IR。
3. **视觉层**：渲染稳定帧，并在问题确实属于像素时截图。

这样自动化工具、CI 与开发者就能共享一套 UI 调试语言，而不必把每个问题都压成
截图。截图仍然用于视觉验收，只是不再承担整个测试体系。

## 文档

- [示例应用](examples/)
- [入门指南](docs/guide/index.md)
- [API 文档](docs/api/index.md)
- [架构说明](docs/architecture.md)
- [轻量消费工作流](docs/consumer-workflow.zh-CN.md)
- [多平台 Doctor](docs/doctor.zh-CN.md)
- [Symbol 与可选图标 Provider](docs/symbols.zh-CN.md)
- [字体](docs/fonts.zh-CN.md)
- [Probe 与 kMode](docs/probe.zh-CN.md)
- [SDL3 Apple 宿主说明](docs/sdl3-apple-host.zh-CN.md)
- [现代 GUI 核心范式洞察辨析](docs/modern-GUI-insights-and-analysis.md)

## 许可证

本项目以 [Apache 2.0 许可证](LICENSE) 发布。保留的上游与第三方归属见
[NOTICE](NOTICE) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。SDL3 与
SDL3_ttf 运行库使用 Zlib 许可证，请参见对应上游项目。上游源码归属保留为
[`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI)。

> [!IMPORTANT]
> 发布基于 CUI 的桌面软件时，请确保 SDL 与 SDL_ttf 动态库位于仓颉可执行文件目录，
> 或位于目标平台的动态库搜索路径中。
