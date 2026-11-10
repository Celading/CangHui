<!-- kind: how-to; audience: desktop-app-developer -->

# 只构建大列表的可见部分

## 目标

把千级数据改成视口构建：固定行高用 `LazyColumn`，可变行高用 `LazyList`，横向条目用 `LazyRow`，规则网格用 `LazyGrid`。完成约需 15 分钟；先理解[布局与滚动](../concepts/layout-and-scrolling.md)。

## 适用场景

聊天记录、日志、时间线和搜索结果已经多到不能每帧重建全部条目时使用。只有几十项、每项构建很轻时，普通 `ForEach` 更简单，不必为“可能变大”提前虚拟化。

## 准备工作

先记录典型数据量、行高是否固定、每行有哪些必须跨滚动保留的业务状态。准备一个稳定业务 id，并确认外层只存在一个负责该方向滚动的容器。迁移前保留普通列表版本，便于比较选择、筛选和滚动位置是否改变。

## 操作步骤

### 1. 先判断高度是否固定

`LazyColumn(count, itemHeight)` 依靠固定行高直接计算可见索引，开销最低。若每行正文长度不同并会换行，改用 `LazyList`；不要给出假的固定高度再让内容溢出。

固定行高必须按**完整行盒预算**计算，不能直接拿最大字号当高度。双行结果行至少包含：

```text
itemHeight
  >= 第一行 textHeight
   + 行间距
   + 第二行 textHeight
   + 上下 padding
   + 需要计入的边框/分隔
```

`textHeight` 是渲染器给出的行盒高度，通常明显大于 `fontSize`；中文、拉丁文和不同
字体回退还可能得到不同结果。把行高常量放在行构建函数旁边，并用真实窗口、真实字体在
常用缩放比例下截图验证。只检查 `13.5.fp < 49.0` 会漏掉行盒、间距和 padding，表现为
选中背景只包住标题、副标题掉到卡片外，或相邻行看似重叠。

```cangjie role=contrast
let SEARCH_TITLE_LINE = 20.0
let SEARCH_META_LINE = 18.0
let SEARCH_ROW_GAP = 2.0
let SEARCH_ROW_PADDING_Y = 7.0
let SEARCH_ROW_H =
    SEARCH_TITLE_LINE + SEARCH_META_LINE + SEARCH_ROW_GAP + SEARCH_ROW_PADDING_Y * 2.0

LazyColumn.of(hits, SEARCH_ROW_H, spacing: 1.0, key: {hit => hit.path}) {
    hit => HStack {
        Icon(IconName.NewDocument)
        VStack(spacing: 2.0.vp) {
            Label(hit.title).maxLines(1)
            Label(hit.path).muted().maxLines(1)
        }
    }
        .padding(13.vp, 7.vp)
        .height(Length(SEARCH_ROW_H - 1.0, LengthUnit.Vp))
}
```

行内背景、选中底色和标签胶囊也要避免意外继承父容器的剩余高度。横向排列的标签行使用
`HStack(...).hug().crossAxisAlignment(CrossAxisAlignment.Center)`，否则它可能在纵向
栈里吃掉剩余空间，把短标签拉成整列高的色块。

### 2. 把业务状态上提

虚拟列表只创建视口附近的行，滚远后行会卸载。选择、编辑草稿、加载状态等必须按业务 id 放进模型。`key` 返回稳定 id，不能返回当前索引。

### 3. 运行固定行高版本

```cangjie verify role=complete profile=gui-visual
package docexample

import chui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("千行收件箱", 640, 420))
    app.run {
        let scroll = rememberState<Float32>("mail-scroll") {0.0}
        LazyColumn(1000, 48.0, spacing: 8.0, scroll: Some(scroll), id: "mail-list") {
            index => HStack(spacing: 12.vp) {
                Label("#${index}").muted().width(70.vp)
                Label("第 ${index} 封邮件").flex()
            }.padding(8.vp)
        }
    }
}
```

### 4. 数据数组使用稳定 key

```cangjie role=variation
LazyColumn.of(messages, 52.0,
    key: {message => message.id},
    scroll: Some(scroll), id: "messages") {
    message => MessageRow(message, drafts[message.id])
}
```

这里 `drafts` 属于页面模型。滚出视口再滚回时，新行会从模型取回草稿。若行高不统一，把同一身份规则迁移到 `LazyList`，而不是在固定高度行里塞入任意高内容。

## 确认结果

运行完整程序并从第 0 行滚到数百行，滚轮应持续响应，滚动条不跳回顶部。改变窗口高度后列表继续占满剩余空间。代码评审时确认行构建函数没有磁盘读取、网络访问或大型排序；这些工作应在模型层预先完成。

再做一次身份验证：选中一个中部业务对象，改变筛选或排序，然后滚离并滚回。选择与草稿应跟随业务 id；纯行内展开状态若没有上提，则允许在卸载后复位。把这两类结果明确区分，避免把设计边界误报为虚拟化缺陷。

## 常见错误

- 把 `rememberState` 当跨滚动存储：行卸载后状态会被清理。
- 使用数组索引作 key：插入或重排后状态串到别项。
- 在行构建器里筛选整个数组：每个可见行都重复做同一工作。
- 外层和内层同时强制消费滚轮：内容不足一屏时形成滚动死区。
- 用 `fontSize` 估行高：行盒、行距和 padding 未计入，固定槽位会装不下内容。
- 给短标签所在 `HStack` 保留默认纵向伸展：胶囊可能被拉满整块剩余高度。

## 相关 API

[LazyColumn](../../api/chui/core/LazyColumn.md)、[LazyList](../../api/chui/core/LazyList.md)、[LazyRow](../../api/chui/core/LazyRow.md)、[LazyGrid](../../api/chui/core/functions.md)。

## 下一步

结构化数据继续看[表格主从界面](table-master-detail.md)，层级数据继续看[树与导航](tree-and-navigation.md)。
