# CangHuiKit：可组合的设计套件

`canghui_kit` 是可选源码包。`chui` 管理状态、布局、输入与动画；Kit 提供常用组件组合、
密度和页面结构。它不替换 Theme，也不捆绑 Liquid Glass 或产品业务逻辑。

本地检验可按工作台使用路径依赖；应用发布时请固定包含 Kit 的框架提交，不要把尚未
发布的新包当作当前远程主线已经提供的能力。

```toml
[dependencies]
chui = { path = "../CangHui" }
canghui_kit = { path = "../CangHui/packages/kit" }
```

```cangjie
import chui.*
import canghui_kit.*

let design = KitDesign(theme: Theme.dark(), density: KitDensity.Comfortable)
kitChoiceCard("local", "本地工作区", "离线可用，文件留在设备上", selected.value,
    {=> selected.value = !selected.value}, design: design)
kitSettingsToggle("motion", "减少动态效果", "属性变化立即生效", reducedMotion, design: design)
```

应用宿主与 `KitDesign` 使用同一 Theme。状态在应用模型里保留，Kit 不会创建另一个全局
状态管理器；设置行只修改传入的绑定，应用负责把该设置用于自己的主题或业务。

## 第一组组件

| 组件 | 组合原则 |
| --- | --- |
| `kitChoiceCard` | 图标和标题靠在一起，说明可换行，尾端留给选择标记；一个动作/焦点拥有者，选中色自动补间 |
| `kitSettingsToggle` | 文本是装饰，尾端 Switch 独立操作；不在开关外再嵌一个按钮 |
| `kitStep` | 无多余边框的编号、标题、说明；不暗中绑定点击动作 |
| `kitAction` | 左右 padding 和自然宽度明确；Compact / Comfortable / Touch 最小高度为 32 / 38 / 44 |
| `kitIntro` | 同一组 visual / actions / steps 插槽可换三种页面结构 |

Kit 不会把长文字压进固定高度。标题、说明可换行；超出屏幕的页面放进 ScrollView，
不要靠缩小字体或提高一整行按钮高度掩盖布局问题。

## 三种结构，不是三套颜色

- `Editorial`：宽屏文案与动作在一侧，视觉对象在另一侧；窄屏重新纵向组织。
- `Focused`：视觉对象、居中标题与行动入口形成单列焦点。
- `Guided`：宽屏把说明和步骤列放左侧，视觉与动作放右侧；窄屏把步骤放回行动前。

`kitIntroLayout(profile, availableWidth)` 可无图查询当前结构。`ComponentContext.viewport`
应由宿主在窗口/容器尺寸变化时更新，使用**该组件区域的逻辑尺寸**，不是物理像素或
整个显示器尺寸。此版本通过宿主提供的尺寸选择结构，不宣称任意嵌套容器的自动尺寸读取。
结构切换本身立即生效；属性动画与已有 keyed 布局过渡按各自契约使用。

visual 插槽由应用提供图片、矢量或 Scene3D 内容。Kit 不附带第三方原型图，也不把
某套平台材料仿真宣传为原生实现。材料需求可另行组合已有的
[Liquid Glass 包](liquid-glass-style.md)。

参见[源码包](../../packages/kit/README.md)、[可运行工作台](../../examples/kit-workbench/README.md)
和[属性动画](../guide/how-to/animate-properties.md)。目前验证面是通用源码测试和 macOS SDL；
Windows、HarmonyOS 等原生设备效果必须由对应宿主实际验证。
