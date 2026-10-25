# Liquid Glass 样式包

`packages/style-liquid-glass` 是 CangHui Multiplatform 的可选样式包，公开包名为
`canghui_style_liquid_glass`。它复用 `chui` 的主题与材质扩展点，不改变核心控件 API。

## 引用

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_style_liquid_glass = { path = "../CangHui/packages/style-liquid-glass" }
```

```cangjie
import chui.*
import canghui_style_liquid_glass.*

let preferences = LiquidGlassPreferences(
    reduceTransparency: false,
    increaseContrast: false,
    reduceMotion: false
)
let app = DesktopApp(
    WindowSpec("Glass", 900, 700),
    theme: LiquidGlass.light(preferences: preferences)
)
```

单个悬浮功能层使用 `Surface` 与公开材质：

```cangjie
Surface(
    shape: Shape.rounded(28.0),
    material: LiquidGlass.material(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Regular,
        tint: Some(Color.rgb(0, 122, 255)),
        interactive: false,
        radius: 28.0,
        preferences: preferences
    )),
    painter: Some(LiquidGlass.surfacePainter(spec: LiquidGlassSpec(
        variant: LiquidGlassVariant.Clear,
        radius: 28.0,
        optics: LiquidGlassOptics(clarity: 0.94, haze: 0.18)
    ))),
    clip: ClipPolicy.Shape
) {
    HStack { /* navigation or controls */ }.padding(16.vp, 12.vp)
}
```

`Regular` 适合工具条、侧栏和浮动导航；`Clear` 是高透明镜片，适合视觉内容丰富且仍能保证
文字对比的背景；`Vapor` 用更高 haze 模拟气态、雾化的内部层次。

三个变体在**光学参数上**本身就不同，靠的是 `LiquidGlassOptics.profile(variant)`，不是只改 alpha：

| 变体 | haze | displacement | lensRadius | edgeRings | 读感 |
|---|---|---|---|---|---|
| `Regular` | 0.34 | 0.72 | 0.46 | 3 | 中性玻璃，边缘有轮廓层次 |
| `Clear` | 0.10 | 0.94 | 0.58 | 2 | 最强折射，接近纯镜片 |
| `Vapor` | 0.72 | 0.44 | 0.74 | 4 | 雾化，弱透镜，无硬高光带 |

`LiquidGlassSpec` 的 `optics` 默认取当前变体的 profile；显式传 `optics: Some(...)` 才会覆盖。
`LiquidGlassOptics` 可调整 `clarity`、`haze`、`edgeEnergy`、`chromaticEdge`、`deformation`，
以及光学修复新增的 `displacement`、`lensRadius`、`sampleRadius`、`edgeRings`、`tintStrength`。
交互按钮可直接使用 `LiquidGlass.buttonStyle()`，整套内置控件则由 `LiquidGlass.light()` 或
`LiquidGlass.dark()` 的 `ComponentTheme` 统一接管。内置 `SegmentedControl` 和 `TabView` 会继续拥有
输入、焦点与布局，只把选中镜片交给样式包绘制；镜片的前后缘使用不同弹簧，在切换时产生可见的
伸展、收拢形变。`reduceMotion` 会将形变量降为零。

## 无障碍与层级

- `reduceTransparency` 把半透明表面替换为不透明表面；
- `increaseContrast` 提高边缘对比与描边宽度；
- `reduceMotion` 传入主题，收敛自动动画；
- 玻璃主要属于导航和重要悬浮控件层，不要给内容区每张卡重复套玻璃；
- 主动作可以 tint，普通动作保留中性玻璃，危险动作仍使用语义危险色。

## 材质分层

材质由五个显式图层组成，一层半透明填充不再代表整个材质：

| 图层 | 职责 |
|---|---|
| `Backdrop` | 有界背景采样请求，携带局部透镜参数 |
| `Body` | 主体填充、渐变、薄雾与染色 |
| `Edge` | 多层同心态描边，形成轮廓梯度而非单描边 |
| `Lens` | 局部透镜：光学中心 + 半径 + 内反射环 + 过渡态色散 |
| `State` | 位置跟随高光、轮廓外光晕 |

局部透镜通过 `BackdropLensOptics` 表达，四元组为光学中心（相对 bounds 归一化）、
半径（相对短边比例）、位移强度与采样半径，另有 `invertInsideLens` 表示镜内倒置。
请求默认不激活（`displacementStrength = 0`），因此既有均匀折射行为不变。

**色散是过渡态特征，不是稳态装饰。** `BackdropEffectRequest.requestedChromaticEdge()` 只在
`motionEnergy > 0` 且透镜激活时返回非零；静止时为零。这与参考素材的最终稳定态一致：
稳态不应残留红蓝边。

参考依据来自工单 `HN-ISSUE-20261025-007` 的三段窗口（`00:51-00:58`、`00:59-01:03`、
`01:09-01:13`）逐帧合同，见
`_helper/docs/CangHui/evidence/LIQUID-GLASS-OPTICS-20261025/VISUAL_CONTRACT.md`。

## 当前渲染边界

第一版已经提供真实的前景几何形变，以及由渐变、薄雾、内外高光、色散边缘和阴影组成的 SDR
高透感模拟。当前 `sdl-readback` adapter 还能在严格像素/数量预算内采样当前帧已绘背景，执行
第一版多采样柔化与镜片取样；`LiquidGlass.paintWithReceipt`、`Renderer.lastEffectReceipt()` 和
Draw IR 会说明实际应用或降级原因。缺少 adapter、旧帧、预算超限、provider 失败或
`reduceTransparency` 时仍使用同一套确定性 SDR/不透明 fallback，不改变 Surface 内容与交互。

光学修复后新增两条降级路径，都会如实出现在 receipt 里：

- `lens-unsupported`：请求带激活的局部透镜，但 provider 没有 `Refraction` 能力。此时退回平面
  fallback，**不会**假装做了局部位移。
- 采样预算：激活透镜的 `sampleRadius` 会计入采样边距，因此大透镜不会在预算外偷偷读背景。

`sample-budget-exceeded`、`effect-budget-exceeded`、`stale-frame`、`outside-viewport` 与
`provider-failed` 的语义保持不变。

首个 provider 的同步 readback 适合少量导航与悬浮控制，不适合无上限列表或全屏堆叠；它尚不支持
多个玻璃形状的 union，并明确返回 `shape-union-unsupported`。详见
[Renderer effects](renderer-effects.md)。macOS SDL 像素证明不等同于 Apple 平台原生材质，也不构成
iOS、Metal、Vulkan、D3D、GLES 或 WebGPU backend 已完成的证明。

设计依据来自 Apple 公开的
[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、
[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
与 [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)。包内不含 Apple 资产。
