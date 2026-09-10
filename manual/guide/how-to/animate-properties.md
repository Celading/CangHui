# 改属性，让界面跟着动

展开卡片、调整内边距或切换选中颜色时，不必手写 Animator。在普通修饰器链末尾添加
`animateProperties`，下一次构建改变属性值即可。

```cangjie
let expanded = State<Bool>(false) // 放在页面模型中，不要每帧重新创建

VStack {
    Button("展开 / 收起", {=> expanded.value = !expanded.value})
    Label("内容随布局一起变化").wrap()
        .padding(if (expanded.value) {24.vp} else {12.vp})
        .width(if (expanded.value) {320.vp} else {180.vp})
        .height(if (expanded.value) {120.vp} else {80.vp})
        .background(if (expanded.value) {Color.rgb(218, 235, 255)} else {Color.rgb(240, 243, 248)}, 16.vp)
        .animateProperties("details")
}.hug()
```

## 时长、改向和停止

默认时长遵循主题 `MotionLevel`。需要固定曲线时使用第二个重载：

```cangjie
.animateProperties("details", AnimationSpec(duration: UInt64(320), easing: Easing.EaseInOutQuad))
```

- 第一次出现直接采用当前值，不从零尺寸“长出来”。
- 中途改向从当前显示值继续；静止很久后的第一帧不会跳过新动画。
- 同一帧重复测量、布局、绘制、探针读取不会重复推进时间。
- 动画结束停止请求帧。卸载后不保留离场快照，重新挂载直接采用新值。
- `Theme.reduceMotion` 对此 API 直接跳到终态，包括显式时长和延迟。
  这比原始 `Animator` 的显式时长策略更严格；原始 API 行为没有改变。

## 支持哪些属性

| 属性 | 变化方式 |
| --- | --- |
| `width` / `height` / `minWidth` / `maxWidth` / `minHeight` / `maxHeight` | 在实际测量和布局中补间，仍服从父容器约束 |
| `padding` | 四边分别补间，内容和命中位置一起变化 |
| `background(color, radius)` | RGBA 通道与圆角分别补间 |
| `border(color, width:, radius:)` | RGBA、边宽、圆角分别补间 |

使用稳定且唯一的 key，并保持同一 key 下的修饰器链结构稳定。它只配置**调用之前的普通
修饰器链**，不递归修改子组件，也不影响之后添加的修饰器。`probe` 等非修饰器包装会
截断这条链，因此先调用 `animateProperties`，再添加 `probe`。组件自有的 `fontSize`、
`SurfaceStyle`、渐变、阴影、可见性、任意旋转或原生 Surface 不在这一版自动补间范围内。
颜色采用通道补间，不声称线性光或感知均匀的颜色插值。

这不是 `.fillWidth()` 的断点动画：填充尺寸仍由父布局决定。响应式重排可继续使用
`KeyedLayoutTransition`；它的输入属于目标位置，而 `animateProperties` 的输入跟随真实
补间布局。不要混淆两种契约，也不要用改变 key 来触发重置式动画。

## 给现有按钮添加手势

```cangjie
Button("预览", {=> openPreview()})
    .key("preview")
    .gestures(GestureHandlers(onLongPress: Some({=> showDetails()})))
```

`IconButton` 也支持相同方法，无需外套第二层点击面。长按只触发一次并抑制本次松手点击；
拖拽开始后不再触发长按。窗口失焦或禁用时取消待处理按压、拖拽与捕获。
双击回调处理第二次点击，第一次普通点击不会被延迟或撤销；需要排他双击的产品应自行
定义动作策略。鼠标、触摸、手柄的实际设备支持仍由宿主输入桥决定。

## 可运行示例与验证

[Kit 工作台](../../../examples/kit-workbench/README.md) 展示尺寸、padding、圆角和颜色联动。
先用 debug CUIC 的 `pview` / probe `advance` 检查中间布局与动作，再用 `cuic prnt` 看像素。
不要用系统截图代替框架内容验收。更底层的自绘动画仍可使用
[Animator / Spring](animate-with-frames.md)。
