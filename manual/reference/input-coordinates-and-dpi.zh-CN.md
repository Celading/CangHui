# 输入坐标与动态 DPI

CangHui 的布局、命中测试和绘制统一使用逻辑视口坐标。鼠标、触摸、手写笔或平台
Surface 回调若提供物理像素，只允许在输入桥这一处转换，业务组件不应再次除以 DPI。

## 输入模型

`sdl.PointerEvent` 保留以下平台事实，直到桌面运行时的兼容边界才降低为既有
`MouseMove/MouseDown/MouseUp`：

- `coordinateSpace`：逻辑视口、窗口像素、Surface 像素或屏幕像素；
- `capturedDisplayScale` 与 `transformRevision`：事件捕获时的坐标变换；
- `orientationRevision` 与 `surfaceGeneration`：拒绝旧方向和已销毁 Surface 的事件；
- pointer/device id、按键、压力、接触面、倾斜和时间戳。

平台 provider 应调用 `normalizePointerEvent`，或将事件交给
`PointerInputBridge.push(event, transform)`。捕获 revision 过旧但 Surface/方向仍有效时，
框架使用捕获时 scale 明确重投影；旧 Surface、旧方向及缺少窗口原点的屏幕坐标直接拒绝，
不会静默套用当前 DPI。

## 动态 DPI

SDL 的 `WINDOW_DISPLAY_SCALE_CHANGED` 会产生新的 `WindowMetrics`。窗口逻辑尺寸保持不变，
renderer scale、物理 backing size、圆角 shape 和 `UiContext.displayScale` 在同一事务中更新，
并推进 `inputTransformRevision`。多窗口状态回执与 probe JSON 都公开当前 scale/revision，
便于自动化确认窗口跨显示器移动后没有命中漂移。

公共回归矩阵覆盖 `1.0 / 1.25 / 1.5 / 2.0`，并单独检查陈旧 transform 重投影、
陈旧 Surface/方向拒绝与 rich pointer 元数据保留。平台真机仍应补充跨屏拖动、旋转中触摸、
IME 和窗口缩放的现场回执。
