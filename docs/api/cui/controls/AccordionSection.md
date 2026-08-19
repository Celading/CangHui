[cui](../../index.md) › [cui.controls](index.md) › AccordionSection

# AccordionSection

`cui.controls` 包中的 public struct

`Accordion` 折叠面板的一个分区描述：可使用标题文本或装饰性 header slot，并提供正文构建函数。正文只在分区展开时构建。

## 声明

```cangjie
public struct AccordionSection
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("AccordionSection", 640, 420))
    app.run {
        let about = AccordionSection("关于") {=> Label("CUI 0.2.0，基于 SDL3。")}
        let panel = Accordion([about], initiallyExpanded: [0])
        // 运行时：窗口先展开“关于”分区，点击标题可收起并再次展开。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(title: String, body: () -> Unit)`](#init) | 由标题与正文构建器构造一个分区描述。 |
| `init(header!: () -> Unit, body!: () -> Unit)` | 由装饰 header slot 与正文构建器构造分区。 |

## 构造函数

### init

由标题与正文构建器构造一个分区描述。`body` 是界面构建函数（可写尾随 lambda），仅在分区展开时被调用。

```cangjie
public init(title: String, body: () -> Unit)
```

**参数**

- `title`: `String` — 标题条上显示的文本。
- `body`: `() -> Unit` — 分区正文的界面构建函数；其中声明的组件构成展开后显示的内容。

header slot 可组合图标、标题、副标题或计数。Disclosure、焦点、点击和键盘切换仍由 Accordion 外层 header 拥有；slot 后代不会形成第二个焦点路径。

## 另请参阅

- [Accordion](Accordion.md) — 消费本类型的折叠面板。
