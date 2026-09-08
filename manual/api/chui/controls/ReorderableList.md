[chui](../../index.md) › [chui.controls](index.md) › ReorderableList

# ReorderableList

## 键盘、手柄与语义操作

每行握点现在是独立焦点项，顺序为“握点 → 该行内容控件 → 下一行握点”。
提供稳定 `key` 后，握点身份为 `ReorderableList:<id>:item:<key>:grip`，重排后焦点跟随原项。
省略 `key` 时身份跟随下标，不能识别同长度数组中的业务项替换；可变数据应提供稳定键。
键必须非空且唯一，否则构造时抛出 `IllegalArgumentException`。

- 未抓取时，方向键及 Home/End 移动握点焦点。
- Enter/Space 抓取；方向键及 Home/End 只移动预览；再次 Enter/Space 提交，Escape 取消。
  按住确认键产生的重复事件不会重复抓取或提交。
- 聚焦握点后，手柄 South 抓取／提交，D-pad 上下移动，East 取消。
  抓取期间只接受所属手柄；该手柄断开会取消。实际设备映射仍需在目标平台验证。
- 失焦、禁用、指针取消或事务期间键列表改变时放弃预览，不调用 `onMove`。
  普通重绘保留预览；提交回调抛出异常前也会清理交互状态。

使用 `.accessibilityLabels({index => "移动 ${tracks[index].title}"})` 为握点提供业务名称；
参数为 `(Int64) -> String`，返回当前 `ReorderableList`，默认名称为 `Reorder item N`。
CUIC/语义树中的 `ReorderHandle` 包含当前预览位置、抓取状态、焦点和稳定动作所有者。
初始支持 Focus/Activate；抓取后按可达方向提供 Increment/Decrement，并提供 Dismiss。
语义动作复用同一排序事务，不直接改写应用数据；原生读屏效果仍需系统验收。

用 debug CUIC 的 `focus <grip-id>`、`key Space`、`key Down`、`key Enter` 回放，
再检查调用方真正重排后的数组。排序手柄仍是原有 30 vp 宽；触摸目标尺寸与长列表自动滚动
不是本次键盘支持的承诺。


`chui.controls` 包中的 public class

行高固定、可拖拽重排的垂直列表：每行左侧带握点手柄，按住手柄拖动即抬起该行随指针移动、其余行让位露出落点，松手调用 `onMove(from, to)` 提交——列表只报告移动，数据始终由调用方持有并自行重排。

## 声明

```cangjie
public class ReorderableList <: Widget
```

## 继承

