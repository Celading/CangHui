# 视觉动效与可选 Kit

`canghui_kit` 增加五组可组合的视觉配方，独立于基础控件和输入系统。
[Motion Studio](../../examples/motion-lab/README.md) 是使用公开 API 的可运行消费工程。

| 配方 | 视觉与行为 |
| --- | --- |
| `kitBounce(key, replay, palette)` | 下落、减幅回弹、落地停稳；递增 replay 重播。 |
| `kitTerminal(key, replay, palette)` | 数字终端网格、逐行揭示、有限扫描。 |
| `kitRollingNumber(key, value, palette, fontSize: ...)` | 各位数字独立滚动，负号保持静止，快速更新接续最新目标。 |
| `kitFocusLight(key, palette, focusKey: ...)` | 局部归一化指针跟随；可关联已有键盘焦点，离开或窗口失焦后收光。 |
| `kitChoreography(key, shown, palette)` | 四条共享轴入场，错峰、可反向中断。 |
| `kitArchive(key, replay, palette)` | 细线、暖纸、信号金、观察仪表与文档揭示。 |
| `kitCascade(key, index, expanded, content)` | 给已有控件增加错峰位移内边距，不复制其输入或焦点。 |

`KitMotionFamily` 包含 Bounce、Digital、FocusLight、Choreography、Archive；
`kitMotionPalette(family, dark: false)` 提供十组亮暗配色及 background/surface/ink/signal/muted。
`kitMotionStudy(key, family, palette, replay: ..., value: ..., shown: ...)` 提供统一组合入口。

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_kit = { path = "../CangHui/packages/kit" }
```

```cangjie
import chui.*
import canghui_kit.*

// 放在应用构建块内，业务值由应用状态持有。
let palette = kitMotionPalette(KitMotionFamily.Digital, dark: true)
kitRollingNumber("orders.total", total, palette).height(80.px)
```

数字直接取 Int64 的精确字符串，覆盖负数、位数变化及 Min/Max；不把整个数字转换为浮点数。
绘制层按真实字体测量等宽列，过长数字缩小以适配可用宽度。
无障碍语义只提供一条只读的完整目标值，滚动列不成为额外控件。
字号、字体族与字体样式继承当前 TypographyEnvironment。

配方中的动画通过公开 `MotionValue` 驱动；减少动效时立即呈现终态，扫描不常驻循环。
光斑只观察输入并返回 false，关联 focusKey 时仍由原控件持有键盘焦点。
这些是二维绘制研究，包括近似玻璃卡片的柔光，并不提供系统光学折射或真正的背景模糊。

Archive 参考 [RhineLabUI](https://github.com/LBEILC/RhineLabUI) 的细线、留白与层次节奏，
参考版本 `12cc5e4013acb9408f753ff71de6b8492299b7c8`，MIT。
此处为原创仓颉二维实现，未复制其代码、标识、角色、模型、字体或音频。

当前源代码验证包含框架回归、公开包消费和同机 macOS SDL 窗口。
其他原生宿主、可变字体轴、双向文字和系统辅助功能需分别验收。
源码 Kit 需选用包含 MotionValue 与 Canvas 上下文入口的当前框架；旧安装版须先升级源码。
