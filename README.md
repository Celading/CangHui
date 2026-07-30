# CangHui / CUI：仓颉多平台 GUI 母体框架

用[仓颉编程语言](https://cangjie-lang.cn/)实现的跨平台、自渲染、声明式 GUI 母体框架，提供声明式界面构建、状态管理、常用组件、文本渲染、矢量绘制以及系统能力集成等。项目从 [`SunriseSummer/CangjieGUI`](https://github.com/SunriseSummer/CangjieGUI) 演进并持续保留其许可证与上游归属；底层依赖[仓颉 SDL 图形库](https://github.com/SunriseSummer/CangjieSDL)。

<img src="./examples/.images/cangcui.png" />
<img src="./images/gallery.jpg" />

## 文档与示例

- [示例应用](examples/)
- [入门指南](docs/guide/index.md)
- [API 文档](docs/api/index.md)
- [Symbol 与可选图标 Provider](docs/symbols.md)

## 开发环境

- Cangjie SDK 1.0.5
- Windows/Mac/Linux
- 当前母体分支保留仓库内 `sdl` 模块，并持续吸收 [`CangjieSDL`](https://github.com/SunriseSummer/CangjieSDL) 上游能力；根据目标平台规格配置 SDL 和 SDL_ttf 动态库

macOS 首次构建先准备 Homebrew SDL 动态库：

```bash
brew install sdl3 sdl3_ttf
./scripts/bootstrap-macos.sh
cjpm build
```

> [!IMPORTANT]
>
> 发布和部署基于 CUI 的桌面软件时，请确保 SDL 和 SDL_ttf 动态库位于仓颉可执行文件目录，或在目标平台的动态库搜索路径中，即可以作为私有资产打包或在目标平台作为公共运行时安装。

## 快速开始

新建仓颉项目，在 `cjpm.toml` 配置 CUI 依赖：

```toml
[dependencies]
cui = { path = "<path/to/CangHui>" }
```

在 `src/main.cj` 中编写代码创建一个简单窗口：

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

执行 `cjpm run` 即可运行查看效果。

## 核心能力

- 基于 SDL3 实现自渲染 GUI 引擎。
- 基于仓颉尾随 lambda、extend、prop 等特性构建声明式 UI 编码范式。
- 提供 `VStack`、`HStack`、`ZStack`、`Grid`、`Panel`、`FlowRow`、`ScrollView`、`SplitView`、`Accordion`、动画折叠
  容器 `Reveal` 等布局容器，以及数据驱动、只渲染视口附近的懒加载容器 `LazyColumn`、`LazyRow`、`LazyList` 与 `LazyGrid`。
- 提供按钮、文本框、开关、复选框、单选框、选择器、步进器、滑块、进度条、环形进度、评分、状态徽标、过滤标签、
  步骤条、分页导航、面包屑、列表、数据表格、树视图、日期选择器、时间选择器、拖动重排列表、分段控件、标签页、下拉和组合框等控件。
- 提供下拉/右键菜单、应用菜单栏、选择器、提示、通知与模态对话框等浮层，浮层按栈管理、可嵌套，对话框内可继续打开下拉、组合框与右键菜单。
- 使用有顺序语义的链式修饰器配置尺寸、约束、内边距、表面、圆角、边框、阴影、渐变背景、弹性、可见性和可用性，支持 `.px`，`.vp`，`.fp` 尺寸单位表达。
- 以 `Observable`/`Bindable` 实现状态管理：可写 `State<T>`，带缓存的派生只读 `DerivedState`
  （`derive`/`map`），双向投影 `Binding`（`project`），控件按读写需要接受对应抽象。
- 以 `Keyed`、`rememberState`、`ForEach` 明确复杂嵌套树与列表中的局部状态身份，控件交互身份按构建顺序自动唯一。
- 支持主轴/交叉轴排列、权重布局、内容自适应、流式换行、裁剪滚动和可复用组件组合。
- 使用 GPU 几何图元和超采样渲染圆角、描边、图标、阴影及抗锯齿图形。
- 提供动画原语：物理弹簧 `Spring`、时长驱动可选缓动曲线与延迟的补间 `Animator`，以及永不静止的重复时间线 `Pulse`，
  由渲染循环充当动画时钟，脏帧下自动续帧；`AnimationSpec` 可选择随主题动效力度自动缩放，或锁定精确播放时间与曲线。
- 提供设计令牌尺度：间距 `Spacing`、圆角 `Radii`、动效 `Motion`，以及主题相邻的 `MotionLevel.Basic / Standard / Full`；它们与颜色 `Theme`、字号 `FontSizes`、
  高度 `Shadow.elevation` 一起构成一致的设计系统。
- 提供文件对话框、消息框、剪贴板、光标、显示器、文件系统、时间、系统信息等平台能力接口。
- 提供 provider-neutral `Symbol`，内建图标保持 `Icon`/`IconButton` 兼容；Material、Ant Design 与 Arco
  作为独立可选包接入，`cuic symbol generate` 生成应用声明的注册子集。
- 已实现图元缓存、惰性渲染、脏帧检测/按需刷新等性能优化机制。

扩展阅读：[现代 GUI 核心范式洞察辨析：函数式/对象式，立即模式/保留模式](docs/modern-GUI-insights-and-analysis.md)

## 多平台组件母体

本分支在上游 `0.9.2` 桌面组件集之上保留平台无关的母体合同：

- `HostProfile` 与 `HostCapability` 描述宿主平台和真实可用能力；
- `ComponentPackageDescriptor`、`ComponentContext` 与 `ViewportSpec` 为组件包注入宿主事实和逻辑视口；
- `Compact / Medium / Expanded` 响应式分级与 Component Gallery 用于公共布局回归；
- `cui.host` 定义生命周期、安全区、触摸、文件选择、存储、主题、通知、后台任务和 native-surface 边界；
- Debug 或显式监管运行可通过 kMode 在不创建窗口、不遍历布局时调用已注册函数。

Android、HarmonyOS 与 iOS 预览只证明公共布局。平台窗口、渲染器、生命周期、IME、无障碍、签名和打包仍由宿主适配层实现，不构成对应平台运行或发布声明。

## 集成工具链

`tools/cuic` 是 CangHui 自带的仓颉工具链，统一负责项目初始化、构建、测试、kMode、无图探针、平台诊断、字体、Symbol 资源与渲染截图。命令名保持为 `cuic`：

```bash
./tools/cuic/bin/cuic version
./tools/cuic/bin/cuic doctor
./tools/cuic/bin/cuic examples
```

平台诊断的状态、退出码、隐私边界与 JSON 契约见 [`docs/doctor.md`](docs/doctor.md)。
字体默认使用随包 HarmonyOS Sans，并支持组件、Theme 与应用级字体覆盖；解析与打包规则见
[`docs/fonts.md`](docs/fonts.md)。
Symbol provider、缺失/variant 回退与按需生成契约见 [`docs/symbols.md`](docs/symbols.md)。

主题切换保留指针起点的圆形 reveal 与控件 InkWell；InkWell 从当前主题语义色派生，按控件圆角真实裁切，
并允许点击热区与视觉反馈区分离。Checkbox、Switch、RadioButton 只在 indicator/track 内表达反馈，
Slider 的任意轨道点击也会产生局部反馈。它们已接入按需渲染循环，通过连续帧请求在脏帧跳过模式下完成动画。
Component Gallery 按 Actions、Selection、Navigation、Feedback、Symbols 五类展示具名组件与 `cui.*` API，
并可直接切换 Basic、Standard、Full 动效力度。Button 与 IconButton 共用 hover、press、InkWell、
移出取消和 release-inside 激活语义；Chip、Breadcrumb、Pagination、Rating、Picker 与 Stepper 也遵守
同一提交门。Stepper/Picker 使用方向文字切换，Rating 区分已选与 hover 预览，Breadcrumb 支持可回退和
重新前进的 history 高亮，Pagination 使用稳定槽位和滑动选中底板，Dropdown 与 Accordion 使用保留动画；
Accordion 在滚动容器内展开收起时保持当前视觉锚点。StepIndicator 的 Gallery 范例提供独立前后步骤按钮。

## 许可证

本项目以 [MIT 许可证](LICENSE) 发布。
