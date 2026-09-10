# 输入坐标与动态 DPI

CangHui 的布局、命中测试和绘制统一使用逻辑视口坐标。鼠标、触摸、手写笔或平台
Surface 回调若提供物理像素，只允许在输入桥这一处转换，业务组件不应再次除以 DPI。

## 输入模型

`sdl.PointerEvent` 保留以下平台事实，直到桌面运行时的兼容边界才降低为既有
`MouseMove/MouseDown/MouseUp`；`Cancel` 独立转换为 `UiEvent.PointerCancelled`，
不能转换为正常松手：

- `coordinateSpace`：逻辑视口、SDL 窗口坐标、窗口物理像素、Surface 像素或屏幕像素；
- `capturedDisplayScale` 与 `transformRevision`：事件捕获时的坐标变换；
- `orientationRevision` 与 `surfaceGeneration`：拒绝旧方向和已销毁 Surface 的事件；
- pointer/device id、按键、压力、接触面、倾斜和时间戳。

平台 provider 应调用 `normalizePointerEvent`，或将事件交给
`PointerInputBridge.push(event, transform)`。捕获 revision 过旧但 Surface/方向仍有效时，
框架使用捕获时 scale 明确重投影；旧 Surface、旧方向及缺少窗口原点的屏幕坐标直接拒绝，
不会静默套用当前 DPI。

`WindowCoordinates` 专指 SDL 事件单位。macOS 上它通常是点，不是 Retina 物理像素；
必须同时提供 `capturedPixelDensity` 和捕获时的 scale/revision。此类事件的变换过期时直接
拒绝，不能在用户缩放后继续沿用旧坐标。已有 `WindowPixel` 与 `SurfacePixel` 仍表示物理像素。

## 设置系统缩放与用户缩放

新应用可显式采用系统感知缩放：

```cangjie
import chui.{DesktopApp, WindowSpec, WindowScaleSettings}

let app = DesktopApp(WindowSpec("Example", 800, 600,
    scaling: Some(WindowScaleSettings())))
// 在 UI 所在线程调用，例如设置页按钮回调：
app.setScaling(WindowScaleSettings(zoom: 1.25))
// 不跟随系统的内容放大，仅保留显示器像素密度与用户 125% 缩放：
app.setScaling(WindowScaleSettings(followSystem: false, zoom: 1.25))
```

`zoom` 接受 0.25–4.0 的有限数值。应用可以提供“跟随系统”和
100%／125%／150%／175%／200% 选项，并用自己的设置存储保存选择。
框架不会偷偷修改系统 DPI。切换用户缩放不改变原生窗口尺寸，而是重新计算逻辑视口。
多窗口使用 `DesktopApplication.setWindowScaling(windowId, settings)`；
`setWindowSize(windowId, width, height)` 则按逻辑尺寸调整指定原生窗口。

兼容说明：未传 `scaling` 时，`WindowSpec.scale` 继续表示旧版“SDL 窗口单位 / 逻辑单位”倍率。
不要把系统 DPI 再填进这个旧参数。`SdlWindow.scale` 与 `WindowMetrics.displayScale`
表示实际“backing 像素 / 逻辑单位”，Retina 上不一定等于传入的旧倍率。
不要直接修改窗口的 scale 字段；通过设置方法触发完整更新。
上述新 API 需要包含本页实现的框架提交，不能假定历史 Git pin 已包含它们。

## 一个窗口，一套换算

输入变换替换或窗口失焦会先取消当前指针交互，再清理按压、拖动及捕获。
取消不点击、不提交重排；连续调节控件保留最后一次已接受的值，不额外应用松手坐标。
自定义宿主应调用 `ctx.cancelPointerInteraction(root)`，让已登记浮层和组件树都收到
取消通知；自定义控件通过 `PointerCancelled` 清理临时状态，Scene3D 输入处理器对应
`Scene3DViewInputEvent.PointerCancelled`。这些是框架事件保证，不替代物理设备验收。

