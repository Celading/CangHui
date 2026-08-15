# 桌面无边框窗口

CangHui 桌面 `WindowSpec` 支持无边框窗口：

```cangjie
let app = DesktopApp(WindowSpec("MyApp", 720, 480, frameless: true))
```

- `frameless: true` 等价于 `decorated: false`，会设置 `SDL_WINDOW_BORDERLESS`。
- 窗口仍可调整大小（`resizable` 默认 true）。
- 无边框窗口的拖动/窗口控制请使用 `ClientWindowChrome` 组件（最小化/最大化/关闭/拖动）。
- Harmony 后端不受影响。
