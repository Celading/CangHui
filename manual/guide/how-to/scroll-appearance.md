# 滚动容器、外观与实际视口

需要一块独立的滚动区域时使用 `ScrollView`；已有父容器时可以调用
`Widget.scrollable`。后者包装同一个 `ScrollView`，因此测量、裁剪、偏移、
嵌套滚轮和内容拖动只有一套实现。不要给每种父容器分别添加另一套滚动逻辑。
大量条目继续用 LazyList/LazyColumn/LazyRow，普通 ScrollView 会测量完整内容。

```cangjie
let offset = rememberState<Float32>("feed.offset") {0.0}
let bar = ScrollBarStyle(
    layout: ScrollBarLayout.Reserved,
    width: 12.0, margin: 3.0, minThumbLength: 24.0,
    radius: 6.0, trackRadius: 6.0,
    opacity: 0.9, trackOpacity: 0.2, thumbOpacity: 0.8,
    hoverOpacity: 1.0, activeOpacity: 1.0,
    trackColor: Some(Color.rgb(95, 130, 160)),
    thumbColor: Some(Color.rgb(46, 126, 180)),
    hoverColor: Some(Color.rgb(32, 154, 201)),
    activeColor: Some(Color.rgb(18, 100, 155)),
    interactionAnimation: Some(AnimationSpec.automatic(
        duration: 160, easing: Easing.EaseOutCubic)))
let options = ScrollOptions.web(bar: bar, contentInset: 4.0,
    duration: 220, easing: Easing.CubicBezier(0.22, 1.0, 0.36, 1.0))
let view = VStack(spacing: 6.vp) {
    for (i in 0..24) { Label("Row ${i}").height(32.0) }
}.hug().scrollable(key: "feed", options: options)
 .scrollState(offset)
 .dragToScroll()
view.height(340.0)
```

`.scrollable()` 使用自动身份和默认策略；`.scrollable(key: "feed")` 提供稳定身份；
`.scrollable(key: "feed", options: options)` 同时指定策略。它返回 ScrollView，
可继续设置 `horizontalContent`、水平/垂直 State 和内容拖动。视口的高度应在包装
之后设置；包装之前的高度约束的是内容本身，会改变溢出是否发生。

| 配置 | 效果 |
| --- | --- |
| `visibility: Hidden` | 不绘制滚动条、不占条槽、不占条的指针命中区域；内容滚轮、外部偏移和已启用的内容拖动保留 |
| `opacity: 0.0` | 不绘制或命中条，但保留所选布局的条槽；需要连槽一起去掉时使用 Hidden 或 Overlay |
| `layout: Reserved` | 溢出时为条预留空间；嵌入控件先复用已有文本内边距，避免重复预留 |
| `layout: Overlay` | 条覆盖内容，不额外收窄内容视口；可见条仍拥有其实际命中区域 |
| `layout: Automatic` | 默认兼容原控件约定：ScrollView/懒容器预留条槽，文本/列表复用固有内边距，Table 保持覆盖绘制 |
| `trackColor` / `thumbColor` | 分别配置轨道与滑块；省略时使用当前主题 panelEdge/accent 的 RGB 与原条透明度约定 |
| `hoverColor` / `activeColor` | 滑块悬停与拖动颜色；省略时逐级继承普通/悬停颜色 |
| `opacity` 与各状态 opacity | 整体透明度乘以部件/状态透明度，显式颜色还乘原 alpha；主题默认保持原条 alpha。取值均为有限的 0..1 |
| `width` / `margin` / `minThumbLength` | 逻辑像素；宽度同时进入绘制、命中、拖动映射和适用的预留空间计算 |
| `radius` / `trackRadius` | 分别设置滑块与轨道的圆角；0 保留方角 |
| `interactionAnimation` | 可选的悬停/拖动颜色与透明度过渡，使用 AnimationSpec 的 duration/easing/delay；省略时直接切换 |

滚轮位移动画由 `ScrollOptions.animation` 控制，`web(duration:easing:)` 是常用
便捷入口；`immediate(bar: ...)` 立即移动。它与滚动条状态过渡相互独立。
自动动画遵循主题动效等级；滚动条状态过渡在减少动效时直接切换，停稳后不持续申请帧。
悬停颜色服从实际输入所有者，不会隔着拥有输入的弹层点亮背景滚动条。
改变圆角/宽度是布局或外观配置更新，不是惯性滚动或物理回弹引擎。
滑动中写入外部 offset 会取消旧目标；隐藏/完全透明后不保留不可见条的拖动。

共享 ScrollOptions 可用于 ScrollView、LazyList/LazyColumn/LazyRow、ListView、
TreeView、Table、Dropdown、ComboBox 和 TextArea。TextArea 原有
`verticalScrollBar(false)` / `horizontalScrollBar(false)` 仍可分别关闭该轴条。
固有文本内边距和边框不会因隐藏条而消失。隐藏条不自动启用内容拖动，
需明确 `.dragToScroll()`，以免破坏文本选择或子控件的拖动所有权。
键盘焦点和已有可访问性操作仍由原子控件负责；这些配置不新增平台滚动语义。

在拥有的 ScrollView **完成 layout 后**调用 `view.metrics()`，可以读取
`viewport`、`contentWidth`、`contentHeight`、`offsetX`、`offsetY`、
`reservedRight` 和 `reservedBottom`。首次布局前返回空几何；窗口调整后再次布局
即可读到新值。不要把上帧副本当作实时 State，也不要在布局回调中反复写状态。
完整示例见 `examples/scroll-style`；绘制与输入均使用逻辑像素。

自定义滚动控件可以复用 `ScrollBar` / `HScrollBar` 控制器：`configure(style)` 设置
策略，`press` 处理主按钮，`drag` 接收 MouseMove，`draw` 绘制同一几何。
未拖动时也应转发 MouseMove，以便统一悬停所有权。复合控件已占有悬停时，
可传 `configure(style, hoverOwner: existingOwnerId)` 复用该所有者，避免新建第二个
焦点或动作目标；更高层弹层已占有输入时不会点亮背景条。


编辑器可直接调用 `TextArea.metrics()` 读取同一 ScrollMetrics，不必用字符数或
常量内边距推算行号栏几何。`viewport` 已包含实际文本内边距、换行和条槽避让；
`reservedRight/Bottom` 只表示超出固有内边距的额外条槽。
ScrollView 的值来自最后完成的布局，TextArea 的值来自最后完成的布局/绘制；
读取不会触发布局或回调。写入外部 offset 或文本后，在下一次布局前仍返回旧快照。
首次布局前的视口和内容大小为空；窗口/文本/字体变更后重新布局读取新值。

应先保留 `let editor = TextArea(...).scrollOptions(...)`，再调用通用字体或尺寸修饰器；
这些修饰器返回 Widget，实际几何仍从保留的 TextArea 引用读取。行号栏应使用
`metrics().viewport` 和 `offsetY`，而非再次推算文字内边距和条宽。
