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

## macOS 原生排版预览

`DesktopApp` 可以在首次 `run` 之前显式启用 CoreText：

```cangjie
let app = DesktopApp(WindowSpec("Native text", 720, 480))
let enabled = app.usePlatformTextLayout(true)
// 检查 enabled，再调用 app.run { ... }。
```

应用启动后调用此设置返回 `false`，保持原有排版模式；默认仍是 SDL_ttf。
自定义渲染宿主也可在测量和绘制之前设置：

```cangjie
let enabled = renderer.usePlatformTextLayout(true)
// 检查 enabled；false 表示当前渲染器不能提供这条原生路径。
```

`platformTextLayoutEnabled()` 返回当前状态。传入 `false` 恢复 SDL_ttf。
切换会清空测量缓存，因此不能在测量与绘制之间切换，也不要逐个标签反复切换。
默认仍使用 SDL_ttf；无设备渲染器和其他平台请求启用时返回 `false`。

普通和粗体文本由同一个保留的 CoreText line 提供宽高、像素与光标几何。
注册的字体文件仍是主字体；按序回退描述符及 CoreText 系统回退可提供缺字和
彩色 emoji。随包 HarmonyOS Sans 的 Regular、Bold 命名实例分别选择。
回退字形可能随 macOS 版本变化。斜体、下划线和删除线的测量与绘制仍一起使用
SDL_ttf；预览不保证所有字体的样式一致性。

原生排版和纹理缓存归渲染器持有，禁用或关闭时释放。单张栅格不超过
16384 × 4096 像素及 16 MiB RGBA；超限会明确报错，不会悄悄截断。
长内容应换行或虚拟化。纹理遵循渲染目标的双轴缩放及已有裁剪。

启用后，`TextField` 的点击、光标、水平跟随、选区和左右键使用整行原生几何。
混合方向文本的同一逻辑边界可能有两个视觉位置，点击会保留所选位置；一段逻辑
选区可能绘制成多段高亮。左右键按视觉位置移动，Home/End 仍是逻辑首尾，
选词仍沿用现有规则。编辑状态保持 UTF-8 字节偏移，并落在扩展字素边界上；
密码字段只把掩码交给这套原生排版查询。

自定义编辑器可用 `Renderer.textCaretPositionsUtf16`（单个或批量索引）、
`textHitUtf16`、`textSelectionSpansUtf16`。索引单位是 UTF-16，坐标是逻辑像素；
返回 `None` 表示当前后端或样式不支持。空文本的原生命中可以返回 `-1`，
调用者须转换为 UTF-8 并归一到字素边界，不能直接写入编辑状态。框架内部使用
`NativeTextIndex` 完成此转换；该内部类型不是供自定义编辑器引用的公开 API。

这仍不是完整原生编辑器：`TextArea` 尚未接入整行原生编辑几何，不应把此开关
用于要求正确 bidi 编辑的 TextArea 页面。IME 光标锚点随 TextField 更新，但
原生组合文本、输入法候选窗实测与读屏接线仍需另行完成。多窗口宿主尚无该启动选项。
无设备 probe 的矩形不证明原生字形正确，像素仍需用 `cuic prnt` 验证。

在 Cangjie 1.1.3 / macOS arm64 上，原生像素测试曾触发与自动生成的跨包 FFI
桥接帧有关的 GC 回栈崩溃。截图与像素验证现在共用正常仓颉读回方法及 Surface
所有权，避开了已观察到的失效调用路径。这不等于修复编译器／运行时或验证了
所有原生调用；此预览仍不代表生产编辑器的稳定性认证。

### 自定义宿主的着色行

直接依赖 `sdl` 的高级宿主可使用 `sdl.text.NativeTextLineSpec`，把单行原始文本、
默认 RGBA 和局部着色范围固定成一份不可变请求：

```cangjie
import sdl.text.{NativeTextLineSpec, NativeTextColorSpan}

let line = NativeTextLineSpec("abc אבג def", red: 30, green: 30, blue: 30,
    colors: [NativeTextColorSpan(1, 5, 230, 70, 40, 255)])
let size = renderer.textSize(line, pointSize: 24.0)
let caret = renderer.textCaretPositionsUtf16(line, Int64(3), pointSize: 24.0)
let drawn = renderer.text(line, 12.0, 20.0, pointSize: 24.0)
```

范围使用 UTF-16 码点边界，不能切断代理对；非法范围抛出 `IllegalArgumentException`。
数组被复制，重叠时后项覆盖前项。默认色也属于请求，绘制时不能临时换色。
更换颜色可能改变连字、emoji 组合及光标位置，因此测量、绘制、单个／批量光标、
`textHitUtf16` 和 `textSelectionSpansUtf16` 必须使用相同请求、字号、样式和字体。
编辑器仍需把原生索引转换为自己的 UTF-8 字素位置，不应直接保存 UTF-16 值。

着色范围不能沿用光标的字素取整规则：合法范围可以从 `e` 与组合重音之间开始，
也可以位于 emoji 的 ZWJ 序列内部。应把每个 UTF-8 码点边界精确转换到 UTF-16；
字节内部、代理对内部及越界位置应拒绝，不能悄悄扩大或缩小范围。例如 `A😀é`
中重音的 UTF-8 范围 `[6,8)` 对应 UTF-16 `[4,5)`，但前一个合法编辑光标在
UTF-8 字节 `5`。按源文本行保留编码索引，不要为每段装饰重新扫描整行。

请求不持有原生指针；原生行及纹理仍由原渲染器缓存和释放。请在文本或颜色改变时
重建请求，不要在逐个光标查询中重建。不支持的样式／后端返回 `None` 或绘制 `false`，
不会绘制替代内容。调用者须同时选择绘制与几何的回退方式。这只是原生着色行接口，
不是 `TextArea` 装饰、自动换行或跨样式编辑的完成声明。

## 原生文本仍有的限制

混合字体回退不等于完整 Unicode 塑形或双向排版。需要整体切到回退字体的复杂
字形簇、默认 SDL 路径中的位图 emoji 字级缩放、跨样式字形塑形仍需独立实现和目标平台验收。
尽量把复杂字素保留在同一 span，并选择能覆盖整个字素的字体。
编辑与换行保证另见[文本边界](text-boundaries.md)。
