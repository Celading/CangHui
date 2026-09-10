# 文本边界与编辑

`TextEditState`、`TextField`、`TextArea` 的左右移动、扩展选择和前后删除按
Unicode 15.1 扩展字素处理。例如 `e` 与组合重音、国旗、家庭 emoji、Hangul
组合音节不会因按一次方向键或删除键而被拆开。无需应用自行拦截这些按键。

## 偏移仍然是 UTF-8 字节

光标、选择锚点和公开文本范围继续使用 UTF-8 字节偏移，不是字素序号。
外部设置落在字素内部的光标会向前规范到该字素起点；插入后若与相邻文字
合成一个字素，光标会落在完整字素之后。不要把 `String.size` 当作可见字符数。

鼠标命中以完整字素的测量中点选择前后位置。密码框每个字素显示一个掩码，
点击和选择会映射回原文的字节偏移；这不改变其禁止明文撤销历史和探针脱敏的规则。

编辑控件保留一个文本边界索引，文本未变化时复用它；组件重建时重新使用当前
文本绑定，不保留旧控件的绑定。文本变化后重建索引，尚不是增量文本编辑引擎。

## 文本换行

普通 `Label` 的省略和自动换行不会在扩展字素内部截断。一个字素宽于整行时，
换行会保留这个字素而允许溢出；省略显示则可能只留下省略号，或在省略号也放不下时
返回空字符串。仍需根据应用空间设置截断、裁切或滚动。

`RichText` 也按完整字素选择换行位置，包括字母与重音、emoji 序列分属不同
样式 span 的情况。排版会预留同一字素后续片段的宽度，保留各片段原来的颜色、
字号、字体和点击归属。图标两侧是独立边界，不会把图标与相邻文本拼成一个字素。
宽于整行的字素仍留在同一行，可能溢出；这不是缩小字体或省略文本的策略。

这项保证仅针对**换行位置**。跨 span 的字体运行仍分别交给渲染器绘制，不能据此
保证组合重音定位、连字或跨样式 emoji 塑形正确。需要可靠的完整字形时，把同一
字素放进同一个文本 span；复杂文字仍须在目标平台检查字体与塑形结果。

## 还不能等同于完整国际化排版

- 跨样式字形塑形仍未统一；字素不跨行不代表多个绘制片段会合成为一个正确字形。
- 双击选词仍使用现有字符分类，不是 Unicode 词边界或各语言分词。
- 垂直移动仍按字节列近似，再规范到字素边界，不是双向文本的视觉列导航。
- 本规则不实现 RTL/Bidi 重排、字体回退、复杂字形塑形或 Unicode 行断规则。
- 原生 IME 组合范围、无障碍和读屏需要各平台适配及真实运行验收；字素测试不证明这些能力。

## 数据与可复现测试

采用 [UAX #29 revision 43](https://www.unicode.org/reports/tr29/tr29-43.html) 的扩展字素规则。
不是对“最新 Unicode”的滚动承诺。生成器使用四份固定版本的原始文件：

- [GraphemeBreakProperty.txt](https://www.unicode.org/Public/15.1.0/ucd/auxiliary/GraphemeBreakProperty.txt)
- [DerivedCoreProperties.txt](https://www.unicode.org/Public/15.1.0/ucd/DerivedCoreProperties.txt)
- [emoji-data.txt](https://www.unicode.org/Public/15.1.0/ucd/emoji/emoji-data.txt)
- [GraphemeBreakTest.txt](https://www.unicode.org/Public/15.1.0/ucd/auxiliary/GraphemeBreakTest.txt)

将原文件放进同一个本地目录，在框架源码根运行：

```sh
python3 scripts/generate-grapheme-data.py /path/to/unicode-15.1 --check
cjpm test --filter '*rapheme*'
```

生成器不联网，先核对全部输入的固定 SHA-256；`--check` 只检查生成结果。
需要重新生成时去掉 `--check`。仓内测试包含官方 1,187 条用例，以及编辑、命中、
密码映射、撤销恢复和长段落用例。测试框架需要本机回环端口。

生成数据及测试遵循 [Unicode License V3](../../LICENSE-UNICODE)，源码 SDK 会保留该许可。
