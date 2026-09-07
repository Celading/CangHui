# 字体解析

[English](fonts.md) | **中文**

CangHui 随包提供未经修改的 HarmonyOS Sans SC，并将其作为默认跨平台字体。是否把字体安装到宿主操作系统是可选项。

## 解析顺序

每一段文本按以下顺序寻找字体：

1. 组件显式选择的字体，例如 `Label.fontFamily`；
2. `Theme.withFontFamily` 选择的主题字体；
3. `Fonts.useApplicationFamily` 选择的进程级应用字体；
4. 随包 HarmonyOS Sans SC 兜底字体；
5. 平台系统 UI 字体。

前三层字体必须通过 `Fonts.register` 注册。无法识别或无法读取的文件会被跳过。使用真实 SDL_ttf 渲染器时，CangHui 会检查整段文本的字形覆盖；当前字体覆盖不完整时继续尝试下一层。

没有单一字体能覆盖整段时，原生后端按上述顺序组合同字号、同字重的可用字体。
例如，支持阿拉伯文的应用字体与随包中文字体可以共同绘制一条混合语言标签。
回退链持有独立的原生字体副本并缓存复用；另一个标签切换字体不会修改已经塑形
文本的回退配置。如果链中没有字体覆盖某个字符，该字符仍会显示缺字标记。

对于 `.bold()`，CangHui 会先选择可变字体文件内部真实的 `Bold` 命名实例（随包 HarmonyOS Sans SC 已包含该实例），再尝试独立的粗体伴随文件；只有两者都不存在时，才在已选基础字体上合成粗体。改变字重不会改变字族回退顺序。

```cangjie
Fonts.register("brand", "assets/fonts/Brand-Regular.ttf")
let theme = Theme.light().withFontFamily(Some("brand"))
let app = DesktopApp(WindowSpec("Example", 720, 480), theme: theme)
```

应用需要统一默认字体、但不想绑定到某个 `Theme` 值时，可以调用 `Fonts.useApplicationFamily("brand")`。组件级字体仍然优先于这两类默认值。

## 打包

集成命令 `cuic init` 会把默认 TTF 与许可证复制到新应用的 `assets/fonts`。`cuic build`、`test`、`run`、`prnt` 也会通过 `CANGHUI_HARMONYOS_SANS` 向受管进程提供框架字体路径。

其他构建系统应一起打包以下文件：

```text
assets/fonts/HarmonyOS_Sans_SC.ttf
assets/fonts/HARMONYOS_SANS_LICENSE.txt
assets/fonts/HARMONYOS_SANS_SOURCE.txt
```

资源布局不同的应用宿主可以在创建窗口前调用 `Fonts.registerBundledFallback(path)`，也可以在进程启动前设置 `CANGHUI_HARMONYOS_SANS`。

## 诊断

`Renderer.fontResolution()` 报告逻辑上的首选层级。使用真实渲染器时，`Renderer.fontResolutionForText(text)` 还会应用字形覆盖检查，并报告该字符串实际选择的层级。组合回退链返回其主字体，而不是完整的逐字形字体映射。记录型渲染器会在文本 Draw IR 中写入 `resolvedFamily` 与 `fontSource`。

```bash
./tools/cuic/bin/cuic font status macos
./tools/cuic/bin/cuic doctor macos --verbose
```

稳定的机器可读契约是 [`canghui.font-resolution.v0`](../../contracts/canghui-font-resolution-v0.json)。

## 原生文本仍有的限制

混合字体回退不等于完整 Unicode 塑形或双向排版。需要整体切到回退字体的复杂
字形簇、位图 emoji 的字级缩放、跨样式字形塑形仍需独立实现和目标平台验收。
尽量把复杂字素保留在同一 span，并选择能覆盖整个字素的字体。
编辑与换行保证另见[文本边界](text-boundaries.md)。