`WindowCoordinateTransform` 提供共同的输入／IME 依据：

```text
renderScale = 系统显示缩放 × 用户 zoom       （followSystem）
renderScale = backing 像素密度 × 用户 zoom   （独立缩放）
windowScale = renderScale / backing 像素密度
逻辑坐标 = SDL 窗口坐标 / windowScale
```

单窗和多窗都通过 `SdlWindow.normalizeWindowEvent` 转换。收到显示缩放、窗口尺寸或
backing 尺寸通知时，框架重新查询完整窗口状态，产生 `WindowMetricsChanged`，不把旧队列中的
尺寸通知当成当前几何。真实 resize 应调整原生窗口，不能靠伪造 `WindowResized` 修改其大小。
渲染、圆角资源、逻辑视口、帧图像素密度和 IME 锚点随更新一起刷新；几何或坐标单位变化时推进
输入 revision。临时超采样／效果纹理使用的倍率不会覆盖持久内容缩放。

桌面循环在执行 UI 队列后读取本帧的布局尺寸；输入或帧回调改变缩放时，绘制前再次布局，
避免把旧尺寸的组件与新缩放一起发布。单窗口缓冲的坐标事件保留采集时的变换版本；
若 UI 工作已替换变换，会取消旧指针事务，不把旧坐标套到新布局。键盘、取消和关闭事件
仍正常派发。它不代表跨屏、真实触摸或原生无障碍动作的全部时序已经验收。

桌面宿主只缓存平台成功接受的 IME 光标区域。平台暂时拒绝时会在后续绘制重试，
不创建后台重试循环；窗口焦点、坐标变换或文本锚点消失后会使缓存失效。
单窗与托管多窗使用相同规则，每窗状态独立。这是锚点转发保证，不替代各平台的
真实输入法、候选窗位置与跨屏验收。

文字和矢量按当前绘制密度重新栅格化，不是将低分辨率的整张界面放大。
低分辨率位图仍受原始资源限制；非整数像素边缘也需要抗锯齿。非等比缩放不是此设置的默认策略，
否则字体、图标和触摸目标会一起变形。特定内容的变换应使用对应内容组件及其输入逆变换。

绘制到非等比目标纹理时，文字与几何使用相同的 X/Y 比例。文字按较大轴的密度生成字形，
再缩小较小轴；裁剪区域同步换算，绘制后恢复原来的变换。这不改变布局测量或输入坐标单位，
也不替自定义 Canvas 完成业务命中逆变换。位图字体本身的固定字级、低清图片及复杂文本塑形
仍是独立限制，不能承诺任意内容在任意缩放下绝无采样损失。

SDL 的平台坐标差异可查阅 [SDL 高 DPI 说明](https://wiki.libsdl.org/SDL3/README-highdpi)。

公共回归矩阵覆盖 `1.0 / 1.25 / 1.5 / 2.0`，并单独检查陈旧 transform 重投影、
陈旧 Surface/方向拒绝与 rich pointer 元数据保留。平台真机仍应补充跨屏拖动、旋转中触摸、
IME 和窗口缩放的现场回执。

## Harmony provider 接入

ArkUI/XComponent 宿主负责在配置密度变化时同步更新原生 provider，即使 Surface 尺寸未变也不能遗漏。
提交 surface 像素尺寸、密度、generation 与输入捕获 revision；物理触摸坐标只在桥层转换一次。
不要同时在 ETS 与 SDL/CangHui 各除一次倍率，也不要永久缓存启动时的 `vp2px(1)`。
通用框架不能替尚未上报新密度的 provider 推断设备状态，HMPC 真机验收仍需宿主方完成。

原生验证夹具位于 `tools/release-fixtures/window-scale-native`，只有 debug 构建执行模拟输入检查。
它验证真实窗口上重复 zoom 的尺寸、换算和 IME 设置调用；不代替跨显示器迁移、真实触摸、笔输入或
系统 IME 候选窗的现场验证。
