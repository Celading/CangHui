# 桌面无边框窗口

CangHui 桌面 `WindowSpec` 支持无边框窗口：

```cangjie
let app = DesktopApp(WindowSpec("MyApp", 720, 480, frameless: true))
```

- `frameless: true` 等价于 `decorated: false`，会设置 `SDL_WINDOW_BORDERLESS`。
- 窗口仍可调整大小（`resizable` 默认 true）。
- 无边框窗口的拖动/窗口控制请使用 `ClientWindowChrome` 组件（最小化/最大化/关闭/拖动）。
- Harmony 后端不受影响。

## 原生主窗口圆角

系统装饰窗口在 macOS 上本来就由 AppKit 提供圆角，不要再叠一层自定义裁切。只有
自绘标题栏/无边框窗口需要显式窗口形状：

```cangjie
let app = DesktopApp(WindowSpec(
    "MyApp",
    720,
    480,
    frameless: true,
    cornerRadius: 18.0
))
```

`cornerRadius` 使用逻辑像素。正值会创建透明窗口并通过 SDL 原生 window shape 裁掉四角；
窗口缩放或 resize 后框架会按物理像素重建 mask，因此透明角也不参与系统命中。它不同于
根组件 `.background(..., radius)`：后者只改变内容绘制，窗口外形仍是矩形。当前实现已在
macOS SDL 路径编译与单元门验证；Windows/Linux 的最终合成外观仍需各平台实机验收。

## 运行时调节

如果初始半径为零但之后需要圆角，创建窗口时显式设置 `transparent: true`：

```cangjie
let app = DesktopApp(WindowSpec("MyApp", 720, 480,
    frameless: true, transparent: true, cornerRadius: 0.0))
let result = app.setWindowCornerRadius(24.0)
app.setWindowCornerRadius(0.0) // 清除自定义形状
let current = app.windowShapeReceipt()
```

多窗口使用 `application.setWindowCornerRadius(id, radius)`，未找到窗口返回 `None`。
API 必须在窗口 owner 线程调用。半径须为有限值；负值按零处理，过大值裁到半边长。
未以透明或正半径创建的窗口返回 `Failed`，不会偷偷重建窗口。返回 `Applied` 只表示
原生形状调用成功，不代替桌面合成验收。最大化或全屏时清除形状，回到普通窗口时按
保存的半径恢复；实际事件交付和合成仍由平台决定。

示例见 [macos-shell](../../examples/macos-shell/)。默认系统装饰和圆角保持不变；自定义
半径面向无边框窗口，不用于强行覆盖系统标题栏形状。