`ReorderableList <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

行是 `item` 构建器产出的普通组件，可携带自己的内容与控件：落在手柄条（每行左缘 30 逻辑像素）之外的事件自顶向下转发给行内容，勾选、点按都与拖动互不干扰；`Frame` 帧事件转发给全部行。行标识跟随 `key`——给出稳定键后，勾选态等行内局部状态在重排后仍跟随原行。

拖动期间被拖行抬升（强调描边加投影的浮起面）并钉在指针下方、上下夹在列表范围内；落点由被拖行中心所在的行槽决定，其余行按预览次序让位。松手时仅当 `from` 与 `to` 都在范围内且不相等才回调 `onMove`，原地放回不产生回调。全部行在构造时即时构建（不做惰性窗口化），适合条数有限、整屏可见的列表——设置顺序、播放列表；很长的列表应包在滚动容器里，让拖动交互保持在视野内。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ReorderableList", 640, 420))
    app.run {
        let tasks = ["写周报", "备份数据", "整理桌面"]
        let moved = rememberState<String>("moved") {""}
        ReorderableList.of(tasks, 40.0, {from, to => moved.value = "${from}->${to}"}, spacing: 8.0, key: {t => t}) {
            task => Label(task)
        }
        Label(if (moved.value.isEmpty()) {
            "尚未移动"
        } else {
            "最近移动：${moved.value}"
        }).muted()
        // 运行时：按住行左侧手柄拖动并松开，onMove 报告原下标与目标下标。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以行数、行高、移动回调与行构建器构造列表。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static of(...)`](#of) | 数据驱动形态：对 `Array<T>` 逐项构行，`onMove` 收到数组下标。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 返回充满可用宽度、高为全部行加行距总和的尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 按当前拖动预览排布各行：内容区从手柄右侧起，被拖行随指针、其余行让位。 |
| [`draw(ctx: UiContext)`](#draw) | 先画未拖的行，最后画抬升的被拖行，使其浮于其余行之上。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 手柄按下开始拖动、移动更新预览、松手经 `onMove` 提交；非拖动事件自顶向下转发给行内容。 |
| [`focusableIds()`](#focusableids) | 按行顺序返回握点与行内容的焦点项。 |

## 构造函数

### init

以行数、行高、移动回调与行构建器构造列表。全部行即时构建，不做窗口化。

```cangjie
public init(
    count: Int64,
    rowHeight: Float32,
    onMove: (Int64, Int64) -> Unit,
    spacing!: Float32 = 6.0,
    key!: ?((Int64) -> String) = None,
    id!: ?String = None,
    item!: (Int64) -> Unit
)
```

**参数**

- `count`: `Int64` — 行数；负值按 0 计。
- `rowHeight`: `Float32` — 统一行高，逻辑像素；下限 1。
- `onMove`: `(Int64, Int64) -> Unit` — 松手提交时收到 `(from, to)` 显示位置；调用方对自己的数据施加这次移动，下一帧构建即显示新序。
- `spacing!`: `Float32` — 行间距，逻辑像素；默认 `6.0`，负值按 0 计。
- `key!`: `?((Int64) -> String)` — 按下标给出行标识键；默认 `None` 以下标为键，重排后行内局部状态不跟随内容——需要跟随时给出稳定键。
- `id!`: `?String` — 列表自身标识（拖动状态与行状态的作用域）；默认 `None`，按构建顺序自动派生。
- `item!`: `(Int64) -> Unit` — 行内容的界面构建函数，按下标调用。

**异常**

- `IllegalArgumentException` — `id` 传入空字符串时。

## 方法

### of

数据驱动形态：对 `Array<T>` 逐项构行，`onMove` 收到数组下标。`key` 从数据项导出稳定标识，行内局部状态随该项跨重排迁移。

```cangjie
public static func of<T>(
    data: Array<T>,
    rowHeight: Float32,
    onMove: (Int64, Int64) -> Unit,
    spacing!: Float32 = 6.0,
    key!: ?((T) -> String) = None,
    id!: ?String = None,
    item!: (T) -> Unit
): ReorderableList
```

**参数**

- `data`: `Array<T>` — 逐项构行的数据。
- `rowHeight`: `Float32` — 统一行高，逻辑像素；下限 1。
- `onMove`: `(Int64, Int64) -> Unit` — 松手提交时收到 `(from, to)` 数组下标。
- `spacing!`: `Float32` — 行间距；默认 `6.0`，负值按 0 计。
- `key!`: `?((T) -> String)` — 从数据项导出标识键；默认 `None` 以下标为键。
- `id!`: `?String` — 列表自身标识；默认 `None`，按构建顺序自动派生。
- `item!`: `(T) -> Unit` — 行内容的界面构建函数，按数据项调用。

**返回值** `ReorderableList` — 构建完成的列表。

**异常**

- `IllegalArgumentException` — `id` 传入空字符串时。

### measure

返回充满可用宽度、高为全部行加行距总和的尺寸。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

按当前拖动预览排布各行：内容区从手柄右侧起，被拖行随指针、其余行让位。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

先画未拖的行，最后画抬升的被拖行，使其浮于其余行之上。行槽裁剪外扩了投影余量，卡片式行的柔和光晕不会被槽边切断。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

手柄按下开始拖动、移动更新预览、松手经 `onMove` 提交；非拖动事件自顶向下转发给行内容。悬停手柄或拖动中申请交互指针。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableIds

按行顺序返回握点与行内容的焦点项。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 各行握点及行内容中可参与键盘焦点导航的全部标识。

## 另请参阅

- [ListView](ListView.md) — 只读选择语义的字符串列表。
- [LazyColumn](../core/LazyColumn.md) — 长列表的惰性（按需构建）容器。
