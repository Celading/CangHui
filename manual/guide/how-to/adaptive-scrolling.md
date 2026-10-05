# 横向内容，纵向按需滚动

优先让布局适配可用空间；只有内容确实需要比视口宽时，再选择横向画布。
不需要另一套视图框架，仍使用 `ScrollView`：

```cangjie
let x = rememberState<Float32>("board.x") {0.0}
let y = rememberState<Float32>("board.y") {0.0}
ScrollView(key: "board") {
    HStack(spacing: 16.vp) {
        VStack {
            Label("Overview")
            for (i in 0..20) { Label("Item ${i}").height(36.0) }
        }.width(320.0)
        VStack { Label("Details") }.width(320.0)
    }.hug()
}.horizontalContent(656.0)
 .horizontalScrollState(x)
 .scrollState(y)
 .dragToScroll()
```

- `horizontalContent(width)` 是内容宽度，不是窗口或视口宽度；必须是有限正数。
  视口更宽时内容至少填满视口，不生成无意义的横向滚动范围。
- 不设置它时保持原有垂直 ScrollView。纵向只有实际超高才出现滚动条和滚动范围。
- 两个滚动条各留独立槽位，横条导致高度变少时会重新检查纵向溢出。
- 子 ScrollView 优先处理滚轮。当前方向不能再移动时交给父层；零增量不消费。
  双轴增量按主方向选择一轴，不同时推进两轴；仅纵向容器不劫持主横向手势。
- `dragToScroll()` 明确选择内容拖动，默认关闭，避免破坏文本选取和滑杆拖动。
  主指针拖动超过 8 逻辑像素后锁定方向；子控件已取得拖动/捕获时优先尊重子控件。
  容器取得拖动时取消子按钮按压，松开不会额外触发一次点击。取消/失焦释放捕获。
- 一次已经取得捕获的拖动不会在途中转移给父层；嵌套边界接续适用于滚轮和新手势起点。
  这不是惯性或分页吸附引擎，横向切页可继续保留应用现有页码/动画逻辑。
- 给每页显式稳定 key，或让每页各自持有偏移 State。内容/视口变小后偏移自动夹取；
  页面被移出构建树后要恢复位置，应使用应用持有的 State，不能依赖已回收的局部状态。

尺寸与输入都使用逻辑像素。宿主仍须正确上报 DPI、旋转及键盘导致的可用视口变化；
滚动容器不会猜测物理屏幕尺寸，也不会把错误的空白 gap、过高按钮或重叠布局自动修好。
大量项目请使用 LazyRow/LazyColumn，普通 ScrollView 仍然测量和布局完整内容。
